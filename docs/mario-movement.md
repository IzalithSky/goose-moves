# Mario-family Movement Math (SM64)

Source-verified against `references/sm64/src/game/{mario_actions_moving.c, mario_actions_airborne.c, mario_step.c, mario_actions_submerged.c, mario.c}` (n64decomp/sm64 decompilation). Odyssey/Banjo/Spyro are closed but share the substrate (noted at the end). Contrast: [q3-movement.md](q3-movement.md) — different substrate entirely.

## Core model: polar speed + facing + action FSM

- Movement state is a **scalar `forwardVel` + a heading `faceAngle[1]`**, *not* a velocity vector. The Cartesian `vel[]` is **derived each frame**:
  `vel[0] = forwardVel·sin(faceAngle[1])`, `vel[2] = forwardVel·cos(faceAngle[1])` (`mario_actions_moving.c:323`; setter `mario.c:377`). `vel[1]` (vertical) is separate and scripted.
- **Everything is an explicit action FSM** — `ACT_WALKING`, `ACT_JUMP`, `ACT_DIVE`, `ACT_LONG_JUMP`… each its own function, transitions via `set_mario_action`. (Opposite of Q3's stateless per-tick dispatch.)
- **Input is analog**: `intendedMag` (stick magnitude, ~0–32) and `intendedYaw` (stick world direction).

There is **no target for velocity *direction*** — you turn by rotating `faceAngle`, and the whole speed vector swings with it. That's the skid-turn feel, and the root reason Quake air-strafing can't exist here.

## Ground acceleration (`update_walking_speed`, `mario_actions_moving.c:434`)

```
maxTargetSpeed = (floor == SURFACE_SLOW ? 24 : 32)
targetSpeed    = min(intendedMag, maxTargetSpeed)          # analog: partial stick = walk
if   forwardVel <= 0:         forwardVel += 1.1
elif forwardVel <= target:    forwardVel += 1.1 - forwardVel/43   # accel fades toward cap
elif floor is flat (n.y≥0.95): forwardVel -= 1.0                  # decel if over target
clamp forwardVel ≤ 48
faceAngle[1] ← approach(intendedYaw, 0x800)               # turn rate ~11°/frame
→ apply_slope_accel
```
Decel when no input (`update_decelerating_speed`, `:420`): `forwardVel → 0` by 1.0/frame.

## Slopes (`apply_slope_accel`, `:283`)

- On a slope, `forwardVel += slopeAccel·steepness` when facing downhill (`|floorAngle − faceAngle| < 0x4000`), else `−=`. `slopeAccel` by surface class: **very slippery 5.3 · slippery 2.7 · default 1.7 · not-slippery 0.0**.
- Then the polar→Cartesian conversion above, with `vel[1] = 0` (slide keeps horizontal speed only; Y comes from the step).

## Steps & floor-snapping (`perform_ground_quarter_step`, `mario_step.c:258`)

Unlike Q3's trace-up-`STEPSIZE` / move / trace-down bend, SM64 has **no step-up routine and no step-height constant** — it snaps to the floor. Each ground step runs 4 quarter-steps; per quarter-step:

1. Move horizontally at the current Y, then resolve **wall collisions at two fixed heights** — offsets `30` (radius 24) and `60` (radius 50) above the feet (`:267-268`). A riser caught here **blocks** you.
2. `find_floor` at the new XZ, then **snap Y straight to it**: `m->pos[1] = floorHeight` (`:302`).

Consequences:
- **Up:** a small rise is climbed *automatically* if no wall blocks the move — Mario just snaps onto the higher floor. A rise tall enough to register at the ~30/60 u wall samples becomes a **wall you must jump** (with ledge-grab in the air step, `:471`).
- **Down:** snaps down to the floor unless the drop exceeds **100 u**, then `LEFT_GROUND` → fall (`:287`). Ceiling clearance needs `> 160 u` (`:288`, `:298`).
- **No explicit step height** — "steppability" is emergent from floor-snap + whether geometry has a blocking wall. Closer to Godot's `floor_snap_length` than to a step routine.

## Air movement (`update_air_without_turn` / `update_air_with_turn`, `:216` / `:186`)

```
forwardVel ← approach(forwardVel, 0, 0.35)                # weak drag toward 0
if analog input:
    dYaw = intendedYaw − faceAngle[1]
    forwardVel += 1.5 · cos(dYaw) · (intendedMag/32)      # accel toward stick
    with_turn:    faceAngle[1] += 512 · sin(dYaw) · mag   # steer the facing
    without_turn: sidewaysSpeed = 10 · sin(dYaw) · mag    # transient lateral nudge
dragThreshold = (ACT_LONG_JUMP ? 48 : 32)
if forwardVel > dragThreshold: forwardVel −= 1            # drag only ABOVE threshold
vel[0] = forwardVel·sin(faceAngle[1]);  vel[2] = forwardVel·cos(faceAngle[1])
```

- **The decomp's own comment: `//! Uncapped air speed. Net positive when moving forward.` (`:203`, `:234`).** This is Mario's analog of Quake's "strafe jump maxspeed bug": above the threshold speed bleeds only 1/frame while forward input adds 1.5/frame, so moving forward you *net gain*. Long jump raises the threshold to 48 — the engine root of BLJ-style speed retention.
- But steering is a **facing rotation** (`with_turn`) or a **transient** `sidewaysSpeed` recomputed from input each frame (`without_turn`) — **it never accumulates into an off-axis velocity**. So no strafe-jump: velocity stays ≈ `forwardVel·facing`.

## Momentum per action (`set_mario_action_airborne`, `mario.c:776`)

Answers "does a move override momentum?" — **per action**, three behaviors, all real values:

| action | `forwardVel` effect | class |
|---|---|---|
| Jump / Double / Triple | **× 0.8** | **preserve** (scaled) |
| Long jump | **× 1.5**, cap 48 | **build** |
| Dive | **+ 15**, cap 48 | **build** |
| Backflip | **= −16** | override (backward) |
| Side flip | **= 8**, snap `faceAngle = intendedYaw` | override |
| Wall kick | **= 24** | override |
| Slide kick | **= 32** (with `vel[1] = 12`) | override |
| Lava boost | **= 0** (with `vel[1] = 84`) | override |

So **normal jumps keep ~80% of your speed** (not a reset); dive/long-jump *add* to it; flips/kicks *reset* it. `mario_set_forward_vel(m, X)` (`mario.c:374`) is the one-line "commit a scripted speed" primitive — trivial precisely because momentum is a single scalar. Vertical `vel[1]` is likewise scripted per action (e.g. lava boost 84, burning jump 31.5, slide kick 12, jump kick 20).

## Water (`mario_actions_submerged.c`)

A **3D extension of the polar model** — scalar `forwardVel` + **pitch** (`faceAngle[0]`) + **yaw** (`faceAngle[1]`), with buoyancy replacing gravity:

```
vel[0] = forwardVel · cos(pitch) · sin(yaw)     # :250
vel[1] = forwardVel · sin(pitch) + buoyancy     # :251
vel[2] = forwardVel · cos(pitch) · cos(yaw)     # :252
```

- **Buoyancy** (`get_buoyancy`, `:52`) is a vertical bias — ~`-2` normal (slow sink), `-18` metal cap; `vel[1]` eases toward it (`:221`). No gravity.
- **Stroke propulsion**: idle drag pulls `forwardVel → 0` at 1.0/frame (`:220`); a breaststroke adds a burst that decays past a threshold (`:235-247`), capped at a max swim speed.
- Swim where you're pitched/aimed — pitch follows the stick. Its own action group (idle / breaststroke / plunge…).

Parallels Q3 water (3D view-directed, no gravity, buoyant sink), but in the polar substrate and **stroke-based** rather than continuous.

## Special surfaces (`m->floor->type`, `include/surface_terrains.h`)

SM64 makes surfaces a real system — well beyond friction:

- **Slipperiness → 4 classes** (`mario_get_floor_class`, `mario.c:387`; `SURFACE_ICE` etc. → very-slippery). The class drives **three** things at once: **decel/friction** × { very-slip **0.2** · slip **0.7** · default **2.0** · not-slip **3.0** } (`apply_slope_decel`), **slope accel** × { **5.3 · 2.7 · 1.7 · 0.0** } (`apply_slope_accel`, `:283`), and whether a slope throws you into a **sliding action** (`mario_floor_is_slippery` / `_slope`). Ice = slide far, accelerate downhill, hard to stop.
- **`SURFACE_SLOW`** — caps `maxTargetSpeed` at 24 vs 32 (`mario_actions_moving.c:438`).
- **`SURFACE_BURNING` (lava)** — touching it forces **`ACT_LAVA_BOOST`**: ejected upward (`vel[1] = 84`) + damage (`mario_actions_moving.c:1233`). A launch hazard — opposite of Q3's swimmable lava.
- **Quicksand** (`SURFACE_*_QUICKSAND`) — `quicksandDepth` sinks you and scales `targetSpeed *= 6.25/depth` (`:447`); deep/instant variants are lethal.
- **Wind / flowing / moving** (`HORIZONTAL_WIND`, `VERTICAL_WIND`, `FLOWING_WATER`, `MOVING_QUICKSAND`) — **force/conveyor** surfaces that *add* velocity (`mario_update_windy_ground`, …), not friction.
- **`SURFACE_HARD*`** — always inflicts fall damage (removes the low-fall grace); **death-plane / instant-warp** surfaces trigger death/area transitions.

So "just different friction?" — no: friction (the decel multiplier) is one of several per-surface effects, alongside slope-accel, speed caps, hazard-launch, sinking, and conveyor forces.

## vs Quake — why it's a different substrate

| | Quake (VQ3) | SM64 |
|---|---|---|
| velocity | Cartesian vector | scalar `forwardVel` + `faceAngle` → derived |
| dispatch | stateless per-tick trace | explicit action FSM |
| turn | instant (free vector) | facing rotates ~11°/frame (skid) |
| air speed gain | strafe-jump: project **off-axis**, accumulates | forward-only "uncapped air speed"; **no off-axis accumulation** |
| speed source | emergent *generation* | scripted per-action (preserve / build / reset) |
| jump | set `vel.z` (270) | set `vel[1]` per action (same idea) |

**Incompatible with Q-likes:** the polar substrate — velocity is always `forwardVel·facing`, so it can't bank the accumulating off-axis component Quake air-strafing needs; turning swings the whole vector (skid). **Portable onto a Cartesian base:** the *verbs* — analog target speed, per-action momentum rules (×0.8 / +15 / ×1.5 / reset), scripted-`velY` jumps, surface-class slope accel — all drop onto a vector mover as velocity-writers.

## Odyssey / Banjo / Spyro

Closed-source, same family (polar speed + facing + moveset FSM). Odyssey differs mainly in tuning: **roll** builds a speed scalar (cap + decay), and its **dive *resets* momentum to a fixed value** (opposite of SM64's `+15` build) — which is why cap-dive-cancel tech exists, to dodge that reset. Substrate unchanged.

## Platformer controller port

`scripts/platformer_controller.gd` implements the researched movement as the
`platformer` character option. It keeps `forward_speed`, facing yaw, vertical
speed, and action state in source units, advances formulas at a 30 Hz-equivalent
rate, then converts motion to metres for Godot. The project scale is `0.0125 m`
per source unit.

Source speed is stored in units per 30 Hz reference frame. Conversion is
`m/s = source_speed × 0.0125 × 30`; source acceleration converts with
`m/s² = source_acceleration × 0.0125 × 30²`. Thus the default `32 u/f` run is
`12 m/s`, the `42 u/f` base jump is `15.75 m/s`, and `4 u/f²` gravity is
`45 m/s²`. A normal jump also adds `0.25 × forward_speed` once before scaling
horizontal speed by `0.8`; that additive term is part of the source action
transition, not a second jump impulse.

Spatial values use the same conversion helper. The default Godot capsule is
`50 u = 0.625 m` in radius and `160 u = 2 m` tall. Floor snap is
`100 u = 1.25 m`; the floor-metadata fallback ray extends `4 u = 0.05 m` above
and `20 u = 0.25 m` below the feet. Fall distance is converted back to source
units before the `1150 u` damage check, while quicksand visual depth is
converted to metres before moving the mesh.

The audited wall-query dimensions are: ground lower `30 u` offset / `24 u`
radius (`0.375 m` / `0.3 m`), ground upper `60 u` / `50 u`
(`0.75 m` / `0.625 m`), air upper `150 u` / `50 u`
(`1.875 m` / `0.625 m`), and swim `10 u` / `110 u`
(`0.125 m` / `1.375 m`). Godot movement currently uses one capsule rather
than separate height-sampled circular wall queries, so the normal capsule uses
the converted upper/air radius and standing clearance. Tests pin every listed
conversion so a future multi-probe implementation cannot silently change the
scale.

Implemented movement actions are walk/decelerate, slope slide, jump chain,
backflip, side flip, long jump, wall kick, dive, ground pound, freefall, lava
boost, and swimming. Jump, dive, long-jump, and flip momentum writers use the
values in `set_mario_action_airborne`; ordinary air motion uses
`update_air_without_turn`.

Normal-ground release decelerates by `1 u/f` at the 30 Hz reference rate.
High-speed input more than 100 degrees behind facing enters a turnaround state
instead of slowly rotating walking velocity: default ground removes `4 u/f`
there, then restarts toward the held direction at `8 u/f`. Slippery classes
apply their source multipliers to that turnaround braking. Slope sliding also
uses the source side-input rotation before downhill acceleration and per-frame
loss.

`CharacterBody3D` is only the collision mover. The controller writes all three
velocity components before `move_and_slide()`: action code owns ground
deceleration and air drag, and exactly one airborne branch owns gravity each
tick. Godot/Jolt does not automatically apply gravity, damping, or rigid-body
friction to a `CharacterBody3D`; the engine-assumption and live platformer
tests pin that separation.

Controls use an independent persisted platformer mapping:

- Move: camera-relative `WASD` by default.
- Jump / breaststroke: `Space`.
- Crouch / long jump / ground pound: `Ctrl`.
- Dive: `E`.
- Mouse: orbit the collision-aware third-person camera.
- View: the persisted `First-person camera` setting switches cameras and hides
  the body mesh; third-person remains the default.

## Player move guide

Original control letters map to this project as follows:

| Original control | Action name | Project input | Default key |
|---|---|---|---|
| Stick | Move | `player_forward/back/left/right` | `WASD` |
| A | Jump / Swim Stroke | `player_jump` | `Space` |
| B | Dive / Attack | `player_special` | `E` |
| Z | Crouch / Ground Pound | `player_crouch` | `Ctrl` |

### Base moves and combinations

- **Run:** hold `WASD`. Reversing more than 100 degrees at speed enters the
  skid/turnaround state.
- **Jump:** press **Jump / Swim Stroke** (`Space`). Releasing it early cuts the
  upward portion short.
- **Double/triple jump:** press **Jump / Swim Stroke** again after consecutive
  moving landings; the third jump needs enough forward speed.
- **Backflip:** hold **Crouch / Ground Pound** (`Ctrl`), then press
  **Jump / Swim Stroke** while stationary or moving slowly.
- **Side flip:** run, reverse direction to start the turnaround, then press
  **Jump / Swim Stroke**.
- **Long jump:** while running, hold **Crouch / Ground Pound**, then press
  **Jump / Swim Stroke**.
- **Wall kick:** jump into a wall, then press **Jump / Swim Stroke** during the
  short wall-contact window.
- **Dive:** press **Dive / Attack** (`E`) while airborne.
- **Ground pound:** press **Crouch / Ground Pound** while airborne.
- **Swim:** steer with `WASD`; press **Jump / Swim Stroke** for a speed stroke.

The original moveset also includes punches, a finishing kick, jump kick, slide
kick, crawling, ledge grabs, pole climbing, and dive rollouts. Those actions are
not yet implemented by this controller.

### Common movement techniques

- **Jump-dive:** jump, then dive to extend horizontal distance.
- **Triple-jump setup:** keep moving and time jumps across consecutive
  landings.
- **Wall-kick chain:** alternate walls to climb narrow spaces.
- **Slope movement:** steer a downhill slide and jump out toward the target.
- **Dive rollout:** in the original moveset, press Jump or Attack during the
  belly slide to preserve momentum; not yet implemented here.
- **Backward long-jump speed build:** an original-game exploit using repeated
  backward long jumps on suitable stairs or slopes; exact behavior is not yet
  implemented here.

Floor behavior is selected with `platformer_surface` metadata. Supported values are
`ice` / `very_slippery`, `slippery`, `not_slippery`, `slow`, `hard`,
`quicksand`, `moving_quicksand`, `burning`, `horizontal_wind`,
`vertical_wind`, and `flowing_water`. Force surfaces optionally use a
`platformer_force_direction` `Vector3`. Water is an `Area3D` on collision layer
2 with `platformer_medium = "water"`.

The primitive test level contains pads for every supported special floor,
four class-specific slope fixtures, a flowing-water pool, and burning lava.
It is 180 × 180 metres to keep those fixtures separate from the Q3 course.

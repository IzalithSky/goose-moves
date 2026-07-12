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

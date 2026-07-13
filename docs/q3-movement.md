# Quake 3 Movement — Principles

Source-verified against `references/Quake-III-Arena/code/game/{bg_pmove.c,bg_slidemove.c,bg_local.h}` (VQ3, GPLv2). CPM/CPMA differences noted where relevant.

## Core model

- **Velocity-based, semi-implicit Euler.** Forces modify velocity; position = velocity·dt with collision. No acceleration is stored between frames.
- **Per tick:** derive situation from traces → subtract friction → add input accel → integrate + collide (+gravity if airborne).
- **State split:** *persistent* (`ps`: velocity, `pm_type`, `pm_flags`, `pm_time`) vs *transient, rebuilt every tick* (`pml`: `walking`, `groundPlane`). Grounded-ness is **re-traced each frame, never stored** — no locomotion state machine.
- **Fixed timestep.** The command is chopped into steps ≤ `pmove_msec` (if `pmove_fixed`) else ≤ 66 ms, to avoid framerate-dependent physics. With `pmove_fixed 0`, higher fps subtly changes accel — the classic strafe-jump fps dependence.

## Forces — world (not from input)

| Force | Effect | Applied when | NOT applied when |
|---|---|---|---|
| **Gravity** | `v.z -= g·dt` (g=800), trapezoidal-averaged | airborne (`StepSlideMove` gravity=true) | on walkable ground — **except** SLICK surface or knockback |
| **Ground friction** | `drop = max(speed,100)·6·dt` (stopspeed floor → hard stop below 100 u/s) | `walking` | airborne; SLICK surface; `PMF_TIME_KNOCKBACK` |
| **Water/flight/spectator friction** | linear drag `speed·f·dt` | in water / flight powerup / spectating | otherwise |
| **Collision clip (slide)** | `out = in − n·(in·n)·OVERCLIP`, OVERCLIP=1.001 | every move, per contact plane | — |

Clip removes only the into-surface component → **tangential speed is preserved** (wall-strafing, ramp jumps keep horizontal speed). Steps ≤ 18 u are auto-climbed (`STEPSIZE`).

## Forces — player input

| Force | Effect | Applied when | NOT applied when |
|---|---|---|---|
| **Accelerate toward wishdir** | see below | always (ground & air) | already ≥ wishspeed along wishdir (`addspeed ≤ 0`); no input |
| **Jump** | `v.z = 270` (**set, not add**) | on ground + jump pressed | jump held since last jump; `upmove < 10`; respawn frame |

```
currentspeed = dot(v, wishdir)          # projection of velocity onto desired dir
addspeed     = wishspeed - currentspeed
if addspeed <= 0: return                # cap is on the PROJECTION, not total speed
accelspeed   = min(accel·dt·wishspeed, addspeed)
v += accelspeed · wishdir
```

- **accel:** ground `pm_accelerate = 10`, air `pm_airaccelerate = 1`. SLICK/knockback ground also uses air accel (1).
- **wishspeed** derived from input, capped at `ps->speed = 320` on ground (duck/water scale it lower). **No 30-cap** — that's Quake1/Source, not Q3.
- Jump sets z-velocity, so it never stacks; and it requires a key release each time → **no hold-to-bhop in VQ3**.

### Crouch & slow walk

- **Crouch** is a held down-input (`upmove < 0`), not a toggle. `PM_CheckDuck`
  keeps the 30×30 footprint, changes the hull from z `-24..32` (56 u) to
  `-24..16` (40 u), and drops viewheight from 26 to 12. Releasing crouch only
  stands if a zero-length trace with the standing hull is clear. While walking,
  `pm_duckScale = 0.25` caps wishspeed at 80 u/s; it is not an extra friction.
- **Slow walk** is produced client-side: with `cl_run 1` (the default), holding
  `+speed` sends forward/right input at 64 instead of 127 and sets
  `BUTTON_WALKING`. The resulting full-input wishspeed is `320 × 64 / 127` =
  **161.26 u/s**. `BUTTON_WALKING` selects walk animations and suppresses
  footsteps; the server clears it if either move component exceeds 64.

### Configurable collider and third-person view

The Q3 controller profile exposes **Character size X/Y/Z** in metres. Y is the standing, feet-anchored hull height; crouching preserves the Q3 `40/56` height ratio, and both eye height and the collision offset scale with the active stance. X and Z independently control the box width and depth.

The **Third-person camera** toggle switches from the eye camera to a collision-aware spring arm. **Third-person distance** configures its length from `0.5–15 m` (`4 m` by default). A translucent box mesh becomes visible only in third person and is synchronized to the live `BoxShape3D` size and local position, including profile resizing and crouching, so the rendered box is an exact visualization of the character collider.

## Key emergent behaviors

- **Strafe jumping / speed > 320:** because the cap is on the projection, an off-axis wishdir keeps adding speed → total velocity grows unbounded. id's own code calls this the *"strafe jump maxspeed bug"*; the physically-correct clamp is present but `#if`'d out ("feels bad").
- **No air control in VQ3:** `PM_AirMove` only accelerates; it never rotates velocity toward view. CPM adds that (plus air-stop accel, strafe accel with a ~30 wishspeed cap, and double-jump).

## Slopes & stairs

**Walkable test** (`PM_GroundTrace`, `bg_pmove.c:1107`) — a full-hull 0.25 u down-probe each tick (0.009525 m at this project's scale). Walkable only if `normal.z ≥ MIN_WALK_NORMAL (0.7 ≈ 45°)`; steeper → `groundPlane = true` but `walking = false`, so it runs the **air path and slides down** under gravity. A "kickoff" case (moving up *and* away from the plane, `dot(vel,normal) > 10`) also drops grounding — this is what lets you leave a ramp.

**Walking a slope** (`PM_WalkMove`) — the forward/right input basis is clipped onto the ground plane so movement follows the surface; after accel, velocity is clipped to the plane then **rescaled to its pre-clip magnitude**. Slopes redirect velocity but cost **no speed**.

**Slide** (`PM_SlideMove`, `bg_slidemove.c:45`) — collide-and-slide, ≤ 4 iterations: move, and on impact clip velocity along the contact plane; slide along a 2-plane crease (cross product), dead stop at a 3-plane corner. Keeps tangential speed — but a vertical stair riser alone just stops you.

**Step-up** (`PM_StepSlideMove`, `bg_slidemove.c:233`) — if the plain slide was blocked: trace **up by STEPSIZE (18 u)**, redo the slide from up there (clears the riser), then trace back **down** onto the step and clip to the landing plane. So **steps ≤ 18 u auto-climb; taller = wall**. Skipped while moving upward (no stepping mid-jump). Emits `EV_STEP_*` events → the client smooths the camera's vertical rise. Descending isn't snapped — you fall to the next step.

## Water

**Level is a 0–3 sample** (`PM_SetWaterLevel`, `bg_pmove.c:1205`) — probes bottom / mid-body / eye height each tick; uses `viewheight`, so ducking shifts it. `watertype` (water/slime/lava) doesn't affect movement, only damage.

**The blend is a hard threshold, not a gradient** — swimming engages only at `waterlevel > 1`:
- **0–1 (dry / wading, depth < ~½ body):** normal `WalkMove`/`AirMove` with full ground control; water only *bleeds in* as friction (`drop += speed·waterfriction·waterlevel·dt`, `:208`) and a wishspeed cap (~0.83× at level 1, `:760`). Swimming does **not** engage until waist-deep.
- **2 (waist) / 3 (submerged):** `PM_WaterMove` (`:471`) — **identical movement**. They differ only in friction ×depth (2× vs 3×), water-jump allowed at level 2 only (`:410`), and level-3 head-under events + drowning + fall immunity.

**Swimming** (`PM_WaterMove`): 3D wishdir from the **full view vector** + jump/crouch for up/down (swim where you look); **no input → sink** (`wishvel = (0,0,-60)`, `:506`); speed capped at `swimScale·320 = 160` (`:517`); `wateraccelerate 4`; **no gravity** — neutral buoyancy (`PM_SlideMove(qfalse)`, `:534`); slope-preserve so you swim up ramps (`:524`).

**Falling into water** — dispatch flips to swim once `waterlevel > 1`; water friction bleeds inbound velocity and gravity stops. Fall damage is depth-cushioned in `PM_CrashLand`: level 3 → **none**, level 2 → ×0.25, level 1 → ×0.5 (ducking-while-falling doubles it first).

**Water-jump** (`PM_CheckWaterJump`, `:400`) — at waist depth facing a ledge with clearance above, launches `forward·200, z = 350` for 2 s with no control + gravity (`PM_WaterJumpMove`), cancelled once you start falling.

## Special surfaces

Q3 keeps this minimal — surface *flags* (`SURF_*`) for surfaces, content types for volumes.

- **`SURF_SLICK` (ice)** — the only flag that changes *movement*, and it's **more than friction**: ground friction is skipped (`:197`), ground accel drops to `pm_airaccelerate` (1, not 10) (`:772`), and gravity is applied *while walking* (`:783`) so you slide down slopes. (Same branch as `PMF_TIME_KNOCKBACK`.) Net: no grip, barely steerable, gravity-driven slide.
- **`SURF_NODAMAGE`** — negates fall damage in `PM_CrashLand` (`:984`). `SURF_METALSTEPS`/`NOSTEPS`/`FLESH`/`DUST` are audio/FX only.
- **Lava / slime** (`CONTENTS_LAVA`, `CONTENTS_SLIME`) — **not** a movement special-case: `MASK_WATER` includes them, so you *swim* them exactly like water (the type-specific swim code is `#if 0`'d, `:487`); they differ only in damage (game code) and fog. Q3 lava is a swimmable volume, not a launch hazard.

So "just different friction?" — no for ice (friction-off + air-accel + gravity), and lava/slime aren't a friction case at all.

## Per-tick order (`PmoveSingle`)

1. `UpdateViewAngles`
2. `SetWaterLevel` · `CheckDuck` · `GroundTrace`  — derive state
3. `DropTimers`
4. dispatch **one** of: Fly / Grapple / WaterJump / Water / **Walk** / **Air**
   (each: `Friction` → build wishdir/wishspeed → `Accelerate` → `StepSlideMove` [+gravity if air])
5. `GroundTrace` + `SetWaterLevel` again — for next frame + land events
6. `Weapon`

## Scale & Godot conversion

Q3 game units are arbitrary: the movement code has no SI conversion. The
[Q3Radiant mapping manual](https://icculus.org/gtkradiant/documentation/q3radiant_manual/appndx/appn_c.htm)
uses the conventional scale **8 units ≈ 1 foot (30.48 cm)**. Use that convention
when moving this controller to Godot, whose default 3D unit is one metre:

- **1 Q3 unit = 0.0381 m**; **1 m = 26.247 Q3 units**.
- The 30×30×56 Q3 player hull becomes **1.143×1.143×2.134 m**. Its 50-unit
  standing eye height (`MINS_Z = -24`, `viewheight = 26`) becomes **1.905 m**.
- Convert every value carrying a distance dimension: `g_speed 320` → **12.192
  m/s**, `g_gravity 800` → **30.48 m/s²**, jump velocity 270 → **10.287 m/s**,
  stop speed 100 → **3.81 m/s**, and `STEPSIZE 18` → **0.6858 m**.
- Keep the dimensionless tuning values unchanged: acceleration **10 / 1**,
  friction **6**, `OVERCLIP` **1.001**, and the walk normal **0.7**.

The mapping manual describes the scale as approximate, so it is a convention
rather than an engine-enforced physical unit. The project controller uses this
convention consistently.

## Constants (VQ3)

`g_speed 320` · `g_gravity 800` · `JUMP_VELOCITY 270` · `pm_accelerate 10` · `pm_airaccelerate 1` · `pm_friction 6` · `pm_stopspeed 100` · `OVERCLIP 1.001` · `STEPSIZE 18` · `MIN_WALK_NORMAL 0.7` · `pm_swimScale 0.5` · `pm_wateraccelerate 4` · `pm_waterfriction 1`

(CPM tuning differs: accel 15, +air control ~150, air-stop accel ~2.5, strafe accel ~70, wishspeed 30, friction ~8.)

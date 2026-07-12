# Unity MVP Movement vs Q3 / CPMA

Comparison of `references/mvp_unity_game/Assets/Scripts/Player/MovementController.cs` against Q3 (see [q3-movement.md](q3-movement.md)). All `:N` line refs are that file.

## Verdict

Same **accelerate core** as Quake (projection-based), but **Rigidbody/force-based** (not Q3's kinematic velocity+slide), and the **ground friction is counter-drift** — velocity-snapping, the *opposite* of Q3. Air path is VQ3-style strafe-jump-capable; **no CPMA air control** anywhere.

## Architecture

| | Q3 | Unity MVP |
|---|---|---|
| Integration | custom semi-implicit Euler, owns velocity | `Rigidbody` + `AddForce`, PhysX owns it |
| Collision | trace + `ClipVelocity` slide | PhysX capsule + a ground-stick force hack (`:300`) |
| Timestep | fixed, move chopped | `FixedUpdate` (`:85`) ✓ |
| Grounded | `PM_GroundTrace` each tick | `SphereCast` each tick (`:145`) — re-derived, no FSM ✓ |
| Gravity | only airborne (in slide) | `useGravity` toggled off when grounded (`:153`) ✓ |
| Determinism | high | engine-dependent |

## Accelerate core — aligned ✓

`RegularMovement()` (`:243`) is the Q3 `PM_Accelerate` shape:

```
Q3                                    Unity (:244)
current = dot(vel, wishdir)           dot(planarVel, moveDir)
add     = wishspeed - current         dv = maxspd - that
if add <= 0: return                   moveDir != 0 && dv > 0
step = min(accel·dt·wishspeed, add)   a = min(currentAccel, dv/dt)
vel += step·wishdir                   vel += a·dt·moveDir
```

Cap is on the **projection**, not total speed → off-axis input can grow speed = the strafe-jump mechanism, present in both. (Only diff: Q3's step scales with `wishspeed`; Unity's is a constant `currentAccel`.)

## Also aligned ✓

- Grounded re-traced every tick (no locomotion FSM).
- Gravity only when airborne.
- Fixed timestep.
- **Air path is VQ3-like**: airborne cap `airSpeed = 1`, `airAcceleration = 20` (`:164-168`), and friction is skipped in air → off-axis air-strafe gains speed. Mechanically bhop-capable.
- "Don't overshoot" clamp on friction (`:335`) ≈ Q3 clamping `accelspeed` to `addspeed`.

## Diverges ✗

- **Ground friction = counter-drift, the opposite of Q3.** `ApplyFrictionCounterDrift()` (`:326`) steers velocity toward `moveDir·maxspd`, deleting off-axis and excess speed. Q3 friction only scales speed toward zero, never steers → here ground speed is hard-capped at `runSpeed`, there's no ground strafe, and **landings scrub excess speed, killing bhop chains**. Arcade-tight, not Quake.
- **Rigidbody + `AddForce`** vs a kinematic mover → needs the ground-stick force hack (`:300`), less deterministic, engine collision.
- **Jump = additive impulse + timer**: `AddForce(up·jumpForce, Impulse)` (`:290`) with a `jumpDelay` cooldown (`:267`), vs Q3 *setting* `velocity.z = 270` and gating on key-release.
- **No CPMA layer**: no air control, air-stop accel, strafe-accel branch, or double jump.
- **Real-world scale** (`runSpeed 8` / `walkSpeed 4` m/s) vs Q3 320 ups.

## Slopes & stairs

**Slopes — aligned, but no walkable-angle limit:**
- `GetSurfaceNormalInPoint()` (`:171`) raycasts down (`slopeProbeDistance = 1`) for the surface normal, then `Quaternion.FromToRotation(up, surfaceNormal)` rotates `moveDir` into the slope plane (`:158-162`) — movement follows the surface (≈ Q3's plane-projected forward/right).
- Accel and friction both run in-plane via `ProjectOnPlane(velocity, surfaceNormal)` (`:244, :321, :328`).
- A **grounding force** `-surfaceNormal · groundingAcceleration (80)` (`:300`) presses the capsule into the surface — Unity's stand-in for Q3's ground trace + snap; keeps you stuck over crests and downslopes instead of launching (the dynamic-Rigidbody tax).
- **No `MIN_WALK_NORMAL`** — any surface the down-ray hits counts as walkable; there's no steep-slope slide-off. Diverges from Q3 (which slides below `normal.z 0.7` / ~45°).

**Stairs — force-boost, not Q3's kinematic bend:**
- `StairMovement()` (`:194`) fires 3 forward probes (`stepProbesCount`) up to `maxStepHeight (0.5)`; if a low probe hits but an upper probe at step height is clear, it's a climbable step → `isSteppingUp` (`:222-239`).
- `ExecuteMovements()` then adds **upward** `stairsClimbingAcceleration (35)` (`:296`) to lift the Rigidbody over it (the grounding force is suppressed while stepping, `:299`).
- vs Q3: Q3 repositions kinematically (trace up 18 / move / trace down) — instant, exact, momentum-independent. Unity **applies an upward force and relies on forward momentum** to carry you up — the standard dynamic-Rigidbody workaround, but tuning-sensitive (can bounce or vary with speed). Step heights are comparable (0.5 m ≈ 18 u).

## To move it toward Q3 / CPMA

1. Replace `ApplyFrictionCounterDrift` with proportional scale-to-zero friction, **ground only** (Q3 `PM_Friction` + stopspeed floor). This alone restores momentum/bhop.
2. Prefer a kinematic velocity + slide mover over the dynamic Rigidbody for determinism — or at minimum, stop steering velocity with friction.
3. Jump: **set** vertical velocity instead of an additive impulse; gate on key-release, not a timer.
4. CPMA: extend the air path only — aircontrol (rotate velocity toward view, forward-only), air-stop accel, strafe-accel branch (`wishspeed ~30`), and double-jump. See the CPM constants in [q3-movement.md](q3-movement.md).

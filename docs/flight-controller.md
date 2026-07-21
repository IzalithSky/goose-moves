# Flight Controller Logic

The flight controller is a direct-orientation port of the plane-style mechanics
from `../merlin`. It does not integrate angular velocity or torque. Each physics
frame derives a target body basis from velocity and camera input, writes
`global_basis` directly, then lets aerodynamic forces bend the velocity over
time.

## Frame order

`scripts/flight_controller.gd` runs the controller in this order:

1. Decrement flap cooldown.
2. Collect discrete input (`player_jump` can apply a flap impulse).
3. Measure current angle of attack and sideslip from local velocity.
4. Apply gravity, aerodynamic lift/drag, and extra drag to velocity.
5. Apply direct rotation from velocity/camera controls.
6. Move with `move_and_slide()`.
7. Apply collision response and Q3-style floor friction if grounded.
8. Move the camera rig to the character.

This matters because the displayed AoA/sideslip are measured before the current
frame's direct rotation, and forces for the current frame use that measured
state.

## Coordinate conventions

Godot body axes are used directly:

| Axis | Meaning |
|---|---|
| `-global_basis.z` | body forward / nose direction |
| `global_basis.x` | body right |
| `global_basis.y` | body up |

Velocity is transformed into local body space for aerodynamic angles:

```gdscript
air_velocity_local = global_basis.orthonormalized().transposed() * velocity
flow_forward = -air_velocity_local.z
flow_up = air_velocity_local.y
flow_right = air_velocity_local.x
```

## Camera controls

Mouse input updates a detached camera rig:

- Horizontal mouse changes `camera_yaw`.
- Vertical mouse changes `camera_pitch`, clamped to `-75°..60°`.
- The camera rig is top-level and follows character position, so camera pitch is
  a control input, not a child rotation inherited from the aircraft body.

The controller interprets camera pitch as requested AoA. It does not try to put
the nose at a particular world/horizon pitch.

## Heading and bank

The controller first chooses a heading reference from velocity:

- Use horizontal velocity projected onto the world XZ plane.
- If horizontal speed is too small, fall back to the current body forward.
- If that is also degenerate, use `Vector3.FORWARD`.

It then compares that heading to the camera's flat forward direction and computes
a yaw error. Bank is driven directly by that yaw error:

```gdscript
target_bank_angle = clamp(-yaw_error, -max_bank_angle, max_bank_angle)
```

So the nose/camera yaw-to-bank ratio is 1:1 until the configured bank limit is
hit. The `Max bank angle` setting is parameterized with a `0°..90°` range. The
current default comes from `DEFAULT_MAX_BANK_ANGLE_DEGREES`.

Bank does not directly yaw the aircraft as an input. Instead, bank tilts the lift
vector. Tilted lift curves velocity sideways; on following frames the heading
reference follows that changed velocity, so the aircraft turns.

## Pitch and AoA

Pitch is applied as a target angle of attack relative to the flight path:

1. Start with `camera_pitch`.
2. Clamp it through the max-lift AoA limiter when airspeed is high enough.
3. Scale only pitch-down by bank angle.
4. Build the target body basis from the resulting AoA and target bank.

Positive AoA/pitch-up is not reduced by bank. Negative AoA/pitch-down is reduced
linearly as bank approaches the configured max bank:

```gdscript
bank_fraction = abs(target_bank_angle) / max_bank_angle
scaled_pitch_down = target_aoa * (1.0 - bank_fraction)
```

At zero bank, full camera-derived pitch-down applies. At max bank, pitch-down is
zero. This prevents hard nose-down input at knife-edge/max-bank while preserving
pitch-up authority.

## High-bank alignment path

There are two direct-rotation construction paths:

- Below `HIGH_BANK_AOA_ALIGNMENT_START_RAD` (`60°`), target forward is built from
  horizontal heading plus AoA against world up, then banked around that forward
  axis.
- At higher bank, target right/up are built around the actual airflow direction,
  then AoA is applied around target right.

The high-bank path keeps camera pitch behaving as character-relative AoA even
near knife-edge. A camera pitch above neutral pitches in body-relative up; a
camera pitch below neutral pitches in body-relative down, subject to the
pitch-down bank scaling described above.

## Skid / slip measurement

Sideslip is measured in body space from lateral velocity:

```gdscript
sideslip_deg = rad_to_deg(atan2(flow_right, sqrt(flow_forward² + flow_up²)))
```

This is a diagnostic angle. It says how much of the velocity is moving through
the character's right/left side, relative to the forward/up plane.

Angle of attack is measured from the same local velocity:

```gdscript
aoa_deg = rad_to_deg(-atan2(flow_up, flow_forward))
```

## Skid / slip compensation

The compensation is an always-local weathervane yaw unless the setting is turned
off. It uses only the velocity component in the character's yaw plane:

```gdscript
axial = velocity.dot(-global_basis.z)
lateral = velocity.dot(global_basis.x)
skid = atan2(lateral, axial)
correction = clamp(-skid, -max_yaw_per_frame, max_yaw_per_frame)
global_basis = Basis(global_basis.y, correction) * global_basis
```

Important properties:

- It yaws around `global_basis.y`, the character's local up axis.
- It ignores vertical/up velocity for correction.
- It works at any bank because body right/up are used, not world right/up.
- It is capped by `Sideslip yaw step` per physics frame.
- It can be disabled with the `Sideslip compensation` toggle.

With compensation enabled, the character yaws so its forward axis aligns with
the velocity projection in its own yaw plane. At `90°` bank, one side of the
character may point toward world up/down; the correction is still local yaw and
does not become pitch.

## AoA limiter

The max-lift AoA limiter is derived from the lift coefficient table:

- Positive limit = the positive-AoA table point with the highest lift
  coefficient.
- Negative limit = the negative-AoA table point with the lowest lift
  coefficient.
- If one side is missing, it mirrors the other side.

When airspeed is below `MAX_LIFT_AOA_MIN_AIRSPEED`, camera pitch is used
directly. At or above that speed, requested camera pitch is clamped to the
derived negative/positive max-lift AoA range before bank-dependent pitch-down
scaling.

This means camera pitch requests AoA, but the limiter prevents requesting beyond
the stall-side peak of the configured lift curve at meaningful airspeed.

## Aerodynamic forces

Aerodynamic force is based on speed squared:

```gdscript
dynamic_pressure = 0.5 * air_density * speed²
drag = -airflow_direction * dynamic_pressure * reference_area * drag_coefficient
lift = lift_axis * dynamic_pressure * reference_area * lift_coefficient
```

Lift/drag coefficients are sampled from the AoA tables. Lift is perpendicular to
the relative wind in the body's symmetry plane:

```gdscript
lift_axis = global_basis.x.cross(airflow_direction).normalized()
```

This avoids using body-up lift directly, which would add an along-flightpath
retarding component and double-count drag already represented by the drag table.

## Flap impulse

`player_jump` applies an instantaneous velocity impulse, similar to Q3's normal
jump model, instead of constant thrust over a fixed time.

The impulse direction blends local forward and local up:

```gdscript
axis = forward * cos(angle) + up * sin(angle)
velocity += axis.normalized() * flap_impulse_strength
```

Parameters:

- `Flap impulse strength` controls velocity added in m/s.
- `Flap impulse angle` ranges from forward (`0°`) to straight up (`90°`), with
  `45°` as the default.
- `Flap cooldown` prevents repeated impulses until the timer expires, with
  `0.5 s` as the default.

## Tunable flight parameters

The flight settings exposed in `scripts/settings.gd` are:

| Setting | Effect |
|---|---|
| `Field of view` | Camera FOV |
| `Mouse sensitivity` | Camera yaw/pitch sensitivity |
| `Camera distance` | Spring arm length |
| `Gravity scale` | Multiplier on project gravity |
| `Mass` | Divisor for force-to-velocity integration |
| `Flap impulse strength` | Instant flap velocity delta |
| `Flap impulse angle` | Forward/up blend for flap impulse |
| `Flap cooldown` | Minimum time between flap impulses |
| `Max bank angle` | Clamp on target bank, range `0°..90°` |
| `Sideslip compensation` | Enables/disables local yaw weathervaning |
| `Sideslip yaw step` | Max compensation yaw per physics frame |
| `Reference area` | Scales aerodynamic lift/drag |
| `Extra quadratic drag` | Adds non-table quadratic drag |

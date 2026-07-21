# Flight Controller Logic

The flight controller is a direct-orientation port of the plane-style mechanics
from `../merlin`. It does not integrate angular velocity or torque. Each physics
frame derives a target body basis from velocity and input state, writes
`global_basis` directly, then lets aerodynamic forces bend the velocity over
time.

## Frame order

`scripts/flight_controller.gd` runs the controller in this order:

1. Decrement flap cooldown.
2. Collect pitch/roll input from camera FBW or manual fallback (`player_jump`
   can apply a flap impulse).
3. Measure current angle of attack and sideslip from local velocity.
4. Apply gravity, aerodynamic lift/drag, and extra drag to velocity.
5. Apply direct rotation from pitch/roll input around the current body axes.
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
- The camera rig is top-level and follows a point above the character, so the
  body sits below the look ray instead of obscuring the target.

With `Camera fly-by-wire` enabled, the camera look ray defines a virtual
checkpoint. If the ray hits world geometry, that hit is the target. Otherwise,
the target is `FBW target distance` meters along the camera look direction.
The controller then flies the character toward that target by changing only the
pitch and roll command inputs.

With `Camera fly-by-wire` disabled, mouse/camera movement is view-only and
manual W/S/A/D pitch/roll controls are used.

## Camera fly-by-wire

The camera FBW mode is a reduced port of Merlin's bot target-following control:

1. Convert the world target direction into the character's local body basis.
2. Measure the local turn angle from the body-forward axis.
3. Roll to put the lift vector on the target bearing.
4. Pull pitch in proportion to turn angle and lift-vector alignment.
5. Smooth the resulting pitch and roll inputs before direct rotation.

Only target following is ported. The flight controller does not use Merlin's
collision avoidance, overspeed/underspeed handling, throttle management,
engagement/aggro logic, or weapon behavior.

## Pitch and roll controls

When camera FBW is disabled, flight uses the controller keybinding actions:

| Action | Default key | Effect |
|---|---:|---|
| `player_forward` | W | Pitch down |
| `player_back` | S | Pitch up |
| `player_left` | A | Roll left |
| `player_right` | D | Roll right |
| `player_jump` | Space | Flap |

Pitch keys command a pitch rate around the current body-right axis:

```gdscript
pitch_input = Input.get_action_strength("player_back") - Input.get_action_strength("player_forward")
pitch_delta = aoa_limit(pitch_input * DEFAULT_PITCH_RATE_DEGREES_PER_SECOND * delta)
basis = Basis(body_right, pitch_delta) * basis
```

Roll keys command a roll rate around the current body-forward axis:

```gdscript
roll_input = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
basis = Basis(body_forward, roll_input * DEFAULT_ROLL_RATE_DEGREES_PER_SECOND * delta) * basis
```

Both the manual fallback and the camera FBW output are applied around the
character body axes at the start of the frame, matching Merlin's body-basis
control torque mapping. They are not camera-relative or world-up-relative.

There is no bank limiter. Roll is only limited by the per-frame roll rate.

Roll does not directly yaw the aircraft. Instead, roll tilts the lift vector.
Tilted lift curves velocity sideways, while slip/skid compensation yaws the
aircraft toward the local yaw-plane velocity.

## Pitch and AoA

Pitch is applied as a body-relative rate command:

1. Start with the active pitch-rate command from camera FBW or manual W/S fallback.
2. Clamp the pitch delta through the max-lift AoA limiter when airspeed is high enough.
3. Rotate the body around its current right axis by that limited pitch delta.

## Basis construction

Direct rotation uses the current body basis. AoA is still measured as the angle
between the nose and the relative wind (velocity), never between the nose and
the horizon:

- Pitch rotates around `global_basis.x`.
- Roll rotates around `-global_basis.z`.
- Slip/skid compensation then yaws around `global_basis.y`.

S pitches in body-relative up; W pitches in body-relative down. A/D roll around
the nose. The AoA limiter still applies at any roll angle, including knife-edge.

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

When airspeed is below `MAX_LIFT_AOA_MIN_AIRSPEED`, the active pitch delta is
used directly. At or above that speed, the requested pitch delta is clamped so the
resulting AoA stays inside the derived negative/positive max-lift range.

This means pitch commands request AoA, but the limiter prevents requesting
beyond the stall-side peak of the configured lift curve at meaningful airspeed.

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
| `Mouse sensitivity` | Orbit camera yaw/pitch sensitivity |
| `Camera distance` | Spring arm length from the elevated chase pivot |
| `Gravity scale` | Multiplier on project gravity |
| `Mass` | Divisor for force-to-velocity integration |
| `Flap impulse strength` | Instant flap velocity delta |
| `Flap impulse angle` | Forward/up blend for flap impulse |
| `Flap cooldown` | Minimum time between flap impulses |
| `Camera fly-by-wire` | Enables/disables camera target following |
| `FBW target distance` | Fallback target distance along the camera look ray |
| `Sideslip compensation` | Enables/disables local yaw weathervaning |
| `Sideslip yaw step` | Max compensation yaw per physics frame |
| `Reference area` | Scales aerodynamic lift/drag |
| `Extra quadratic drag` | Adds non-table quadratic drag |

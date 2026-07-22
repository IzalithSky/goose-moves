# Q3 + Flight Controller

The Q3 + Flight controller is a hybrid character controller that uses Q3-style
arena movement as the default locomotion mode and switches into the flight
controller while airborne under explicit, tunable conditions.

It is implemented as a small state machine in `scripts/q3_n_flight_controller.gd`
with two composed movement motors:

- `Q3MovementMotor` for grounded / walking / jumping / Q3 extensions.
- `FlightMovementMotor` for airborne flight, flap impulse, aerodynamics, and
  camera fly-by-wire.

The controller owns one `CharacterBody3D`. Both motors write to the same body,
so velocity and position are naturally shared. State transitions preserve
momentum by preserving the body's `velocity` vector instead of copying between
separate character instances.

## Default behavior

The controller starts in Q3 mode.

Default Q3-side behavior:

- Q3 movement mode: `Warsow Classic (CPM-like)`.
- Autojump: enabled.
- Camera: third-person.
- FOV: `80°`.
- Crouch key: `Ctrl`.
- Special / Wall Jump key: `E`.
- Collision size: fixed to the flight collision box, `1.2 m × 1.2 m × 1.2 m`.

Default flight-side behavior:

- Camera: third-person.
- Camera fly-by-wire: enabled.
- FBW direct-pitch window: `15°`.
- Flap / jump key: `Space`.

Default hybrid gates:

| Setting | Default | Meaning |
|---|---:|---|
| `flight_hold_threshold` | `0.3 s` | Jump/flap must be held this long before flight can activate. |
| `flight_no_contact_threshold` | `0.3 s` | The body must have touched no surface for this long. |
| `flight_min_activation_speed` | `12.0 m/s` | Velocity length must be at least this high. |

Default body-bounce / knockdown:

| Setting | Default | Meaning |
|---|---:|---|
| `body_bounce` | on | Enables high-speed body impacts. |
| `body_bounce_min_normal_speed` | `14.0 m/s` | Minimum incoming speed into the hit normal. |
| `body_bounce_knockdown_duration` | `1.2 s` | Time with movement control disabled after impact. |
| `body_bounce_restitution` | `0.75` | Reflected velocity scale after impact. |

## State machine

The controller has two modes:

```gdscript
enum Mode {
    Q3,
    FLIGHT,
}
```

### Q3 mode

In Q3 mode, physics is delegated to `Q3MovementMotor`. This is the default mode
and remains active while grounded, walking, jumping, wall-jumping, crouch
sliding, swimming, or otherwise using the Q3 movement path.

Each frame:

1. Track how long jump/flap has been held.
2. Run Q3 movement physics.
3. Check high-speed impact bounce.
4. Update the no-surface-contact timer.
5. If all flight gates pass, transition to flight mode.

Flight can activate only when all conditions are true:

```gdscript
not knocked_down
and flap_hold_time >= flight_hold_threshold
and no_surface_contact_time >= flight_no_contact_threshold
and velocity.length() >= flight_min_activation_speed
```

The no-contact gate prevents flicker while standing on the floor, sliding along
walls, scraping ceilings, or repeatedly touching any collision surface. The
speed gate prevents slow hops from entering flight accidentally.

### Flight mode

In flight mode, physics is delegated to `FlightMovementMotor`.

Each frame:

1. Track held jump/flap input.
2. Run flight process and camera logic.
3. Run flight physics and aerodynamics.
4. Check high-speed impact bounce.
5. If any surface contact is detected, transition back to Q3 mode.

Any floor, wall, ceiling, or slide collision counts as surface contact. This is
intentionally broad: flight mode is only for free-air movement.

## Q3 → Flight transition

The transition preserves:

- `global_position`
- `velocity`
- camera view continuity through a short camera blend

The body orientation is rebuilt for flight. The controller starts from the Q3
view basis and tries to align the flight nose with the takeoff velocity in the
view pitch plane:

1. Take the current view forward direction and flatten it onto the world XZ
   plane to get the horizontal heading.
2. Use that heading to define the pitch axis.
3. Project the current velocity into that pitch plane.
4. If the projected velocity is meaningful, point the flight nose along it.
5. Build a flight basis from nose, pitch axis, and up.

This means a jump that produces forward + upward velocity enters flight with the
nose pitched along that movement vector instead of snapping to level flight.

If the resulting flight body would overlap world geometry, the controller falls
back to an upright yaw-only basis to avoid spawning the flight hull into a wall
or floor.

The transition then:

- switches `motion_mode` to floating,
- disables floor snap,
- clears the flap hold timer,
- updates flight camera and aero angles,
- starts a camera lerp from the previous Q3 camera view to the active flight
  camera.

## Flight → Q3 transition

Flight returns to Q3 when any surface is touched.

The transition preserves:

- `global_position`
- `velocity`

When entering Q3, the body snaps upright:

- pitch is set to `0`,
- roll is set to `0`,
- yaw is preserved from the current body orientation.

The transition then:

- switches `motion_mode` back to grounded,
- restores Q3 floor snap,
- updates the Q3 view angles,
- starts a camera lerp from the flight camera to the Q3 camera.

Momentum is not converted or discarded. The resulting Q3 velocity is whatever
the flight mode had at contact time, except when a body-bounce knockdown changes
it through reflection.

## Camera behavior

The hybrid controller uses three camera paths:

- Q3 camera: first-person or third-person, driven by `Q3MovementMotor`.
- Flight camera: first-person or third-person, driven by `FlightMovementMotor`.
- Transition camera: temporary camera used only during state changes.

State changes do not snap the active camera directly. Instead, the transition
camera copies the previous camera transform and FOV, becomes current, and lerps
toward the target mode's active camera over `0.2 s`.

This is especially important when switching between:

- Q3 rigid / movement-relative camera
- Flight free camera / fly-by-wire camera

### Flight camera fly-by-wire

Flight camera fly-by-wire is inherited from the standalone flight controller.
The camera look ray defines a target point. The flight motor rolls and pitches
the body toward that target.

The hybrid uses the same `camera_fly_by_wire_pitch_window` setting as the
standalone flight controller. When the target is within the configured
world-horizontal angle, the nearest signed pitch is used directly:

- target above the nose → pitch up,
- target below the nose → pitch down.

Outside that horizontal window, the normal bank-and-pull behavior is used.

## Body bounce and knockdown

Body bounce is an optional high-speed impact mechanic. It is enabled by default
for Q3 + Flight.

For each slide collision, the controller computes incoming speed into the
surface normal:

```gdscript
normal_speed = max(0.0, -impact_velocity.dot(collision_normal))
```

If the strongest normal speed is at least `body_bounce_min_normal_speed`, the
impact triggers a bounce:

```gdscript
reflected = impact_velocity - 2.0 * impact_velocity.dot(normal) * normal
velocity = reflected * body_bounce_restitution
```

This is the ordinary angle-of-incidence equals angle-of-reflection response,
scaled by restitution.

On a qualifying impact:

- the character is forced into Q3 mode,
- control is disabled for `body_bounce_knockdown_duration`,
- the Q3 HUD displays the active knockdown timer,
- flap-hold and no-contact timers are cleared.

While knocked down, Q3 movement input is suppressed and flight cannot activate.
When the timer reaches zero, Q3 control is restored and the HUD knockdown state
clears.

## Keybindings

The hybrid controller shares actions between Q3 and flight:

| Action | Default key | Q3 mode | Flight mode |
|---|---:|---|---|
| `player_forward` | W | Move forward | Pitch down |
| `player_back` | S | Move back | Pitch up |
| `player_left` | A | Move left | Roll left |
| `player_right` | D | Move right | Roll right |
| `player_jump` | Space | Jump / hold to enter flight | Flap |
| `player_crouch` | Ctrl | Crouch | unused |
| `player_special` | E | Special / Wall Jump | unused |
| `player_walk` | Shift | Slow Walk | unused |

The action labels in the settings menu use hybrid names such as
`Jump / Hold Flight / Flap` and `Move Forward / Pitch Down`.

## Settings and presets

The controller is selected with controller id `q3_n_flight` and label
`Q3 + Flight`.

The built-in preset lives at:

```text
data/settings_presets/q3_n_flight/default.json
```

The settings schema is built from:

1. hybrid-only gates and body-bounce options,
2. Q3 movement options,
3. flight movement options.

Q3 character size settings are hidden in the hybrid profile. The Q3 hull is
always synchronized to `FLIGHT_COLLISION_SIZE`, because the same `CharacterBody3D`
must be valid in both modes and must not change size during mode transitions.

Hybrid-specific settings:

| Key | Purpose |
|---|---|
| `flight_hold_threshold` | Held jump/flap time required before flight. |
| `flight_no_contact_threshold` | Airborne/no-surface time required before flight. |
| `flight_min_activation_speed` | Minimum speed required before flight. |
| `body_bounce` | Enables/disables body-bounce knockdown. |
| `body_bounce_min_normal_speed` | Incoming normal speed required to bounce. |
| `body_bounce_knockdown_duration` | Knockdown control-lock time. |
| `body_bounce_restitution` | Reflected velocity scale. |

Inherited Q3 defaults overridden for the hybrid:

| Setting | Hybrid default |
|---|---:|
| `fov` | `80°` |
| `movement_mode` | `Warsow Classic (CPM-like)` |
| `third_person` | on |
| `auto_jump` | on |

Inherited flight defaults overridden for the hybrid:

| Setting | Hybrid default |
|---|---:|
| `first_person` | off |

## Implementation notes

The implementation uses composition, not inheritance chaining. Godot has no
multiple inheritance, and inheriting from either standalone controller would make
the other controller's lifecycle awkward. The hybrid therefore owns:

- one `Q3MovementMotor`,
- one `FlightMovementMotor`,
- one shared `CharacterBody3D`,
- mode-specific visuals/cameras/HUD nodes.

This keeps the transition code explicit and makes it clear which mode is allowed
to run physics in a given frame.

The important files are:

| File | Role |
|---|---|
| `scripts/q3_n_flight_controller.gd` | State machine, transitions, bounce, camera blend. |
| `scenes/q3_n_flight_controller.tscn` | Hybrid scene and mode-specific nodes. |
| `scripts/q3_movement_motor.gd` | Q3 movement implementation. |
| `scripts/flight_movement_motor.gd` | Flight movement implementation. |
| `scripts/settings.gd` | Hybrid setting schema and default overrides. |
| `scripts/keybindings_settings.gd` | Hybrid action labels and default bindings. |
| `data/settings_presets/q3_n_flight/default.json` | Built-in Q3 + Flight preset. |
| `tests/test_q3_n_flight_behavior.gd` | Hybrid behavior regression tests. |

## Testing expectations

The hybrid behavior test covers:

- settings visibility and defaults,
- fixed shared collision size,
- Q3 → Flight velocity preservation,
- takeoff pitch alignment,
- camera transition lerp,
- Flight → Q3 upright snap,
- no-contact gate,
- minimum-speed gate,
- low-hop anti-teleport behavior,
- surface-contact return to Q3,
- body-bounce reflection,
- knockdown HUD and control lock.

Run the focused test with:

```sh
HOME=/tmp XDG_DATA_HOME=/tmp "$GODOT_BIN" --headless --path . --scene res://tests/test_q3_n_flight_behavior.tscn --quit-after 4000
```

Run the full suite with:

```sh
HOME=/tmp XDG_DATA_HOME=/tmp tests/run.sh
```

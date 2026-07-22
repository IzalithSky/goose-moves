# Movement State API

The movement controllers expose a normalized state snapshot for visual,
animation, audio, and gameplay code:

```gdscript
var state := controller.get_movement_state()
```

The API is intentionally read-only. Consumers should use it to choose
presentation or downstream behavior without probing controller internals.

## Controllers

Implemented by:

- `Q3CharacterController`
- `FlightController`
- `Q3NFlightController`

All three controllers use `MovementStateTracker` for common event timers,
landing facts, and dictionary construction.

## Core Fields

These fields are always present:

| Key | Type | Meaning |
|---|---|---|
| `controller` | `String` | Current controller family, e.g. `"q3"` or `"flight"` |
| `mode` | `String` | Current movement mode; same as `controller` for standalone controllers |
| `position` | `Vector3` | Current global body position |
| `velocity` | `Vector3` | Current body velocity |
| `horizontal_speed` | `float` | XZ speed magnitude |
| `vertical_speed` | `float` | Y velocity |
| `facing_direction` | `Vector3` | Normalized horizontal facing direction |
| `grounded` | `bool` | Body is on a floor |
| `airborne` | `bool` | Inverse of `grounded` |
| `wall_contact` | `bool` | Body currently reports wall contact |
| `ceiling_contact` | `bool` | Body currently reports ceiling contact |

## Q3 Fields

These are meaningful for Q3 and Q3+flight while in Q3-backed movement:

| Key | Type | Meaning |
|---|---|---|
| `swimming` | `bool` | Water level is deep enough for swim movement |
| `water_level` | `int` | Q3 water level, `0` to `3` |
| `water_type` | `StringName` | Volume type, e.g. `&"water"` or `&"slime"` |
| `crouching` | `bool` | Current stance is crouched |
| `crouch_sliding` | `bool` | Crouch slide is active |

Standalone flight returns neutral values for these fields.

## Flight Activation Fields

These are meaningful for Q3+flight:

| Key | Type | Meaning |
|---|---|---|
| `flight_activation_charging` | `bool` | Flight input is being held while in Q3 mode |
| `flight_activation_charge` | `float` | Current held-flight input time |
| `flight_activation_threshold` | `float` | Hold duration required before flight can activate |
| `just_entered_flight` | `bool` | Short-lived flag after Q3 → flight transition |
| `just_exited_flight` | `bool` | Short-lived flag after flight → Q3 transition |

Standalone Q3 and standalone flight keep these transition flags false unless
that controller gains equivalent mechanics later.

## Landing And Takeoff Fields

Landing/takeoff events are short-lived and suitable for one-shot animation,
sound, particles, or controller feedback:

| Key | Type | Meaning |
|---|---|---|
| `just_landed` | `bool` | Recently transitioned from airborne to grounded |
| `just_took_off` | `bool` | Recently transitioned from grounded to airborne |
| `hard_landed` | `bool` | Recent landing exceeded the configured hard-landing threshold |
| `landing_horizontal_speed` | `float` | Horizontal speed before the most recent landing |
| `landing_vertical_impact_speed` | `float` | Downward speed before the most recent landing |
| `landing_surface_type` | `StringName` | Surface type from collision metadata, or a default such as `&"ground"` |
| `landing_surface_normal` | `Vector3` | Walkable contact normal for the landing |
| `landing_carry_active` | `bool` | Landing carry timer is active |
| `landing_carry_time_remaining` | `float` | Seconds remaining for landing carry behavior |
| `takeoff_horizontal_speed` | `float` | Horizontal speed before the most recent takeoff |
| `takeoff_vertical_speed` | `float` | Vertical speed before the most recent takeoff |

Q3+flight uses landing carry to preserve horizontal speed at touchdown and then
apply reduced ground friction for a short configurable window. Slick surfaces
and crouch slide can preserve speed naturally through their existing ground
friction behavior.

## Crash And Recovery Fields

These are only meaningful for controllers with crash or knockdown mechanics.
Currently that is Q3+flight body-bounce recovery.

| Key | Type | Meaning |
|---|---|---|
| `crashed` | `bool` | Recent crash or body-bounce event |
| `knocked_down` | `bool` | Control is currently suppressed by recovery |
| `crash_recovery_time_remaining` | `float` | Seconds of recovery left |
| `crash_impact_speed` | `float` | Strongest incoming normal speed for the crash |
| `crash_surface_normal` | `Vector3` | Normal used for the crash response |

Standalone Q3 and standalone flight report neutral crash values because they do
not currently have crash or knockdown mechanics.

## Landing Carry Settings

Q3+flight exposes these settings:

| Setting | Meaning |
|---|---|
| `landing_carry` | Enables landing carry behavior |
| `landing_friction_multiplier` | Scales ground friction while carry is active |
| `landing_carry_duration` | Carry window in seconds |
| `landing_carry_min_speed` | Minimum horizontal landing speed required |
| `hard_landing_vertical_speed` | Downward impact speed required for `hard_landed` |

The optional high-speed skid/slide behavior is not currently implemented.

## Example

```gdscript
var state := player.get_movement_state()

if state["crashed"] or state["knocked_down"]:
	play("crash_recover")
elif state["just_landed"]:
	if state["hard_landed"]:
		play("hard_land")
	elif state["landing_carry_active"] or state["crouch_sliding"]:
		play("land_runout")
	else:
		play("soft_land")
elif state["airborne"]:
	play("fall" if state["vertical_speed"] < 0.0 else "jump")
elif state["horizontal_speed"] > 0.5:
	play("run")
else:
	play("idle")
```

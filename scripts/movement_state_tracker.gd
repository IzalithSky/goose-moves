class_name MovementStateTracker
extends RefCounted

const EVENT_DURATION := 0.12

var just_landed_time_remaining := 0.0
var just_took_off_time_remaining := 0.0
var just_entered_flight_time_remaining := 0.0
var just_exited_flight_time_remaining := 0.0
var hard_landed_time_remaining := 0.0
var crashed_time_remaining := 0.0
var landing_carry_time_remaining := 0.0

var landing_horizontal_speed := 0.0
var landing_vertical_impact_speed := 0.0
var landing_surface_type := &""
var landing_surface_normal := Vector3.UP
var takeoff_horizontal_speed := 0.0
var takeoff_vertical_speed := 0.0
var crash_impact_speed := 0.0
var crash_surface_normal := Vector3.ZERO


func physics_tick(delta: float) -> void:
	landing_carry_time_remaining = maxf(landing_carry_time_remaining - delta, 0.0)
	just_landed_time_remaining = maxf(just_landed_time_remaining - delta, 0.0)
	just_took_off_time_remaining = maxf(just_took_off_time_remaining - delta, 0.0)
	just_entered_flight_time_remaining = maxf(just_entered_flight_time_remaining - delta, 0.0)
	just_exited_flight_time_remaining = maxf(just_exited_flight_time_remaining - delta, 0.0)
	hard_landed_time_remaining = maxf(hard_landed_time_remaining - delta, 0.0)
	crashed_time_remaining = maxf(crashed_time_remaining - delta, 0.0)


func record_landing(impact_velocity: Vector3, impact: Dictionary, carry_config := {}) -> void:
	var horizontal_velocity := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	landing_horizontal_speed = horizontal_velocity.length()
	landing_vertical_impact_speed = maxf(0.0, -impact_velocity.y)
	landing_surface_normal = impact.get("normal", Vector3.UP) as Vector3
	landing_surface_type = StringName(impact.get("surface_type", &"ground"))
	just_landed_time_remaining = EVENT_DURATION

	var hard_landing_vertical_speed := float(carry_config.get("hard_landing_vertical_speed", INF))
	if landing_vertical_impact_speed >= hard_landing_vertical_speed:
		hard_landed_time_remaining = EVENT_DURATION

	var carry_enabled := bool(carry_config.get("enabled", false))
	var carry_min_speed := float(carry_config.get("min_speed", 0.0))
	var carry_duration := float(carry_config.get("duration", 0.0))
	if carry_enabled and landing_horizontal_speed >= carry_min_speed and carry_duration > 0.0:
		landing_carry_time_remaining = carry_duration


func record_takeoff(takeoff_velocity: Vector3) -> void:
	takeoff_horizontal_speed = Vector2(takeoff_velocity.x, takeoff_velocity.z).length()
	takeoff_vertical_speed = takeoff_velocity.y
	just_took_off_time_remaining = EVENT_DURATION


func record_entered_flight() -> void:
	just_entered_flight_time_remaining = EVENT_DURATION


func record_exited_flight() -> void:
	just_exited_flight_time_remaining = EVENT_DURATION


func record_crash(impact: Dictionary) -> void:
	crash_impact_speed = float(impact.get("speed", 0.0))
	crash_surface_normal = impact.get("normal", Vector3.ZERO) as Vector3
	crashed_time_remaining = EVENT_DURATION


func get_landing_friction_multiplier(carry_enabled: bool, multiplier: float) -> float:
	if not carry_enabled or landing_carry_time_remaining <= 0.0:
		return 1.0
	return maxf(multiplier, 0.0)


func apply_landing_carry_preservation(body: CharacterBody3D, impact_velocity: Vector3, carry_config: Dictionary) -> void:
	if not bool(carry_config.get("enabled", false)):
		return
	var incoming_horizontal := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	if incoming_horizontal.length() < float(carry_config.get("min_speed", 0.0)):
		return
	body.velocity.x = incoming_horizontal.x
	body.velocity.z = incoming_horizontal.z


func get_floor_collision_impact(
	body: CharacterBody3D,
	impact_velocity: Vector3,
	walkable_normal_y: float,
	default_surface_type := &"ground"
) -> Dictionary:
	var best_normal := Vector3.ZERO
	var best_speed := 0.0
	var best_surface_type := default_surface_type
	for collision_index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(collision_index)
		var normal := collision.get_normal().normalized()
		if normal.y < walkable_normal_y:
			continue
		var normal_speed := maxf(0.0, -impact_velocity.dot(normal))
		if normal_speed >= best_speed:
			best_normal = normal
			best_speed = normal_speed
			best_surface_type = _get_collision_surface_type(collision, default_surface_type)
	if best_normal == Vector3.ZERO and body.is_on_floor():
		best_normal = body.get_floor_normal()
	if best_normal == Vector3.ZERO:
		return {}
	return {
		"normal": best_normal,
		"speed": best_speed,
		"surface_type": best_surface_type,
	}


func _get_collision_surface_type(collision: KinematicCollision3D, default_surface_type: StringName) -> StringName:
	var collider := collision.get_collider() as Node
	if collider != null and collider.has_meta("q3_surface"):
		return StringName(collider.get_meta("q3_surface"))
	return default_surface_type


func build_state(snapshot: Dictionary) -> Dictionary:
	var velocity := snapshot.get("velocity", Vector3.ZERO) as Vector3
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var facing_direction := snapshot.get("facing_direction", Vector3.ZERO) as Vector3
	facing_direction.y = 0.0
	if facing_direction.length_squared() <= 0.0001:
		facing_direction = horizontal_velocity
	if facing_direction.length_squared() <= 0.0001:
		facing_direction = Vector3.FORWARD
	facing_direction = facing_direction.normalized()

	var grounded := bool(snapshot.get("grounded", false))
	return {
		"controller": str(snapshot.get("controller", snapshot.get("mode", ""))),
		"mode": str(snapshot.get("mode", snapshot.get("controller", ""))),
		"position": snapshot.get("position", Vector3.ZERO),
		"velocity": velocity,
		"horizontal_speed": horizontal_velocity.length(),
		"vertical_speed": velocity.y,
		"facing_direction": facing_direction,
		"grounded": grounded,
		"airborne": not grounded,
		"swimming": bool(snapshot.get("swimming", false)),
		"water_level": int(snapshot.get("water_level", 0)),
		"water_type": StringName(snapshot.get("water_type", &"")),
		"crouching": bool(snapshot.get("crouching", false)),
		"crouch_sliding": bool(snapshot.get("crouch_sliding", false)),
		"wall_contact": bool(snapshot.get("wall_contact", false)),
		"ceiling_contact": bool(snapshot.get("ceiling_contact", false)),
		"flight_activation_charging": bool(snapshot.get("flight_activation_charging", false)),
		"flight_activation_charge": float(snapshot.get("flight_activation_charge", 0.0)),
		"flight_activation_threshold": float(snapshot.get("flight_activation_threshold", 0.0)),
		"just_landed": just_landed_time_remaining > 0.0,
		"just_took_off": just_took_off_time_remaining > 0.0,
		"just_entered_flight": just_entered_flight_time_remaining > 0.0,
		"just_exited_flight": just_exited_flight_time_remaining > 0.0,
		"hard_landed": hard_landed_time_remaining > 0.0,
		"crashed": crashed_time_remaining > 0.0,
		"knocked_down": bool(snapshot.get("knocked_down", false)),
		"crash_recovery_time_remaining": float(snapshot.get("crash_recovery_time_remaining", 0.0)),
		"landing_horizontal_speed": landing_horizontal_speed,
		"landing_vertical_impact_speed": landing_vertical_impact_speed,
		"landing_surface_type": landing_surface_type,
		"landing_surface_normal": landing_surface_normal,
		"landing_carry_active": landing_carry_time_remaining > 0.0,
		"landing_carry_time_remaining": landing_carry_time_remaining,
		"takeoff_horizontal_speed": takeoff_horizontal_speed,
		"takeoff_vertical_speed": takeoff_vertical_speed,
		"crash_impact_speed": crash_impact_speed,
		"crash_surface_normal": crash_surface_normal,
	}

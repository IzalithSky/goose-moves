class_name Q3CharacterController
extends CharacterBody3D

const Q3_MOVEMENT_HUD := preload("res://scripts/q3_movement_hud.gd")
const Q3_UNITS_PER_FOOT := 8.0
const METERS_PER_FOOT := 0.3048
const Q3_METERS_PER_UNIT := METERS_PER_FOOT / Q3_UNITS_PER_FOOT
const Q3_SPEED := 320.0
const Q3_GROUND_ACCELERATION := 10.0
const Q3_AIR_ACCELERATION := 1.0
const Q3_FRICTION := 6.0
const Q3_GRAVITY := 800.0
const Q3_JUMP_VELOCITY := 270.0
const Q3_STOP_SPEED := 100.0
const Q3_STEP_HEIGHT := 18.0
const Q3_GROUND_TRACE_DISTANCE := 0.25 * Q3_METERS_PER_UNIT
const Q3_GROUND_KICKOFF_SPEED := 10.0 * Q3_METERS_PER_UNIT
const Q3_MAX_SLOPE_ANGLE := 45.572996
const Q3_RUN_COMMAND := 127.0
const Q3_WALK_COMMAND := 64.0
const Q3_CROUCH_SPEED_SCALE := 0.25
const Q3_MINS_Z := -24.0
const Q3_STANDING_MAX_Z := 32.0
const Q3_CROUCH_MAX_Z := 16.0
const Q3_STANDING_VIEWHEIGHT := 26.0
const Q3_CROUCH_VIEWHEIGHT := 12.0
const Q3_STANDING_HULL_HEIGHT := Q3_STANDING_MAX_Z - Q3_MINS_Z
const Q3_CROUCH_HULL_HEIGHT := Q3_CROUCH_MAX_Z - Q3_MINS_Z
const Q3_STANDING_EYE_HEIGHT := Q3_STANDING_VIEWHEIGHT - Q3_MINS_Z
const Q3_CROUCH_EYE_HEIGHT := Q3_CROUCH_VIEWHEIGHT - Q3_MINS_Z
const Q3_SWIM_SCALE := 0.5
const Q3_WATER_ACCELERATION := 4.0
const Q3_WATER_FRICTION := 1.0
const Q3_SLIME_FRICTION := 12.0
const Q3_WATER_SINK_SPEED := 60.0
const Q3_VOLUME_COLLISION_MASK := 2
const Q3_WATER_JUMP_FORWARD_DISTANCE := 30.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_LOW_PROBE_HEIGHT := (Q3_MINS_Z * -1.0 + 4.0) * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_CLEARANCE := 16.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_FORWARD_VELOCITY := 200.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_VELOCITY := 350.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_DURATION := 2.0
const WARSOW_GROUND_ACCELERATION := 12.0
const WARSOW_AIR_ACCELERATION := 1.0
const WARSOW_AIR_DECELERATION := 2.0
const WARSOW_FRICTION := 8.0
const WARSOW_STOP_SPEED := 12.0
const WARSOW_STRAFE_ACCELERATION := 70.0
const WARSOW_STRAFE_WISH_SPEED := 30.0
const WARSOW_AIR_CONTROL := 150.0
const WARSOW_CROUCH_SLIDE_DURATION := 1.5
const WARSOW_CROUCH_SLIDE_FADE := 0.5
const WARSOW_CROUCH_SLIDE_COOLDOWN := 0.7
const WARSOW_CROUCH_SLIDE_CONTROL := 3.0
const WARSOW_WALK_SPEED := 160.0

enum MovementMode {
	VQ3,
	WARSOW_CLASSIC,
}

# Runtime values; overwritten from Settings in _ready and on settings_changed.
var movement_mode := MovementMode.VQ3
var auto_jump := false
var crouch_slide_enabled := false
var move_speed := Q3_SPEED * Q3_METERS_PER_UNIT
var ground_acceleration := Q3_GROUND_ACCELERATION
var air_acceleration := Q3_AIR_ACCELERATION
var friction := Q3_FRICTION
var stop_speed := Q3_STOP_SPEED * Q3_METERS_PER_UNIT
var gravity := Q3_GRAVITY * Q3_METERS_PER_UNIT
var jump_velocity := Q3_JUMP_VELOCITY * Q3_METERS_PER_UNIT
var step_height := Q3_STEP_HEIGHT * Q3_METERS_PER_UNIT
var max_slope_angle := Q3_MAX_SLOPE_ANGLE
var crouch_speed_scale := Q3_CROUCH_SPEED_SCALE
var walk_speed_scale := Q3_WALK_COMMAND / Q3_RUN_COMMAND
var swim_speed_scale := Q3_SWIM_SCALE
var water_acceleration := Q3_WATER_ACCELERATION
var water_friction := Q3_WATER_FRICTION
var slime_friction := Q3_SLIME_FRICTION
var mouse_sensitivity := 0.003

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hud: Q3_MOVEMENT_HUD = $HUD

var pitch := 0.0
var yaw := 0.0
var floor_is_slick := false
var is_crouching := false
var is_crouch_sliding := false
var crouch_slide_time_remaining := 0.0
var body_shape: BoxShape3D
var water_level := 0
var water_type: StringName
var water_jump_time_remaining := 0.0


func _ready() -> void:
	_apply_controller_settings()
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_stop_on_slope = false
	floor_snap_length = step_height
	body_shape = (collision_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	collision_shape.shape = body_shape
	_set_stance_geometry(false)
	pitch = head.rotation.x
	yaw = rotation.y
	Settings.settings_changed.connect(on_settings_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var horizontal_speed_mps := Vector2(velocity.x, velocity.z).length()
	hud.update_values(
		horizontal_speed_mps / Q3_METERS_PER_UNIT,
		horizontal_speed_mps,
		roundi(Engine.get_frames_per_second()),
		is_on_floor(),
		floor_is_slick,
		is_crouching,
		water_level,
		water_jump_time_remaining > 0.0,
		_get_current_friction_coefficient(),
		_get_current_acceleration(),
	)


func _physics_process(delta: float) -> void:
	_update_crouch_state()
	_update_water_level()
	var grounded := is_on_floor()
	var floor_normal := get_floor_normal() if grounded else Vector3.UP
	if not grounded:
		var ground_collision := _get_ground_collision()
		if ground_collision != null:
			var traced_normal := ground_collision.get_normal()
			var kicked_off := (
				velocity.y > 0.0
				and velocity.dot(traced_normal) > Q3_GROUND_KICKOFF_SPEED
			)
			if traced_normal.y >= cos(floor_max_angle) and not kicked_off:
				grounded = true
				floor_normal = traced_normal
				apply_floor_snap()
	var slick := grounded and floor_is_slick
	var movement_input := _get_movement_input()
	_update_crouch_slide(delta, grounded)
	if water_jump_time_remaining > 0.0:
		_water_jump_move(delta)
		return
	if water_level > 1:
		if _try_water_jump():
			_water_jump_move(delta)
			return
		_water_move(movement_input, delta)
		return
	if grounded and _jump_requested() and not Input.is_action_pressed("player_crouch"):
		velocity.y = jump_velocity
		grounded = false

	var wish_direction := _get_wish_direction(movement_input, floor_normal if grounded else Vector3.UP)
	var wish_speed := _get_wish_speed(movement_input)
	if grounded:
		if water_level > 0:
			var wade_scale := 1.0 - ((1.0 - swim_speed_scale) * (water_level / 3.0))
			wish_speed = minf(wish_speed, move_speed * wade_scale)
		if is_crouching:
			wish_speed = minf(wish_speed, move_speed * crouch_speed_scale)

	_apply_friction(delta, grounded and not slick)
	var airborne_end_velocity_y := 0.0
	if grounded:
		if is_crouch_sliding and not slick:
			_crouch_slide_accelerate(wish_direction, wish_speed, _get_ground_acceleration(), delta)
		else:
			_accelerate(wish_direction, wish_speed, air_acceleration if slick else _get_ground_acceleration(), delta)
		if slick:
			if not floor_normal.is_equal_approx(Vector3.UP):
				velocity.y -= gravity * delta
		_project_velocity_onto_plane(floor_normal)
	else:
		_air_move(wish_direction, wish_speed, movement_input, delta)
		airborne_end_velocity_y = velocity.y - (gravity * delta)
		velocity.y = (velocity.y + airborne_end_velocity_y) * 0.5

	if grounded:
		_try_step_up(delta)

	move_and_slide()
	if is_on_floor():
		if grounded:
			_restore_velocity_on_floor_plane(get_floor_normal())
	elif not grounded:
		velocity.y = airborne_end_velocity_y
	_update_floor_surface()


func _get_movement_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("player_right") - Input.get_action_strength("player_left"),
		Input.get_action_strength("player_forward") - Input.get_action_strength("player_back"),
	)


func _get_wish_direction(movement_input: Vector2, ground_normal: Vector3) -> Vector3:
	if movement_input.is_zero_approx():
		return Vector3.ZERO

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var wish_direction := (right * movement_input.x) + (forward * movement_input.y)
	return wish_direction.slide(ground_normal).normalized()


func _get_wish_speed(movement_input: Vector2) -> float:
	if movement_input.is_zero_approx():
		return 0.0

	var forward_move := movement_input.y * _get_movement_scale()
	var right_move := movement_input.x * _get_movement_scale()
	var up_move := _get_vertical_input()
	var maximum_move := maxf(maxf(absf(forward_move), absf(right_move)), absf(up_move))
	var total_move := sqrt((forward_move * forward_move) + (right_move * right_move) + (up_move * up_move))
	return move_speed * maximum_move * Vector2(forward_move, right_move).length() / total_move


func _get_movement_scale() -> float:
	return walk_speed_scale if Input.is_action_pressed("player_walk") else 1.0


func _get_vertical_input() -> float:
	return (Input.get_action_strength("player_jump") - Input.get_action_strength("player_crouch"))


func _jump_requested() -> bool:
	if auto_jump:
		return Input.is_action_pressed("player_jump")
	return Input.is_action_just_pressed("player_jump")


func _update_crouch_slide(delta: float, grounded: bool) -> void:
	if not crouch_slide_enabled:
		is_crouch_sliding = false
		crouch_slide_time_remaining = 0.0
		return

	if crouch_slide_time_remaining > 0.0:
		crouch_slide_time_remaining -= delta
		if crouch_slide_time_remaining <= 0.0:
			crouch_slide_time_remaining = WARSOW_CROUCH_SLIDE_COOLDOWN if is_crouch_sliding else 0.0
			is_crouch_sliding = false

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var can_slide := (
		_get_vertical_input() < 0.0
		and horizontal_speed > WARSOW_WALK_SPEED * Q3_METERS_PER_UNIT
	)
	if can_slide:
		if crouch_slide_time_remaining > 0.0 or grounded:
			return
		is_crouch_sliding = true
		crouch_slide_time_remaining = WARSOW_CROUCH_SLIDE_DURATION + WARSOW_CROUCH_SLIDE_FADE
	elif is_crouch_sliding:
		crouch_slide_time_remaining = minf(crouch_slide_time_remaining, WARSOW_CROUCH_SLIDE_FADE)


func _update_crouch_state() -> void:
	if Input.is_action_pressed("player_crouch"):
		if not is_crouching:
			_set_crouching(true)
	elif is_crouching and _can_stand():
		_set_crouching(false)


func _set_crouching(value: bool) -> void:
	is_crouching = value
	_set_stance_geometry(value)


func _set_stance_geometry(crouching: bool) -> void:
	var hull_height := (Q3_CROUCH_HULL_HEIGHT if crouching else Q3_STANDING_HULL_HEIGHT) * Q3_METERS_PER_UNIT
	var eye_height := (Q3_CROUCH_EYE_HEIGHT if crouching else Q3_STANDING_EYE_HEIGHT) * Q3_METERS_PER_UNIT
	body_shape.size.y = hull_height
	collision_shape.position.y = hull_height * 0.5
	head.position.y = eye_height


func _can_stand() -> bool:
	_set_stance_geometry(false)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape
	query.transform = collision_shape.global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var blocked := not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	_set_stance_geometry(true)
	return not blocked


func _update_water_level() -> void:
	water_level = 0
	water_type = &""
	var eye_height := head.position.y
	var water_area := _get_water_area_at(global_position + (Vector3.UP * Q3_METERS_PER_UNIT))
	if water_area == null:
		return

	water_type = StringName(water_area.get_meta("q3_volume_type", &"water"))
	water_level = 1
	if _get_water_area_at(global_position + (Vector3.UP * (eye_height * 0.5))) == null:
		return

	water_level = 2
	if _get_water_area_at(global_position + (Vector3.UP * eye_height)) != null:
		water_level = 3


func _get_water_area_at(point: Vector3) -> Area3D:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = Q3_VOLUME_COLLISION_MASK
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var results := get_world_3d().direct_space_state.intersect_point(query, 1)
	if results.is_empty():
		return null
	return results[0].get("collider") as Area3D


func _water_move(movement_input: Vector2, delta: float) -> void:
	_apply_friction(delta, false)
	var wish_velocity := _get_swim_wish_velocity(movement_input)
	var wish_speed := wish_velocity.length()
	if wish_speed > move_speed * swim_speed_scale:
		wish_speed = move_speed * swim_speed_scale
	_accelerate(wish_velocity.normalized(), wish_speed, water_acceleration, delta)

	if is_on_floor() and velocity.dot(get_floor_normal()) < 0.0:
		_project_velocity_onto_plane(get_floor_normal())

	move_and_slide()
	_update_floor_surface()


func _try_water_jump() -> bool:
	if water_level != 2:
		return false

	var flat_forward := -global_transform.basis.z
	flat_forward.y = 0.0
	if flat_forward.is_zero_approx():
		return false
	flat_forward = flat_forward.normalized()
	var ledge_point := global_position + (flat_forward * Q3_WATER_JUMP_FORWARD_DISTANCE)
	ledge_point.y += Q3_WATER_JUMP_LOW_PROBE_HEIGHT
	if not _has_solid_at(ledge_point):
		return false
	if _has_solid_at(ledge_point + (Vector3.UP * Q3_WATER_JUMP_CLEARANCE)):
		return false

	velocity = -head.global_transform.basis.z * Q3_WATER_JUMP_FORWARD_VELOCITY
	velocity.y = Q3_WATER_JUMP_VELOCITY
	water_jump_time_remaining = Q3_WATER_JUMP_DURATION
	return true


func _water_jump_move(delta: float) -> void:
	move_and_slide()
	velocity.y -= gravity * delta
	water_jump_time_remaining = maxf(water_jump_time_remaining - delta, 0.0)
	if velocity.y < 0.0:
		water_jump_time_remaining = 0.0
	_update_floor_surface()


func _has_solid_at(point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()


func _get_swim_wish_velocity(movement_input: Vector2) -> Vector3:
	var vertical_input := _get_vertical_input()
	if movement_input.is_zero_approx() and is_zero_approx(vertical_input):
		return Vector3.DOWN * Q3_WATER_SINK_SPEED * Q3_METERS_PER_UNIT

	var movement_scale := _get_movement_scale()
	var forward_move := movement_input.y * movement_scale
	var right_move := movement_input.x * movement_scale
	var maximum_move := maxf(maxf(absf(forward_move), absf(right_move)), absf(vertical_input))
	var total_move := sqrt((forward_move * forward_move) + (right_move * right_move) + (vertical_input * vertical_input))
	var command_scale := move_speed * maximum_move / total_move
	var forward := -head.global_transform.basis.z
	var right := global_transform.basis.x
	return ((forward * forward_move) + (right * right_move) + (Vector3.UP * vertical_input)) * command_scale


func _get_current_friction_coefficient() -> float:
	if water_jump_time_remaining > 0.0:
		return 0.0

	var current_friction := _get_volume_friction() * water_level
	if water_level <= 1 and is_on_floor() and not floor_is_slick:
		current_friction += _get_ground_friction()
	return current_friction


func _get_current_acceleration() -> float:
	if water_jump_time_remaining > 0.0:
		return 0.0
	if water_level > 1:
		return water_acceleration
	if is_on_floor() and not floor_is_slick:
		return _get_ground_acceleration() * (WARSOW_CROUCH_SLIDE_CONTROL if is_crouch_sliding else 1.0)
	var movement_input := _get_movement_input()
	var wish_direction := _get_wish_direction(movement_input, Vector3.UP)
	return _get_air_acceleration(wish_direction, movement_input)


func _get_ground_acceleration() -> float:
	return WARSOW_GROUND_ACCELERATION if movement_mode == MovementMode.WARSOW_CLASSIC else ground_acceleration


func _get_ground_friction() -> float:
	var ground_friction := WARSOW_FRICTION if movement_mode == MovementMode.WARSOW_CLASSIC else friction
	if not crouch_slide_enabled or not is_crouch_sliding:
		return ground_friction
	if crouch_slide_time_remaining >= WARSOW_CROUCH_SLIDE_FADE:
		return 0.0
	var fade_fraction := maxf(crouch_slide_time_remaining, 0.0) / WARSOW_CROUCH_SLIDE_FADE
	return ground_friction * (1.0 - sqrt(fade_fraction))


func _get_ground_stop_speed() -> float:
	if movement_mode == MovementMode.WARSOW_CLASSIC:
		return WARSOW_STOP_SPEED * Q3_METERS_PER_UNIT
	return stop_speed


func _get_air_acceleration(wish_direction: Vector3, movement_input: Vector2) -> float:
	if movement_mode != MovementMode.WARSOW_CLASSIC:
		return air_acceleration

	var acceleration := WARSOW_AIR_ACCELERATION
	if not wish_direction.is_zero_approx() and velocity.dot(wish_direction) < 0.0:
		acceleration = WARSOW_AIR_DECELERATION
	if not is_zero_approx(movement_input.x) and is_zero_approx(movement_input.y):
		acceleration = WARSOW_STRAFE_ACCELERATION
	return acceleration


func _get_volume_friction() -> float:
	return slime_friction if water_type == &"slime" else water_friction


func _apply_friction(delta: float, apply_ground_friction: bool) -> void:
	var friction_velocity := velocity
	if apply_ground_friction:
		friction_velocity.y = 0.0
	var speed := friction_velocity.length()
	if speed <= 0.0:
		return

	var drop := 0.0
	if apply_ground_friction:
		drop += maxf(speed, _get_ground_stop_speed()) * _get_ground_friction() * delta
	if water_level > 0:
		drop += speed * _get_volume_friction() * water_level * delta
	if drop <= 0.0:
		return

	var new_speed := maxf(speed - drop, 0.0)
	velocity *= new_speed / speed


func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	if wish_direction.is_zero_approx():
		return

	var current_speed := velocity.dot(wish_direction)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var acceleration_speed := minf(acceleration * delta * wish_speed, add_speed)
	velocity += wish_direction * acceleration_speed


func _crouch_slide_accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	var entry_speed := velocity.length()
	_accelerate(wish_direction, wish_speed, acceleration * WARSOW_CROUCH_SLIDE_CONTROL, delta)
	var new_speed := velocity.length()
	if new_speed > wish_speed and new_speed > 0.0:
		velocity *= maxf(wish_speed, entry_speed) / new_speed


func _air_move(wish_direction: Vector3, wish_speed: float, movement_input: Vector2, delta: float) -> void:
	var capped_wish_speed := wish_speed
	if (
		movement_mode == MovementMode.WARSOW_CLASSIC
		and not is_zero_approx(movement_input.x)
		and is_zero_approx(movement_input.y)
	):
		capped_wish_speed = minf(capped_wish_speed, WARSOW_STRAFE_WISH_SPEED * Q3_METERS_PER_UNIT)
	_accelerate(wish_direction, capped_wish_speed, _get_air_acceleration(wish_direction, movement_input), delta)
	_apply_air_control(wish_direction, movement_input, delta)


func _apply_air_control(wish_direction: Vector3, movement_input: Vector2, delta: float) -> void:
	if (
		movement_mode != MovementMode.WARSOW_CLASSIC
		or not is_zero_approx(movement_input.x)
		or is_zero_approx(movement_input.y)
	):
		return

	var horizontal_velocity := velocity
	horizontal_velocity.y = 0.0
	var speed := horizontal_velocity.length()
	if speed <= 0.0:
		return

	var velocity_direction := horizontal_velocity / speed
	var alignment := velocity_direction.dot(wish_direction)
	if alignment <= 0.0:
		return

	var control_speed := (
		32.0
		* Q3_METERS_PER_UNIT
		* WARSOW_AIR_CONTROL
		* alignment
		* alignment
		* delta
	)
	var controlled_direction := (velocity_direction * speed) + (wish_direction * control_speed)
	if controlled_direction.is_zero_approx():
		return
	controlled_direction = controlled_direction.normalized() * speed
	velocity.x = controlled_direction.x
	velocity.z = controlled_direction.z


func _project_velocity_onto_plane(plane_normal: Vector3, speed: float = -1.0) -> void:
	if speed < 0.0:
		speed = velocity.length()
	velocity = velocity.slide(plane_normal)
	if not velocity.is_zero_approx():
		velocity = velocity.normalized() * speed


func _restore_velocity_on_floor_plane(plane_normal: Vector3) -> void:
	if is_zero_approx(plane_normal.y):
		return
	velocity.y = -((velocity.x * plane_normal.x) + (velocity.z * plane_normal.z)) / plane_normal.y


func _get_ground_collision() -> KinematicCollision3D:
	var collision := KinematicCollision3D.new()
	if test_move(
		global_transform,
		Vector3.DOWN * Q3_GROUND_TRACE_DISTANCE,
		collision,
		safe_margin,
		false,
	):
		return collision
	return null


func _try_step_up(delta: float) -> bool:
	if velocity.y > 0.0:
		return false

	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if horizontal_motion.is_zero_approx():
		return false

	var collision := KinematicCollision3D.new()
	if not test_move(global_transform, horizontal_motion, collision, safe_margin, true):
		return false
	if collision.get_normal().y >= cos(floor_max_angle):
		return false

	var raised_transform := global_transform.translated(Vector3.UP * step_height)
	if test_move(global_transform, Vector3.UP * step_height, null, safe_margin, true):
		return false
	if test_move(raised_transform, horizontal_motion, null, safe_margin, true):
		return false

	global_transform = raised_transform
	return true


func _update_floor_surface() -> void:
	floor_is_slick = false
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().y >= cos(floor_max_angle):
			floor_is_slick = _surface_is_slick(collision.get_collider() as Node)
			return

	var ground_collision := _get_ground_collision()
	if ground_collision != null and ground_collision.get_normal().y >= cos(floor_max_angle):
		floor_is_slick = _surface_is_slick(ground_collision.get_collider() as Node)


func _surface_is_slick(collider: Node) -> bool:
	while collider != null:
		if (
			StringName(collider.get_meta("q3_surface", &"")) == &"slick"
			or bool(collider.get_meta("slick", false))
		):
			return true
		collider = collider.get_parent()
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - (event.relative.y * mouse_sensitivity), deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation.y = yaw
		head.rotation.x = pitch


func on_settings_changed() -> void:
	_apply_controller_settings()


func _apply_controller_settings() -> void:
	movement_mode = roundi(Settings.get_controller_setting("movement_mode", Settings.CHARACTER_Q3))
	auto_jump = Settings.get_controller_setting("auto_jump", Settings.CHARACTER_Q3) >= 0.5
	crouch_slide_enabled = Settings.get_controller_setting("crouch_slide", Settings.CHARACTER_Q3) >= 0.5
	if not crouch_slide_enabled:
		is_crouch_sliding = false
		crouch_slide_time_remaining = 0.0
	move_speed = Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3)
	ground_acceleration = Settings.get_controller_setting("ground_acceleration", Settings.CHARACTER_Q3)
	air_acceleration = Settings.get_controller_setting("air_acceleration", Settings.CHARACTER_Q3)
	friction = Settings.get_controller_setting("friction", Settings.CHARACTER_Q3)
	stop_speed = Settings.get_controller_setting("stop_speed", Settings.CHARACTER_Q3)
	gravity = Settings.get_controller_setting("gravity", Settings.CHARACTER_Q3)
	jump_velocity = Settings.get_controller_setting("jump_velocity", Settings.CHARACTER_Q3)
	step_height = Settings.get_controller_setting("step_height", Settings.CHARACTER_Q3)
	max_slope_angle = Settings.get_controller_setting("max_slope_angle", Settings.CHARACTER_Q3)
	crouch_speed_scale = Settings.get_controller_setting("crouch_speed_scale", Settings.CHARACTER_Q3)
	walk_speed_scale = Settings.get_controller_setting("walk_speed_scale", Settings.CHARACTER_Q3)
	swim_speed_scale = Settings.get_controller_setting("swim_speed_scale", Settings.CHARACTER_Q3)
	water_acceleration = Settings.get_controller_setting("water_acceleration", Settings.CHARACTER_Q3)
	water_friction = Settings.get_controller_setting("water_friction", Settings.CHARACTER_Q3)
	slime_friction = Settings.get_controller_setting("slime_friction", Settings.CHARACTER_Q3)
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", Settings.CHARACTER_Q3)
	camera.fov = Settings.get_controller_setting("fov", Settings.CHARACTER_Q3)
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = step_height

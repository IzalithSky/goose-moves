class_name Q3MovementMotor
extends RefCounted

const Q3_MOVEMENT_HUD := preload("res://scripts/q3_movement_hud.gd")
const FORCE_VECTOR_DEBUG_ADAPTER := preload("res://scripts/force_vector_debug_adapter.gd")
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
const WARSOW_GROUND_DETACH_SPEED := 180.0
const WARSOW_SLIDE_OVERBOUNCE := 1.01
const WARSOW_PLANE_INTERACTION_EPSILON := 0.05
const WARSOW_WALL_JUMP_COOLDOWN := 1.3
const WARSOW_WALL_JUMP_UP_SPEED := 330.0
const WARSOW_WALL_JUMP_BOUNCE := 0.3
const WARSOW_WALL_JUMP_OVERBOUNCE := 1.0005
const WARSOW_WALL_JUMP_MAX_NORMAL_Y := 0.3
const WARSOW_WALL_JUMP_PROBE_DIRECTIONS := 20
const WARSOW_DASH_SPEED := 450.0 * Q3_METERS_PER_UNIT
const WARSOW_DASH_UP_SPEED_THRESHOLD := 8.0 * Q3_METERS_PER_UNIT
const DEBUG_COLOR_NET_ACCELERATION := Color(1.0, 0.55, 0.1)

enum MovementMode {
	VQ3,
	WARSOW_CLASSIC,
}

var body: CharacterBody3D
var settings_controller_id := Settings.CHARACTER_Q3
var force_vector_debug

var velocity: Vector3:
	get:
		return body.velocity
	set(value):
		body.velocity = value
var position: Vector3:
	get:
		return body.position
	set(value):
		body.position = value
var global_position: Vector3:
	get:
		return body.global_position
	set(value):
		body.global_position = value
var rotation: Vector3:
	get:
		return body.rotation
	set(value):
		body.rotation = value
var transform: Transform3D:
	get:
		return body.transform
	set(value):
		body.transform = value
var global_transform: Transform3D:
	get:
		return body.global_transform
	set(value):
		body.global_transform = value
var global_basis: Basis:
	get:
		return body.global_basis
	set(value):
		body.global_basis = value
var floor_max_angle: float:
	get:
		return body.floor_max_angle
	set(value):
		body.floor_max_angle = value
var floor_snap_length: float:
	get:
		return body.floor_snap_length
	set(value):
		body.floor_snap_length = value
var floor_stop_on_slope: bool:
	get:
		return body.floor_stop_on_slope
	set(value):
		body.floor_stop_on_slope = value
var safe_margin: float:
	get:
		return body.safe_margin
	set(value):
		body.safe_margin = value
var collision_mask: int:
	get:
		return body.collision_mask
	set(value):
		body.collision_mask = value
var motion_mode: CharacterBody3D.MotionMode:
	get:
		return body.motion_mode
	set(value):
		body.motion_mode = value


func is_on_floor() -> bool:
	return body.is_on_floor()


func get_floor_normal() -> Vector3:
	return body.get_floor_normal()


func apply_floor_snap() -> void:
	body.apply_floor_snap()


func move_and_slide() -> bool:
	return body.move_and_slide()


func move_and_collide(
	motion: Vector3,
	test_only := false,
	motion_safe_margin := 0.001,
	recovery_as_collision := false,
) -> KinematicCollision3D:
	return body.move_and_collide(motion, test_only, motion_safe_margin, recovery_as_collision)


func test_move(
	from_transform: Transform3D,
	motion: Vector3,
	collision: KinematicCollision3D = null,
	motion_safe_margin := 0.001,
	recovery_as_collision := false,
) -> bool:
	return body.test_move(from_transform, motion, collision, motion_safe_margin, recovery_as_collision)


func get_slide_collision_count() -> int:
	return body.get_slide_collision_count()


func get_slide_collision(collision_index: int) -> KinematicCollision3D:
	return body.get_slide_collision(collision_index)


func get_world_3d() -> World3D:
	return body.get_world_3d()


func get_rid() -> RID:
	return body.get_rid()



# Runtime values; overwritten from Settings in _ready and on settings_changed.
var movement_mode := MovementMode.VQ3
var auto_jump := false
var crouch_slide_enabled := false
var ramp_launch_enabled := false
var wall_jump_enabled := false
var third_person_enabled := false
var control_enabled := true
var character_size := Vector3(
	30.0 * Q3_METERS_PER_UNIT,
	Q3_STANDING_HULL_HEIGHT * Q3_METERS_PER_UNIT,
	30.0 * Q3_METERS_PER_UNIT,
)
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

var head: Node3D
var camera: Camera3D
var third_person_spring_arm: SpringArm3D
var third_person_camera: Camera3D
var collision_shape: CollisionShape3D
var character_collider_visual: MeshInstance3D
var hud: Q3_MOVEMENT_HUD

var pitch := 0.0
var yaw := 0.0
var floor_is_slick := false
var is_crouching := false
var is_crouch_sliding := false
var crouch_slide_time_remaining := 0.0
var ground_friction_multiplier := 1.0
var wall_jump_cooldown_remaining := 0.0
var body_shape: BoxShape3D
var body_mesh: BoxMesh
var water_level := 0
var water_type: StringName
var water_jump_time_remaining := 0.0


func setup(
	body_ref: CharacterBody3D,
	refs: Dictionary,
	controller_id := Settings.CHARACTER_Q3,
	duplicate_collision_shape := true,
) -> void:
	body = body_ref
	settings_controller_id = controller_id
	force_vector_debug = FORCE_VECTOR_DEBUG_ADAPTER.new(body, settings_controller_id)
	head = refs.get("head") as Node3D
	camera = refs.get("camera") as Camera3D
	third_person_spring_arm = refs.get("third_person_spring_arm") as SpringArm3D
	third_person_camera = refs.get("third_person_camera") as Camera3D
	collision_shape = refs.get("collision_shape") as CollisionShape3D
	character_collider_visual = refs.get("character_collider_visual") as MeshInstance3D
	hud = refs.get("hud") as Q3_MOVEMENT_HUD
	_apply_controller_settings()
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_stop_on_slope = false
	floor_snap_length = step_height
	if duplicate_collision_shape:
		body_shape = (collision_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		collision_shape.shape = body_shape
	else:
		body_shape = collision_shape.shape as BoxShape3D
	body_mesh = (character_collider_visual.mesh as BoxMesh).duplicate() as BoxMesh
	character_collider_visual.mesh = body_mesh
	_set_stance_geometry(false)
	pitch = head.rotation.x
	yaw = rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func process_tick(_delta: float) -> void:
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


func physics_tick(delta: float) -> void:
	var debug_start_velocity := velocity
	_begin_force_vector_debug_frame()
	_update_crouch_state()
	_update_water_level()
	wall_jump_cooldown_remaining = maxf(wall_jump_cooldown_remaining - delta, 0.0)
	var grounded := is_on_floor()
	var floor_normal := get_floor_normal() if grounded else Vector3.UP
	var warsow_detached := (
		movement_mode == MovementMode.WARSOW_CLASSIC
		and velocity.y > WARSOW_GROUND_DETACH_SPEED * Q3_METERS_PER_UNIT
	)
	if warsow_detached:
		grounded = false
		floor_normal = Vector3.UP
	elif not grounded:
		var ground_collision := _get_ground_collision()
		if ground_collision != null:
			var traced_normal := ground_collision.get_normal()
			var kicked_off := (
				movement_mode != MovementMode.WARSOW_CLASSIC
				and velocity.y > 0.0
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
		_end_force_vector_debug_frame(debug_start_velocity, delta)
		return
	if water_level > 1:
		if _try_water_jump():
			_water_jump_move(delta)
			_end_force_vector_debug_frame(debug_start_velocity, delta)
			return
		_water_move(movement_input, delta)
		_end_force_vector_debug_frame(debug_start_velocity, delta)
		return
	if grounded and _jump_requested() and not Input.is_action_pressed("player_crouch"):
		_apply_jump_velocity(floor_normal)
		grounded = false
	var wall_jumped := _try_wall_jump(grounded)

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
		if not wall_jumped:
			_air_move(wish_direction, wish_speed, movement_input, delta)
		airborne_end_velocity_y = velocity.y - (gravity * delta)
		velocity.y = (velocity.y + airborne_end_velocity_y) * 0.5

	if grounded:
		_try_step_up(delta)

	var move_velocity := velocity
	move_and_slide()
	if is_on_floor():
		if grounded:
			_restore_velocity_on_floor_plane(get_floor_normal())
	else:
		var default_velocity_y := move_velocity.y if grounded else airborne_end_velocity_y
		velocity.y = _get_ramp_collision_velocity_y(move_velocity, default_velocity_y)
	_update_floor_surface()
	_end_force_vector_debug_frame(debug_start_velocity, delta)


func _get_movement_input() -> Vector2:
	if not control_enabled:
		return Vector2.ZERO
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
	if not control_enabled:
		return 1.0
	return walk_speed_scale if Input.is_action_pressed("player_walk") else 1.0


func _get_vertical_input() -> float:
	if not control_enabled:
		return 0.0
	return (Input.get_action_strength("player_jump") - Input.get_action_strength("player_crouch"))


func _jump_requested() -> bool:
	if not control_enabled:
		return false
	if KeybindingsSettings.is_action_just_pressed(&"player_jump"):
		return true
	if auto_jump:
		return Input.is_action_pressed("player_jump")
	return false


func _apply_jump_velocity(ground_normal: Vector3) -> void:
	if movement_mode != MovementMode.WARSOW_CLASSIC:
		velocity.y = jump_velocity
		return
	# Warsow clips against the ground when jumping while moving down toward it
	# (gs_pmove.cpp:1166); horizontal dot with the normal means moving downhill.
	if (
		ground_normal.y > 0.0
		and velocity.y < 0.0
		and (velocity.x * ground_normal.x) + (velocity.z * ground_normal.z) > 0.0
	):
		velocity = _clip_velocity(velocity, ground_normal, WARSOW_SLIDE_OVERBOUNCE)
	# Grounded upward carry is added to, not replaced: the ramp/ledge double
	# jump (gs_pmove.cpp:1171).
	if velocity.y > 0.0:
		velocity.y += jump_velocity
	else:
		velocity.y = jump_velocity


func _try_wall_jump(grounded: bool) -> bool:
	if (
		not control_enabled
		or not wall_jump_enabled
		or grounded
		or water_level > 1
		or wall_jump_cooldown_remaining > 0.0
		or not KeybindingsSettings.is_action_just_pressed(&"player_special")
		or not _wall_jump_height_allowed()
	):
		return false

	var wall_normal := _get_wall_jump_normal()
	if wall_normal == Vector3.ZERO:
		return false

	var old_vertical_velocity := velocity.y
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	# Warsow clips the normalized horizontal direction, so the 0.3 bounce bias
	# weighs against a unit vector (gs_pmove.cpp:1343).
	var horizontal_direction := (
		horizontal_velocity / horizontal_speed if horizontal_speed > 0.0 else Vector3.ZERO
	)
	var response := _clip_velocity(horizontal_direction, wall_normal, WARSOW_WALL_JUMP_OVERBOUNCE)
	response += wall_normal * WARSOW_WALL_JUMP_BOUNCE
	if response.is_zero_approx():
		response = wall_normal
	var minimum_speed := (WARSOW_WALK_SPEED * Q3_METERS_PER_UNIT + move_speed) * 0.5
	response = response.normalized() * maxf(horizontal_speed, minimum_speed)
	velocity = response
	var gravity_scale := gravity / (Q3_GRAVITY * Q3_METERS_PER_UNIT)
	velocity.y = maxf(old_vertical_velocity, WARSOW_WALL_JUMP_UP_SPEED * Q3_METERS_PER_UNIT * gravity_scale)
	wall_jump_cooldown_remaining = WARSOW_WALL_JUMP_COOLDOWN
	return true


func _wall_jump_height_allowed() -> bool:
	if Input.is_action_pressed("player_jump"):
		return true
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > WARSOW_DASH_SPEED and velocity.y > WARSOW_DASH_UP_SPEED_THRESHOLD:
		return true

	var ground_collision := KinematicCollision3D.new()
	if not test_move(
		global_transform,
		Vector3.DOWN * step_height,
		ground_collision,
		safe_margin,
		false,
	):
		return true
	return ground_collision.get_normal().y < cos(floor_max_angle)


func _get_wall_jump_normal() -> Vector3:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if _wall_jump_collision_allowed(collision):
			return collision.get_normal()

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var primary_direction := _get_wish_direction(_get_movement_input(), Vector3.UP)
	if primary_direction.is_zero_approx():
		primary_direction = horizontal_velocity.normalized()
	if primary_direction.is_zero_approx():
		primary_direction = -global_transform.basis.z
		primary_direction.y = 0.0
		primary_direction = primary_direction.normalized()

	for direction_index in WARSOW_WALL_JUMP_PROBE_DIRECTIONS:
		var direction := primary_direction.rotated(
			Vector3.UP,
			TAU * direction_index / WARSOW_WALL_JUMP_PROBE_DIRECTIONS,
		)
		var predicted_distance := maxf(horizontal_velocity.dot(direction), 0.0) * 0.015
		var probe_gap := maxf(body_shape.size.x, body_shape.size.z) * 0.5
		var collision := KinematicCollision3D.new()
		if test_move(
			global_transform,
			direction * (probe_gap + predicted_distance),
			collision,
			safe_margin,
			true,
		) and _wall_jump_collision_allowed(collision):
			return collision.get_normal()
	return Vector3.ZERO


func _wall_jump_collision_allowed(collision: KinematicCollision3D) -> bool:
	return (
		absf(collision.get_normal().y) < WARSOW_WALL_JUMP_MAX_NORMAL_Y
		and not (collision.get_collider() is CharacterBody3D)
	)


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
	if not control_enabled:
		if is_crouching and _can_stand():
			_set_crouching(false)
		return
	if Input.is_action_pressed("player_crouch"):
		if not is_crouching:
			_set_crouching(true)
	elif is_crouching and _can_stand():
		_set_crouching(false)


func _set_crouching(value: bool) -> void:
	is_crouching = value
	_set_stance_geometry(value)


func _set_stance_geometry(crouching: bool) -> void:
	var hull_height := character_size.y
	if crouching:
		hull_height *= Q3_CROUCH_HULL_HEIGHT / Q3_STANDING_HULL_HEIGHT
	var eye_height_ratio := (
		Q3_CROUCH_EYE_HEIGHT / Q3_CROUCH_HULL_HEIGHT
		if crouching
		else Q3_STANDING_EYE_HEIGHT / Q3_STANDING_HULL_HEIGHT
	)
	var eye_height := hull_height * eye_height_ratio
	body_shape.size = Vector3(character_size.x, hull_height, character_size.z)
	collision_shape.position.y = hull_height * 0.5
	head.position.y = eye_height
	if body_mesh != null:
		body_mesh.size = body_shape.size
		character_collider_visual.position = collision_shape.position


func set_character_size(value: Vector3) -> void:
	character_size = value
	if body_shape != null:
		_set_stance_geometry(is_crouching)


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
	if not control_enabled or water_level != 2:
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
		return ground_friction * ground_friction_multiplier
	if crouch_slide_time_remaining >= WARSOW_CROUCH_SLIDE_FADE:
		return 0.0
	var fade_fraction := maxf(crouch_slide_time_remaining, 0.0) / WARSOW_CROUCH_SLIDE_FADE
	return ground_friction * (1.0 - sqrt(fade_fraction)) * ground_friction_multiplier


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


func _get_ramp_collision_velocity_y(input_velocity: Vector3, default_velocity_y: float) -> float:
	if not ramp_launch_enabled:
		return default_velocity_y

	var result := default_velocity_y
	var walkable_normal_y := cos(floor_max_angle)
	for collision_index in get_slide_collision_count():
		var plane_normal := get_slide_collision(collision_index).get_normal()
		if (
			plane_normal.y < WARSOW_PLANE_INTERACTION_EPSILON
			or plane_normal.y >= walkable_normal_y
			or input_velocity.dot(plane_normal) >= WARSOW_PLANE_INTERACTION_EPSILON
		):
			continue
		result = maxf(result, velocity.y)
		result = maxf(result, _clip_velocity(input_velocity, plane_normal, WARSOW_SLIDE_OVERBOUNCE).y)
	return result


func _clip_velocity(input_velocity: Vector3, plane_normal: Vector3, overbounce: float) -> Vector3:
	var backoff := input_velocity.dot(plane_normal)
	backoff = backoff * overbounce if backoff <= 0.0 else backoff / overbounce
	return input_velocity - (plane_normal * backoff)


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


func handle_unhandled_input(event: InputEvent) -> void:
	if not control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - (event.relative.y * mouse_sensitivity), deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation.y = yaw
		head.rotation.x = pitch


func on_settings_changed() -> void:
	_apply_controller_settings()
	if force_vector_debug != null:
		force_vector_debug.sync_from_settings()


func _begin_force_vector_debug_frame() -> void:
	if force_vector_debug == null:
		return

	force_vector_debug.begin_frame()


func set_force_vector_debug_active(active: bool) -> void:
	if force_vector_debug == null:
		return

	force_vector_debug.set_active(active)


func clear_force_vector_debug() -> void:
	if force_vector_debug == null:
		return

	force_vector_debug.clear_frame()


func _end_force_vector_debug_frame(previous_velocity: Vector3, delta: float) -> void:
	if force_vector_debug == null:
		return

	force_vector_debug.push_velocity_change(
		_get_force_vector_debug_origin(),
		previous_velocity,
		velocity,
		delta,
		DEBUG_COLOR_NET_ACCELERATION,
	)
	force_vector_debug.end_frame()


func _get_force_vector_debug_origin() -> Vector3:
	return global_position + (Vector3.UP * maxf(character_size.y * 0.5, 0.5))


func _apply_controller_settings() -> void:
	movement_mode = roundi(Settings.get_controller_setting("movement_mode", settings_controller_id)) as MovementMode
	auto_jump = Settings.get_controller_setting("auto_jump", settings_controller_id) >= 0.5
	crouch_slide_enabled = Settings.get_controller_setting("crouch_slide", settings_controller_id) >= 0.5
	ramp_launch_enabled = Settings.get_controller_setting("ramp_launch", settings_controller_id) >= 0.5
	wall_jump_enabled = Settings.get_controller_setting("wall_jump", settings_controller_id) >= 0.5
	third_person_enabled = Settings.get_controller_setting("third_person", settings_controller_id) >= 0.5
	character_size = Vector3(
		Settings.get_controller_setting("character_size_x", settings_controller_id),
		Settings.get_controller_setting("character_size_y", settings_controller_id),
		Settings.get_controller_setting("character_size_z", settings_controller_id),
	)
	if not wall_jump_enabled:
		wall_jump_cooldown_remaining = 0.0
	if not crouch_slide_enabled:
		is_crouch_sliding = false
		crouch_slide_time_remaining = 0.0
	move_speed = Settings.get_controller_setting("move_speed", settings_controller_id)
	ground_acceleration = Settings.get_controller_setting("ground_acceleration", settings_controller_id)
	air_acceleration = Settings.get_controller_setting("air_acceleration", settings_controller_id)
	friction = Settings.get_controller_setting("friction", settings_controller_id)
	stop_speed = Settings.get_controller_setting("stop_speed", settings_controller_id)
	gravity = Settings.get_controller_setting("gravity", settings_controller_id)
	jump_velocity = Settings.get_controller_setting("jump_velocity", settings_controller_id)
	step_height = Settings.get_controller_setting("step_height", settings_controller_id)
	max_slope_angle = Settings.get_controller_setting("max_slope_angle", settings_controller_id)
	crouch_speed_scale = Settings.get_controller_setting("crouch_speed_scale", settings_controller_id)
	walk_speed_scale = Settings.get_controller_setting("walk_speed_scale", settings_controller_id)
	swim_speed_scale = Settings.get_controller_setting("swim_speed_scale", settings_controller_id)
	water_acceleration = Settings.get_controller_setting("water_acceleration", settings_controller_id)
	water_friction = Settings.get_controller_setting("water_friction", settings_controller_id)
	slime_friction = Settings.get_controller_setting("slime_friction", settings_controller_id)
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", settings_controller_id)
	var camera_fov := Settings.get_controller_setting("fov", settings_controller_id)
	camera.fov = camera_fov
	third_person_camera.fov = camera_fov
	third_person_spring_arm.spring_length = Settings.get_controller_setting(
		"third_person_distance",
		settings_controller_id,
	)
	camera.current = not third_person_enabled
	third_person_camera.current = third_person_enabled
	character_collider_visual.visible = third_person_enabled
	if body_shape != null:
		_set_stance_geometry(is_crouching)
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = step_height

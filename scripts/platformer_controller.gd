class_name PlatformerController
extends CharacterBody3D

const FORCE_VECTOR_DEBUG_ADAPTER := preload("res://scripts/force_vector_debug_adapter.gd")
const SOURCE_FPS := 30.0
const METERS_PER_SOURCE_UNIT := 0.0125
const DEFAULT_MAX_TARGET_SPEED := 32.0
const DEFAULT_SLOW_TARGET_SPEED := 24.0
const DEFAULT_GROUND_ACCELERATION := 1.1
const DEFAULT_GROUND_DECELERATION := 1.0
const DEFAULT_TURN_RATE_DEGREES := 11.25
const DEFAULT_AIR_ACCELERATION := 1.5
const DEFAULT_AIR_DRAG := 0.35
const DEFAULT_GRAVITY := 4.0
const DEFAULT_JUMP_VELOCITY := 42.0
const DEFAULT_SWIM_SPEED := 28.0
const DEFAULT_BUOYANCY := -2.0
const TERMINAL_VELOCITY := -75.0
const DROP_SNAP_UNITS := 100.0
const GROUND_LOWER_WALL_PROBE_OFFSET_UNITS := 30.0
const GROUND_LOWER_WALL_PROBE_RADIUS_UNITS := 24.0
const GROUND_UPPER_WALL_PROBE_OFFSET_UNITS := 60.0
const GROUND_UPPER_WALL_PROBE_RADIUS_UNITS := 50.0
const AIR_LOWER_WALL_PROBE_OFFSET_UNITS := 30.0
const AIR_UPPER_WALL_PROBE_OFFSET_UNITS := 150.0
const AIR_WALL_PROBE_RADIUS_UNITS := 50.0
const SWIM_WALL_PROBE_OFFSET_UNITS := 10.0
const SWIM_WALL_PROBE_RADIUS_UNITS := 110.0
const STANDING_CLEARANCE_UNITS := 160.0
const FLOOR_RAYCAST_UP_UNITS := 4.0
const FLOOR_RAYCAST_DOWN_UNITS := 20.0
const FALL_DAMAGE_DISTANCE_UNITS := 1150.0
const MAX_INTENDED_MAGNITUDE := 32.0
const LONG_JUMP_THRESHOLD := 10.0
const TRIPLE_JUMP_THRESHOLD := 20.0
const TURNAROUND_MIN_SPEED := 16.0
const TURNAROUND_ANGLE_DEGREES := 100.0
const TURNAROUND_EXIT_SPEED := 8.0
const TURNAROUND_DECELERATION_COEFFICIENT := 2.0
const DOUBLE_JUMP_WINDOW := 5.0 / SOURCE_FPS
const WALL_KICK_WINDOW := 5.0 / SOURCE_FPS
const VOLUME_COLLISION_MASK := 2
const DEFAULT_RADIUS := GROUND_UPPER_WALL_PROBE_RADIUS_UNITS * METERS_PER_SOURCE_UNIT
const DEFAULT_HEIGHT := STANDING_CLEARANCE_UNITS * METERS_PER_SOURCE_UNIT
const DEBUG_COLOR_NET_ACCELERATION := Color(1.0, 0.55, 0.1)

enum Action {
	IDLE,
	WALKING,
	DECELERATING,
	TURNING_AROUND,
	SLIDING,
	JUMP,
	DOUBLE_JUMP,
	TRIPLE_JUMP,
	BACKFLIP,
	SIDE_FLIP,
	LONG_JUMP,
	WALL_KICK,
	DIVE,
	GROUND_POUND,
	FALL,
	LAVA_BOOST,
	SWIMMING,
}

enum SurfaceClass {
	DEFAULT,
	VERY_SLIPPERY,
	SLIPPERY,
	NOT_SLIPPERY,
}

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var face_marker: MeshInstance3D = $FaceMarker
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var third_person_camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var first_person_camera: Camera3D = $CameraRig/FirstPersonCamera
@onready var status_label: Label = $HUD/StatusLabel

var action := Action.IDLE
var previous_air_action := Action.FALL
var forward_speed := 0.0
var vertical_speed := 0.0
var face_yaw := PI
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(-15.0)
var swim_pitch := 0.0
var slide_velocity := Vector2.ZERO
var current_surface: StringName = &"default"
var current_medium: StringName = &""
var quicksand_depth := 0.0
var peak_height := 0.0
var took_fall_damage := false
var jump_chain := 0
var jump_chain_timer := 0.0
var wall_kick_timer := 0.0
var last_wall_normal := Vector3.ZERO
var floor_collider: Node
var water_area: Area3D

var max_run_speed := DEFAULT_MAX_TARGET_SPEED
var slow_surface_speed := DEFAULT_SLOW_TARGET_SPEED
var ground_acceleration := DEFAULT_GROUND_ACCELERATION
var ground_deceleration := DEFAULT_GROUND_DECELERATION
var turn_rate_degrees := DEFAULT_TURN_RATE_DEGREES
var air_acceleration := DEFAULT_AIR_ACCELERATION
var air_drag := DEFAULT_AIR_DRAG
var gravity := DEFAULT_GRAVITY
var jump_velocity := DEFAULT_JUMP_VELOCITY
var swim_speed := DEFAULT_SWIM_SPEED
var buoyancy := DEFAULT_BUOYANCY
var mouse_sensitivity := 0.003
var character_radius := DEFAULT_RADIUS
var character_height := DEFAULT_HEIGHT
var first_person_enabled := false
var force_vector_debug


func _ready() -> void:
	force_vector_debug = FORCE_VECTOR_DEBUG_ADAPTER.new(self, Settings.CHARACTER_PLATFORMER)
	collision_shape.shape = collision_shape.shape.duplicate()
	body_mesh.mesh = body_mesh.mesh.duplicate()
	_apply_controller_settings()
	floor_max_angle = deg_to_rad(75.0)
	floor_snap_length = source_units_to_meters(DROP_SNAP_UNITS)
	floor_stop_on_slope = false
	floor_constant_speed = true
	_apply_camera_rotation()
	Settings.settings_changed.connect(on_settings_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var medium_text: String = str(current_medium) if not current_medium.is_empty() else "air"
	status_label.text = "Action  %s\nSpeed   %.2f u/f\nSurface %s\nMedium  %s" % [
		Action.keys()[action],
		forward_speed,
		current_surface,
		medium_text,
	]


func _physics_process(delta: float) -> void:
	var debug_start_velocity := velocity
	_begin_force_vector_debug_frame()
	var native_frames := delta * SOURCE_FPS
	jump_chain_timer = maxf(jump_chain_timer - delta, 0.0)
	wall_kick_timer = maxf(wall_kick_timer - delta, 0.0)
	if jump_chain_timer <= 0.0 and is_on_floor():
		jump_chain = 0

	_update_medium()
	var movement_input := _get_movement_input()
	var intended_magnitude := minf(movement_input.length(), 1.0) * MAX_INTENDED_MAGNITUDE
	var intended_yaw := face_yaw
	if intended_magnitude > 0.0:
		intended_yaw = _get_intended_yaw(movement_input)

	var grounded := is_on_floor()
	if grounded:
		_update_floor_surface()
		if _is_air_action(action):
			_land()

	if current_medium == &"water":
		_update_swimming(native_frames, movement_input, intended_magnitude, intended_yaw)
	elif grounded:
		_update_grounded(native_frames, intended_magnitude, intended_yaw)
	else:
		_update_airborne(native_frames, intended_magnitude, intended_yaw)

	_apply_motion_velocity()
	move_and_slide()
	_handle_collisions()
	if not grounded and is_on_floor() and current_medium != &"water":
		_update_floor_surface()
		_land()
		vertical_speed = 0.0
	if not is_on_floor():
		peak_height = maxf(peak_height, global_position.y)
	_apply_camera_rotation()
	_end_force_vector_debug_frame(debug_start_velocity, delta)


func _update_grounded(native_frames: float, intended_magnitude: float, intended_yaw: float) -> void:
	vertical_speed = -0.1
	floor_snap_length = source_units_to_meters(DROP_SNAP_UNITS)
	if current_surface == &"burning":
		_start_lava_boost()
		return

	_update_quicksand(native_frames)
	if Input.is_action_just_pressed("player_jump"):
		_start_ground_jump(intended_magnitude, intended_yaw)
		return

	if _floor_should_slide(get_floor_normal()):
		_update_sliding(native_frames, intended_magnitude, intended_yaw)
		return

	if action == Action.TURNING_AROUND:
		_update_turning_around(native_frames, intended_magnitude, intended_yaw, get_floor_normal())
	elif intended_magnitude > 0.0:
		if forward_speed >= TURNAROUND_MIN_SPEED and _input_is_held_back(intended_yaw):
			action = Action.TURNING_AROUND
		else:
			action = Action.WALKING
			_update_walking_speed(native_frames, intended_magnitude, intended_yaw, get_floor_normal())
	else:
		forward_speed = _approach_value(forward_speed, 0.0, ground_deceleration * native_frames)
		action = Action.IDLE if is_zero_approx(forward_speed) else Action.DECELERATING

	var horizontal := _forward_vector(face_yaw) * forward_speed
	horizontal += _get_surface_force(native_frames)
	slide_velocity = Vector2(horizontal.x, horizontal.z)


func _update_turning_around(
	native_frames: float,
	intended_magnitude: float,
	intended_yaw: float,
	floor_normal: Vector3
) -> void:
	if intended_magnitude <= 0.0:
		forward_speed = _approach_value(forward_speed, 0.0, ground_deceleration * native_frames)
		action = Action.IDLE if is_zero_approx(forward_speed) else Action.DECELERATING
		return
	if not _input_is_held_back(intended_yaw):
		action = Action.WALKING
		_update_walking_speed(native_frames, intended_magnitude, intended_yaw, floor_normal)
		return
	var deceleration := _slope_deceleration(
		_surface_class(current_surface),
		ground_deceleration * TURNAROUND_DECELERATION_COEFFICIENT,
	)
	forward_speed = _approach_value(forward_speed, 0.0, deceleration * native_frames)
	_apply_slope_acceleration(native_frames, floor_normal)
	if is_zero_approx(forward_speed):
		face_yaw = intended_yaw
		forward_speed = TURNAROUND_EXIT_SPEED
		action = Action.WALKING


func _update_airborne(native_frames: float, intended_magnitude: float, intended_yaw: float) -> void:
	if action == Action.SWIMMING:
		action = Action.FALL
		vertical_speed = mps_to_source_speed(velocity.y)
	if not _is_air_action(action):
		action = Action.FALL
		peak_height = global_position.y

	if Input.is_action_just_pressed("player_jump") and wall_kick_timer > 0.0:
		_start_wall_kick()
	elif Input.is_action_just_pressed("player_special") and action != Action.DIVE:
		_start_dive()
	elif Input.is_action_just_pressed("player_crouch") and action != Action.GROUND_POUND:
		_start_ground_pound()

	if action == Action.GROUND_POUND:
		forward_speed = 0.0
		slide_velocity = Vector2.ZERO
		vertical_speed = -50.0
		return

	var horizontal := _update_air_without_turn(native_frames, intended_magnitude, intended_yaw)
	slide_velocity = horizontal
	if action == Action.LONG_JUMP:
		vertical_speed = maxf(vertical_speed - (2.0 * native_frames), TERMINAL_VELOCITY)
	elif action == Action.LAVA_BOOST:
		vertical_speed = maxf(vertical_speed - (3.2 * native_frames), -65.0)
	elif not Input.is_action_pressed("player_jump") and vertical_speed > 20.0 and _action_has_variable_jump_height():
		vertical_speed *= pow(0.25, native_frames)
	else:
		vertical_speed = maxf(vertical_speed - (gravity * native_frames), TERMINAL_VELOCITY)

	if current_surface == &"vertical_wind" and action != Action.GROUND_POUND:
		vertical_speed = minf(vertical_speed + (6.25 * native_frames), 50.0)


func _update_swimming(
	native_frames: float,
	movement_input: Vector2,
	intended_magnitude: float,
	intended_yaw: float
) -> void:
	action = Action.SWIMMING
	if Input.is_action_just_pressed("player_jump"):
		forward_speed = minf(forward_speed + 6.0, swim_speed)
	elif intended_magnitude <= 0.0:
		forward_speed = _approach_value(forward_speed, 0.0, native_frames)

	if intended_magnitude > 0.0:
		face_yaw = _approach_angle(face_yaw, intended_yaw, deg_to_rad(6.0) * native_frames)
		var swim_direction := _get_camera_relative_direction(movement_input, true)
		var target_pitch := asin(clampf(swim_direction.y, -1.0, 1.0))
		swim_pitch = move_toward(swim_pitch, target_pitch, deg_to_rad(4.0) * native_frames)
	else:
		swim_pitch = move_toward(swim_pitch, 0.0, deg_to_rad(2.0) * native_frames)

	forward_speed = clampf(forward_speed, 0.0, swim_speed)
	if forward_speed > 16.0:
		forward_speed = maxf(forward_speed - (0.5 * native_frames), 16.0)
	var horizontal_speed := forward_speed * cos(swim_pitch)
	var horizontal := _forward_vector(face_yaw) * horizontal_speed
	horizontal += _get_surface_force(native_frames)
	slide_velocity = Vector2(horizontal.x, horizontal.z)
	vertical_speed = forward_speed * sin(swim_pitch)
	if intended_magnitude <= 0.0:
		vertical_speed += buoyancy


func _start_ground_jump(_intended_magnitude: float, intended_yaw: float) -> void:
	var old_speed := forward_speed
	if action == Action.TURNING_AROUND:
		action = Action.SIDE_FLIP
		vertical_speed = 62.0
		forward_speed = 8.0
		face_yaw = intended_yaw
	elif Input.is_action_pressed("player_crouch"):
		if forward_speed > LONG_JUMP_THRESHOLD:
			action = Action.LONG_JUMP
			vertical_speed = 30.0
			forward_speed = minf(forward_speed * 1.5, 48.0)
		else:
			action = Action.BACKFLIP
			vertical_speed = 62.0
			forward_speed = -16.0
	elif jump_chain == 1:
		action = Action.DOUBLE_JUMP
		vertical_speed = 52.0 + (old_speed * 0.25)
		forward_speed *= 0.8
	elif jump_chain == 2 and forward_speed > TRIPLE_JUMP_THRESHOLD:
		action = Action.TRIPLE_JUMP
		vertical_speed = 69.0
		forward_speed *= 0.8
	else:
		action = Action.JUMP
		vertical_speed = jump_velocity + (old_speed * 0.25)
		forward_speed *= 0.8
	peak_height = global_position.y
	previous_air_action = action
	_sync_slide_from_forward()
	floor_snap_length = 0.0


func _start_wall_kick() -> void:
	action = Action.WALL_KICK
	vertical_speed = 62.0
	forward_speed = maxf(absf(forward_speed), 24.0)
	face_yaw = _yaw_from_direction(last_wall_normal)
	wall_kick_timer = 0.0
	peak_height = global_position.y
	_sync_slide_from_forward()


func _start_dive() -> void:
	action = Action.DIVE
	forward_speed = minf(forward_speed + 15.0, 48.0)
	previous_air_action = action
	_sync_slide_from_forward()


func _start_ground_pound() -> void:
	action = Action.GROUND_POUND
	forward_speed = 0.0
	vertical_speed = -50.0
	previous_air_action = action


func _start_lava_boost() -> void:
	action = Action.LAVA_BOOST
	forward_speed = 0.0
	vertical_speed = 84.0
	peak_height = global_position.y
	previous_air_action = action
	_sync_slide_from_forward()


func _land() -> void:
	if not _is_air_action(action):
		return
	previous_air_action = action
	var fall_distance_units := meters_to_source_units(peak_height - global_position.y)
	took_fall_damage = (
		fall_distance_units > FALL_DAMAGE_DISTANCE_UNITS
		or (current_surface == &"hard" and vertical_speed < -55.0)
	)
	if action == Action.JUMP or action == Action.FALL or action == Action.SIDE_FLIP or action == Action.WALL_KICK:
		jump_chain = 1
		jump_chain_timer = DOUBLE_JUMP_WINDOW
	elif action == Action.DOUBLE_JUMP:
		jump_chain = 2
		jump_chain_timer = DOUBLE_JUMP_WINDOW
	else:
		jump_chain = 0
		jump_chain_timer = 0.0
	action = Action.IDLE
	vertical_speed = 0.0
	wall_kick_timer = 0.0
	floor_snap_length = source_units_to_meters(DROP_SNAP_UNITS)


func _update_walking_speed(
	native_frames: float,
	intended_magnitude: float,
	intended_yaw: float,
	floor_normal: Vector3
) -> void:
	var maximum_target := slow_surface_speed if current_surface == &"slow" else max_run_speed
	var target_speed := minf(intended_magnitude, maximum_target)
	if quicksand_depth > 10.0:
		target_speed *= 6.25 / quicksand_depth

	if forward_speed <= 0.0:
		forward_speed += ground_acceleration * native_frames
	elif forward_speed <= target_speed:
		forward_speed += (ground_acceleration - (forward_speed / 43.0)) * native_frames
	elif floor_normal.y >= 0.95:
		forward_speed -= ground_deceleration * native_frames
	forward_speed = minf(forward_speed, 48.0)
	face_yaw = _approach_angle(face_yaw, intended_yaw, deg_to_rad(turn_rate_degrees) * native_frames)
	_apply_slope_acceleration(native_frames, floor_normal)


func _update_air_without_turn(
	native_frames: float,
	intended_magnitude: float,
	intended_yaw: float
) -> Vector2:
	var sideways_speed := 0.0
	var drag_threshold := 48.0 if action == Action.LONG_JUMP else 32.0
	forward_speed = _approach_value(forward_speed, 0.0, air_drag * native_frames)
	if intended_magnitude > 0.0:
		var intended_delta := _angle_difference(face_yaw, intended_yaw)
		var magnitude_scale := intended_magnitude / MAX_INTENDED_MAGNITUDE
		forward_speed += magnitude_scale * cos(intended_delta) * air_acceleration * native_frames
		sideways_speed = magnitude_scale * sin(intended_delta) * 10.0
	if forward_speed > drag_threshold:
		forward_speed -= native_frames
	if forward_speed < -16.0:
		forward_speed += 2.0 * native_frames
	var forward := _forward_vector(face_yaw) * forward_speed
	var sideways := _forward_vector(face_yaw + (PI * 0.5)) * sideways_speed
	return Vector2(forward.x + sideways.x, forward.z + sideways.z)


func _update_sliding(native_frames: float, intended_magnitude: float, intended_yaw: float) -> void:
	if action != Action.SLIDING:
		action = Action.SLIDING
		var initial := _forward_vector(face_yaw) * forward_speed
		slide_velocity = Vector2(initial.x, initial.z)
	var floor_normal := get_floor_normal()
	var downhill_3d := Vector3.DOWN.slide(floor_normal)
	var steepness := Vector2(floor_normal.x, floor_normal.z).length()
	var downhill := Vector2(downhill_3d.x, downhill_3d.z).normalized()
	var surface_class := _surface_class(current_surface)
	var acceleration := 7.0
	var loss_factor := 0.92
	if surface_class == SurfaceClass.VERY_SLIPPERY:
		acceleration = 10.0
		loss_factor = 0.98
	elif surface_class == SurfaceClass.SLIPPERY:
		acceleration = 8.0
		loss_factor = 0.96
	elif surface_class == SurfaceClass.NOT_SLIPPERY:
		acceleration = 5.0
	var intended_delta := _angle_difference(_yaw_from_vector2(slide_velocity), intended_yaw)
	var forward_input := cos(intended_delta)
	var magnitude_scale := intended_magnitude / MAX_INTENDED_MAGNITUDE
	loss_factor += magnitude_scale * forward_input * 0.02
	_apply_slide_steering(native_frames, magnitude_scale, sin(intended_delta))
	slide_velocity += downhill * acceleration * steepness * native_frames
	slide_velocity *= pow(loss_factor, native_frames)
	forward_speed = slide_velocity.length()
	if not slide_velocity.is_zero_approx():
		face_yaw = _approach_angle(face_yaw, _yaw_from_vector2(slide_velocity), deg_to_rad(2.8125) * native_frames)
	if not _floor_should_slide(floor_normal) and forward_speed < 4.0:
		action = Action.IDLE


func _apply_slide_steering(native_frames: float, magnitude_scale: float, sideward_input: float) -> void:
	var old_speed := slide_velocity.length()
	slide_velocity.x += slide_velocity.y * magnitude_scale * sideward_input * 0.05 * native_frames
	slide_velocity.y -= slide_velocity.x * magnitude_scale * sideward_input * 0.05 * native_frames
	var steered_speed := slide_velocity.length()
	if old_speed > 0.0 and steered_speed > 0.0:
		slide_velocity *= old_speed / steered_speed


func _apply_slope_acceleration(native_frames: float, floor_normal: Vector3) -> void:
	if not _floor_is_slope(floor_normal):
		return
	var steepness := Vector2(floor_normal.x, floor_normal.z).length()
	var downhill := Vector3.DOWN.slide(floor_normal).normalized()
	var slope_acceleration := _slope_acceleration(_surface_class(current_surface))
	if _forward_vector(face_yaw).dot(downhill) >= 0.0:
		forward_speed += slope_acceleration * steepness * native_frames
	else:
		forward_speed -= slope_acceleration * steepness * native_frames


func _update_quicksand(native_frames: float) -> void:
	if current_surface == &"quicksand" or current_surface == &"moving_quicksand":
		quicksand_depth = minf(quicksand_depth + native_frames, 60.0)
	else:
		quicksand_depth = maxf(quicksand_depth - (2.0 * native_frames), 0.0)
	var visual_sink := minf(source_units_to_meters(quicksand_depth), character_height * 0.7)
	body_mesh.position.y = (character_height * 0.5) - visual_sink
	face_marker.position.y = (character_height * 0.6) - visual_sink


func _get_surface_force(native_frames: float) -> Vector3:
	var direction := Vector3.ZERO
	if floor_collider != null:
		var raw_direction: Variant = floor_collider.get_meta("platformer_force_direction", Vector3.ZERO)
		if raw_direction is Vector3:
			direction = raw_direction as Vector3
	if direction.is_zero_approx():
		direction = Vector3.RIGHT
	if current_surface == &"moving_quicksand":
		return direction.normalized() * 2.0 * native_frames
	if current_surface == &"horizontal_wind":
		return direction.normalized() * 4.0 * native_frames
	if current_surface == &"flowing_water":
		return direction.normalized() * 1.0 * native_frames
	return Vector3.ZERO


func _update_medium() -> void:
	water_area = _get_water_area_at(global_position + (Vector3.UP * character_height * 0.5))
	current_medium = &"water" if water_area != null else &""


func _get_water_area_at(point: Vector3) -> Area3D:
	if not is_inside_tree():
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = VOLUME_COLLISION_MASK
	query.collide_with_bodies = false
	query.collide_with_areas = true
	for result in get_world_3d().direct_space_state.intersect_point(query, 8):
		var area := result.get("collider") as Area3D
		if area == null:
			continue
		var medium := StringName(area.get_meta("platformer_medium", area.get_meta("q3_volume_type", &"")))
		if medium == &"water":
			return area
	return null


func _update_floor_surface() -> void:
	floor_collider = null
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y > 0.2:
			floor_collider = collision.get_collider() as Node
			break
	if floor_collider == null:
		floor_collider = _raycast_floor_collider()
	current_surface = _surface_type_from(floor_collider)


func _raycast_floor_collider() -> Node:
	if not is_inside_tree():
		return null
	var query := PhysicsRayQueryParameters3D.create(
		global_position + (Vector3.UP * source_units_to_meters(FLOOR_RAYCAST_UP_UNITS)),
		global_position + (Vector3.DOWN * source_units_to_meters(FLOOR_RAYCAST_DOWN_UNITS)),
		collision_mask,
		[get_rid()],
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("collider") as Node if not result.is_empty() else null


func _surface_type_from(collider: Node) -> StringName:
	while collider != null:
		if collider.has_meta("platformer_surface"):
			return StringName(collider.get_meta("platformer_surface"))
		collider = collider.get_parent()
	return &"default"


func _handle_collisions() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if normal.y < 0.3:
			if not is_on_floor() and _is_air_action(action):
				last_wall_normal = normal
				wall_kick_timer = WALL_KICK_WINDOW
		elif normal.y > 0.2:
			floor_collider = collision.get_collider() as Node
	if is_on_ceiling() and vertical_speed > 0.0:
		vertical_speed = 0.0


func _apply_motion_velocity() -> void:
	velocity.x = source_speed_to_mps(slide_velocity.x)
	velocity.z = source_speed_to_mps(slide_velocity.y)
	velocity.y = source_speed_to_mps(vertical_speed)


func source_speed_to_mps(source_speed: float) -> float:
	return source_units_to_meters(source_speed) * SOURCE_FPS


func source_acceleration_to_mps2(source_acceleration: float) -> float:
	return source_units_to_meters(source_acceleration) * SOURCE_FPS * SOURCE_FPS


func mps_to_source_speed(meters_per_second: float) -> float:
	return meters_to_source_units(meters_per_second) / SOURCE_FPS


func source_units_to_meters(source_units: float) -> float:
	return source_units * METERS_PER_SOURCE_UNIT


func meters_to_source_units(meters: float) -> float:
	return meters / METERS_PER_SOURCE_UNIT


func _sync_slide_from_forward() -> void:
	var horizontal := _forward_vector(face_yaw) * forward_speed
	slide_velocity = Vector2(horizontal.x, horizontal.z)


func _get_movement_input() -> Vector2:
	return Input.get_vector("player_left", "player_right", "player_back", "player_forward")


func _get_intended_yaw(movement_input: Vector2) -> float:
	return _yaw_from_direction(_get_camera_relative_direction(movement_input, false))


func _get_camera_relative_direction(movement_input: Vector2, include_pitch: bool) -> Vector3:
	var active_camera := get_view_camera()
	var forward := -active_camera.global_transform.basis.z
	var right := active_camera.global_transform.basis.x
	if not include_pitch:
		forward.y = 0.0
		right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return ((right * movement_input.x) + (forward * movement_input.y)).normalized()


func _input_is_held_back(intended_yaw: float) -> bool:
	return absf(_angle_difference(face_yaw, intended_yaw)) > deg_to_rad(TURNAROUND_ANGLE_DEGREES)


func _floor_should_slide(floor_normal: Vector3) -> bool:
	return floor_normal.y <= _slippery_normal_y(_surface_class(current_surface))


func _floor_is_slope(floor_normal: Vector3) -> bool:
	var threshold := cos(deg_to_rad(15.0))
	var surface_class := _surface_class(current_surface)
	if surface_class == SurfaceClass.VERY_SLIPPERY:
		threshold = cos(deg_to_rad(5.0))
	elif surface_class == SurfaceClass.SLIPPERY:
		threshold = cos(deg_to_rad(10.0))
	elif surface_class == SurfaceClass.NOT_SLIPPERY:
		threshold = cos(deg_to_rad(20.0))
	return floor_normal.y <= threshold


func _surface_class(surface: StringName) -> SurfaceClass:
	if surface == &"very_slippery" or surface == &"ice" or surface == &"hard_very_slippery":
		return SurfaceClass.VERY_SLIPPERY
	if surface == &"slippery" or surface == &"hard_slippery":
		return SurfaceClass.SLIPPERY
	if surface == &"not_slippery" or surface == &"hard_not_slippery":
		return SurfaceClass.NOT_SLIPPERY
	return SurfaceClass.DEFAULT


func _slope_acceleration(surface_class: SurfaceClass) -> float:
	if surface_class == SurfaceClass.VERY_SLIPPERY:
		return 5.3
	if surface_class == SurfaceClass.SLIPPERY:
		return 2.7
	if surface_class == SurfaceClass.NOT_SLIPPERY:
		return 0.0
	return 1.7


func _slope_deceleration(surface_class: SurfaceClass, coefficient: float) -> float:
	if surface_class == SurfaceClass.VERY_SLIPPERY:
		return coefficient * 0.2
	if surface_class == SurfaceClass.SLIPPERY:
		return coefficient * 0.7
	if surface_class == SurfaceClass.NOT_SLIPPERY:
		return coefficient * 3.0
	return coefficient * 2.0


func _slippery_normal_y(surface_class: SurfaceClass) -> float:
	if surface_class == SurfaceClass.VERY_SLIPPERY:
		return cos(deg_to_rad(10.0))
	if surface_class == SurfaceClass.SLIPPERY:
		return cos(deg_to_rad(20.0))
	if surface_class == SurfaceClass.NOT_SLIPPERY:
		return 0.0
	return cos(deg_to_rad(38.0))


func _is_air_action(value: Action) -> bool:
	return value in [
		Action.JUMP,
		Action.DOUBLE_JUMP,
		Action.TRIPLE_JUMP,
		Action.BACKFLIP,
		Action.SIDE_FLIP,
		Action.LONG_JUMP,
		Action.WALL_KICK,
		Action.DIVE,
		Action.GROUND_POUND,
		Action.FALL,
		Action.LAVA_BOOST,
	]


func _action_has_variable_jump_height() -> bool:
	return action in [Action.JUMP, Action.DOUBLE_JUMP, Action.LONG_JUMP, Action.WALL_KICK]


func _forward_vector(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _yaw_from_direction(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


func _yaw_from_vector2(direction: Vector2) -> float:
	return atan2(direction.x, direction.y)


func _angle_difference(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)


func _approach_angle(from: float, to: float, amount: float) -> float:
	return from + clampf(_angle_difference(from, to), -amount, amount)


func _approach_value(from: float, to: float, amount: float) -> float:
	return move_toward(from, to, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(
			camera_pitch - (event.relative.y * mouse_sensitivity),
			deg_to_rad(-75.0),
			deg_to_rad(60.0),
		)
		_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	rotation.y = face_yaw
	camera_rig.rotation = Vector3(camera_pitch, camera_yaw - face_yaw, 0.0)


func place_at_view(view_transform: Transform3D) -> void:
	var view_euler := view_transform.basis.get_euler()
	position = view_transform.origin - (Vector3.UP * character_height * 0.72)
	camera_yaw = view_euler.y
	camera_pitch = view_euler.x
	face_yaw = wrapf(camera_yaw + PI, -PI, PI)


func get_view_camera() -> Camera3D:
	return first_person_camera if first_person_enabled else third_person_camera


func on_settings_changed() -> void:
	_apply_controller_settings()
	if force_vector_debug != null:
		force_vector_debug.sync_from_settings()


func _begin_force_vector_debug_frame() -> void:
	if force_vector_debug == null:
		return

	force_vector_debug.begin_frame()


func _end_force_vector_debug_frame(previous_velocity: Vector3, delta: float) -> void:
	if force_vector_debug == null:
		return

	force_vector_debug.push_velocity_change(
		global_position + (Vector3.UP * maxf(character_height * 0.5, 0.5)),
		previous_velocity,
		velocity,
		delta,
		DEBUG_COLOR_NET_ACCELERATION,
	)
	force_vector_debug.end_frame()


func _apply_controller_settings() -> void:
	max_run_speed = Settings.get_controller_setting("max_run_speed", Settings.CHARACTER_PLATFORMER)
	slow_surface_speed = Settings.get_controller_setting("slow_surface_speed", Settings.CHARACTER_PLATFORMER)
	ground_acceleration = Settings.get_controller_setting("ground_acceleration", Settings.CHARACTER_PLATFORMER)
	ground_deceleration = Settings.get_controller_setting("ground_deceleration", Settings.CHARACTER_PLATFORMER)
	turn_rate_degrees = Settings.get_controller_setting("turn_rate", Settings.CHARACTER_PLATFORMER)
	air_acceleration = Settings.get_controller_setting("air_acceleration", Settings.CHARACTER_PLATFORMER)
	air_drag = Settings.get_controller_setting("air_drag", Settings.CHARACTER_PLATFORMER)
	gravity = Settings.get_controller_setting("gravity", Settings.CHARACTER_PLATFORMER)
	jump_velocity = Settings.get_controller_setting("jump_velocity", Settings.CHARACTER_PLATFORMER)
	swim_speed = Settings.get_controller_setting("swim_speed", Settings.CHARACTER_PLATFORMER)
	buoyancy = Settings.get_controller_setting("buoyancy", Settings.CHARACTER_PLATFORMER)
	first_person_enabled = Settings.get_controller_setting("first_person", Settings.CHARACTER_PLATFORMER) >= 0.5
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", Settings.CHARACTER_PLATFORMER)
	character_radius = Settings.get_controller_setting("character_radius", Settings.CHARACTER_PLATFORMER)
	character_height = maxf(
		Settings.get_controller_setting("character_height", Settings.CHARACTER_PLATFORMER),
		character_radius * 2.0,
	)
	if third_person_camera != null:
		var camera_fov := Settings.get_controller_setting("fov", Settings.CHARACTER_PLATFORMER)
		third_person_camera.fov = camera_fov
		first_person_camera.fov = camera_fov
		third_person_camera.current = not first_person_enabled
		first_person_camera.current = first_person_enabled
		body_mesh.visible = not first_person_enabled
		face_marker.visible = not first_person_enabled
	if spring_arm != null:
		spring_arm.spring_length = Settings.get_controller_setting("camera_distance", Settings.CHARACTER_PLATFORMER)
	if collision_shape != null:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.radius = character_radius
		capsule.height = character_height
		collision_shape.position.y = character_height * 0.5
		var mesh := body_mesh.mesh as CapsuleMesh
		mesh.radius = character_radius
		mesh.height = character_height
		body_mesh.position.y = character_height * 0.5
		face_marker.position = Vector3(0.0, character_height * 0.6, character_radius)
		camera_rig.position.y = character_height * 0.72

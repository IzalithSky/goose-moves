class_name Q3CharacterController
extends CharacterBody3D

const Q3_UNITS_PER_FOOT := 8.0
const METERS_PER_FOOT := 0.3048
const Q3_METERS_PER_UNIT := METERS_PER_FOOT / Q3_UNITS_PER_FOOT
const Q3_SPEED := 320.0
const Q3_GRAVITY := 800.0
const Q3_JUMP_VELOCITY := 270.0
const Q3_STOP_SPEED := 100.0
const Q3_STEP_HEIGHT := 18.0
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
const Q3_WATER_SINK_SPEED := 60.0
const Q3_VOLUME_COLLISION_MASK := 2
const Q3_WATER_JUMP_FORWARD_DISTANCE := 30.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_LOW_PROBE_HEIGHT := (Q3_MINS_Z * -1.0 + 4.0) * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_CLEARANCE := 16.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_FORWARD_VELOCITY := 200.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_VELOCITY := 350.0 * Q3_METERS_PER_UNIT
const Q3_WATER_JUMP_DURATION := 2.0

@export_category("VQ3 Movement")
@export var move_speed := Q3_SPEED * Q3_METERS_PER_UNIT
@export var ground_acceleration := 10.0
@export var air_acceleration := 1.0
@export var friction := 6.0
@export var stop_speed := Q3_STOP_SPEED * Q3_METERS_PER_UNIT
@export var gravity := Q3_GRAVITY * Q3_METERS_PER_UNIT
@export var jump_velocity := Q3_JUMP_VELOCITY * Q3_METERS_PER_UNIT
@export var step_height := Q3_STEP_HEIGHT * Q3_METERS_PER_UNIT
@export_range(0.0, 89.0, 0.1, "degrees") var max_slope_angle := Q3_MAX_SLOPE_ANGLE

@export_category("VQ3 Stance")
@export var crouch_speed_scale := Q3_CROUCH_SPEED_SCALE
@export var walk_speed_scale := Q3_WALK_COMMAND / Q3_RUN_COMMAND

@export_category("VQ3 Water")
@export var swim_speed_scale := Q3_SWIM_SCALE
@export var water_acceleration := Q3_WATER_ACCELERATION
@export var water_friction := Q3_WATER_FRICTION

@export_category("View")
@export var mouse_sensitivity := 0.003

@onready var head: Node3D = $Head
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var pitch := 0.0
var yaw := 0.0
var floor_is_slick := false
var is_crouching := false
var body_shape: BoxShape3D
var water_level := 0
var water_type: StringName
var water_jump_time_remaining := 0.0


func _ready() -> void:
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_stop_on_slope = false
	floor_snap_length = step_height
	body_shape = (collision_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	collision_shape.shape = body_shape
	_set_stance_geometry(false)
	pitch = head.rotation.x
	yaw = rotation.y
	mouse_sensitivity = Settings.mouse_sensitivity
	Settings.settings_changed.connect(on_settings_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_update_crouch_state()
	_update_water_level()
	var grounded := is_on_floor()
	var floor_normal := get_floor_normal() if grounded else Vector3.UP
	var slick := grounded and floor_is_slick
	var movement_input := _get_movement_input()
	var wish_direction := _get_wish_direction(movement_input, floor_normal if grounded else Vector3.UP)
	var wish_speed := _get_wish_speed(movement_input)
	if water_jump_time_remaining > 0.0:
		_water_jump_move(delta)
		return
	if water_level > 1:
		if _try_water_jump():
			_water_jump_move(delta)
			return
		_water_move(movement_input, delta)
		return
	if water_level > 0:
		var wade_scale := 1.0 - ((1.0 - swim_speed_scale) * (water_level / 3.0))
		wish_speed = minf(wish_speed, move_speed * wade_scale)
	if grounded and is_crouching:
		wish_speed = minf(wish_speed, move_speed * crouch_speed_scale)
	_apply_friction(delta, grounded and not slick)

	if grounded and not slick:
		_accelerate(wish_direction, wish_speed, ground_acceleration, delta)
		if Input.is_action_just_pressed("player_jump") and not Input.is_action_pressed("player_crouch"):
			velocity.y = jump_velocity
			grounded = false
		else:
			_project_velocity_onto_plane(floor_normal)
	else:
		_accelerate(wish_direction, wish_speed, air_acceleration, delta)
		velocity.y -= gravity * delta

	if grounded:
		_try_step_up(delta)

	move_and_slide()
	if velocity.y <= 0.0:
		apply_floor_snap()
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


func _apply_friction(delta: float, apply_ground_friction: bool) -> void:
	var friction_velocity := velocity
	if apply_ground_friction:
		friction_velocity.y = 0.0
	var speed := friction_velocity.length()
	if speed <= 0.0:
		return

	var drop := 0.0
	if apply_ground_friction:
		drop += maxf(speed, stop_speed) * friction * delta
	if water_level > 0:
		drop += speed * water_friction * water_level * delta
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


func _project_velocity_onto_plane(plane_normal: Vector3) -> void:
	var speed := velocity.length()
	velocity = velocity.slide(plane_normal)
	if not velocity.is_zero_approx():
		velocity = velocity.normalized() * speed


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
		if collision.get_normal().y < cos(floor_max_angle):
			continue
		var collider := collision.get_collider()
		if collider is Node and (
			(collider.has_meta("q3_surface") and collider.get_meta("q3_surface") == &"slick")
			or (collider.has_meta("slick") and bool(collider.get_meta("slick")))
		):
			floor_is_slick = true
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - (event.relative.y * mouse_sensitivity), deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation.y = yaw
		head.rotation.x = pitch


func on_settings_changed() -> void:
	mouse_sensitivity = Settings.mouse_sensitivity

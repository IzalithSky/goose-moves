class_name FlightMovementMotor
extends RefCounted

const DEFAULT_CAMERA_DISTANCE := 5.0
const DEFAULT_CAMERA_HEIGHT := 1.6
const DEFAULT_GRAVITY_SCALE := 0.15
const DEFAULT_MASS := 4.0
const DEFAULT_FLAP_IMPULSE_STRENGTH := 4.7
const DEFAULT_FLAP_IMPULSE_ANGLE_DEGREES := 45.0
const DEFAULT_FLAP_COOLDOWN := 0.5
const DEFAULT_PITCH_RATE_DEGREES_PER_SECOND := 120.0
const DEFAULT_ROLL_RATE_DEGREES_PER_SECOND := 120.0
const DEFAULT_FIRST_PERSON_ENABLED := 0.0
const DEFAULT_CAMERA_FLY_BY_WIRE_ENABLED := 1.0
const DEFAULT_CAMERA_FLY_BY_WIRE_TARGET_DISTANCE := 120.0
const DEFAULT_CAMERA_FLY_BY_WIRE_PITCH_WINDOW_DEGREES := 15.0
const DEFAULT_SIDESLIP_COMPENSATION_ENABLED := 1.0
const DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES := 0.1
const FBW_DIRECTION_PITCH_RESPONSE_RATE := 0.6
const FBW_LEVEL_TURN_ROLL_RESPONSE_RATE := 0.9
const FBW_LEVEL_TURN_ROLL_GAIN := 1.4
const FBW_WINGS_LEVEL_ROLL_GAIN := 1.2
const FBW_ROLL_MAX_DESIRED_RATE := 1.8
const FBW_TURN_FULL_PULL_ANGLE_RAD := PI * 0.5
const FBW_TURN_ROLLOUT_ANGLE_RAD := PI / 4.0
const FBW_TURN_MIN_UNALIGNED_PULL_RATIO := 0.25
const FBW_TURN_PITCH_ANGLE_TO_RATE_GAIN := 0.85
const FBW_TURN_MAX_DESIRED_PITCH_RATE := 1.4
const FBW_TURN_MIN_PULL_ANGLE_RAD := 0.02
const FBW_TURN_ANGLE_DEADBAND_RAD := PI / 180.0
const FBW_WINGS_LEVEL_DEADBAND_RAD := PI / 180.0
const Q3_FLOOR_FRICTION := 6.0
const Q3_FLOOR_STOP_SPEED := 3.81
const FLOOR_NORMAL_Y := 0.7
const DEFAULT_REFERENCE_AREA := 0.275
const DEFAULT_EXTRA_LINEAR_DRAG_LINEAR_COEFFICIENT := 0.0
const DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT := 0.015
const DEFAULT_AIR_DENSITY := 1.225
const MAX_LIFT_AOA_MIN_AIRSPEED := 5.0
const MIN_AERODYNAMIC_SPEED_SQUARED := 0.0001
const MIN_DIRECTION_VECTOR_LENGTH_SQUARED := 0.000001
const COLLISION_OVERBOUNCE := 1.001
const MAX_COLLISION_SLIDES := 4

var body: CharacterBody3D
var settings_controller_id := Settings.CHARACTER_FLIGHT

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


const DEFAULT_LIFT_TABLE: Array[Vector2] = [
	Vector2(-27.6253890991211, -0.15062952041626),
	Vector2(-20.1257400512695, -0.990721225738525),
	Vector2(-10.1813583374023, -0.79803854227066),
	Vector2(-5.06200742721558, -0.398243486881256),
	Vector2(0.0, 0.0),
	Vector2(4.97950315475464, 0.393706113100052),
	Vector2(9.94499397277832, 0.797897636890411),
	Vector2(14.9804210662842, 1.19854366779327),
	Vector2(19.8759765625, 1.60273516178131),
	Vector2(24.064697265625, 1.38089370727539),
	Vector2(29.7328300476074, 0.169581770896912),
]
const DEFAULT_DRAG_TABLE: Array[Vector2] = [
	Vector2(-31.7460308074951, 0.340881764888763),
	Vector2(-26.1224498748779, 0.255310624837875),
	Vector2(-20.5895690917969, 0.180961921811104),
	Vector2(-16.3718814849854, 0.122044086456299),
	Vector2(-10.4761905670166, 0.0631262511014938),
	Vector2(-5.62358283996582, 0.0266533065587282),
	Vector2(0.173160284757614, 0.00265896669588983),
	Vector2(5.80498886108398, 0.0154308620840311),
	Vector2(11.0204086303711, 0.0645290613174438),
	Vector2(15.9637184143066, 0.123446896672249),
	Vector2(20.770975112915, 0.182364732027054),
	Vector2(26.2585029602051, 0.253907829523087),
	Vector2(31.0657596588135, 0.352104216814041),
]
var collision_shape: CollisionShape3D
var body_mesh: MeshInstance3D
var camera_rig: Node3D
var camera: Camera3D
var first_person_camera: Camera3D
var spring_arm: SpringArm3D
var status_label: Label

var view_active := true
var flap_cooldown_remaining := 0.0
var aoa_deg := 0.0
var sideslip_deg := 0.0
var _positive_max_lift_aoa_deg := 15.0
var _negative_max_lift_aoa_deg := -15.0
var mass := DEFAULT_MASS
var reference_area := DEFAULT_REFERENCE_AREA
var gravity_scale := DEFAULT_GRAVITY_SCALE
var extra_linear_drag_quadratic_coefficient := DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT
var flap_impulse_strength := DEFAULT_FLAP_IMPULSE_STRENGTH
var flap_impulse_angle_rad := deg_to_rad(DEFAULT_FLAP_IMPULSE_ANGLE_DEGREES)
var flap_cooldown := DEFAULT_FLAP_COOLDOWN
var pitch_rate_rad := deg_to_rad(DEFAULT_PITCH_RATE_DEGREES_PER_SECOND)
var roll_rate_rad := deg_to_rad(DEFAULT_ROLL_RATE_DEGREES_PER_SECOND)
var first_person_enabled := DEFAULT_FIRST_PERSON_ENABLED >= 0.5
var camera_fly_by_wire_enabled := DEFAULT_CAMERA_FLY_BY_WIRE_ENABLED >= 0.5
var camera_fly_by_wire_target_distance := DEFAULT_CAMERA_FLY_BY_WIRE_TARGET_DISTANCE
var camera_fly_by_wire_pitch_window_rad := deg_to_rad(DEFAULT_CAMERA_FLY_BY_WIRE_PITCH_WINDOW_DEGREES)
var sideslip_compensation_enabled := DEFAULT_SIDESLIP_COMPENSATION_ENABLED >= 0.5
var sideslip_compensation_max_yaw_rad := deg_to_rad(DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES)
var mouse_sensitivity := Settings.DEFAULT_MOUSE_SENSITIVITY
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(-15.0)
var pitch_control_input := 0.0
var roll_control_input := 0.0


func setup(
	body_ref: CharacterBody3D,
	refs: Dictionary,
	controller_id := Settings.CHARACTER_FLIGHT,
	duplicate_collision_shape := true,
) -> void:
	body = body_ref
	settings_controller_id = controller_id
	collision_shape = refs.get("collision_shape") as CollisionShape3D
	body_mesh = refs.get("body_mesh") as MeshInstance3D
	camera_rig = refs.get("camera_rig") as Node3D
	camera = refs.get("camera") as Camera3D
	first_person_camera = refs.get("first_person_camera") as Camera3D
	spring_arm = refs.get("spring_arm") as SpringArm3D
	status_label = refs.get("status_label") as Label
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	camera_rig.top_level = true
	if first_person_camera != null:
		first_person_camera.top_level = true
	if duplicate_collision_shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	body_mesh.mesh = body_mesh.mesh.duplicate()
	spring_arm.add_excluded_object(get_rid())
	_apply_controller_settings()
	_refresh_max_lift_aoa_limits()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func process_tick(_delta: float) -> void:
	var forward_speed := velocity.dot(-global_basis.z)
	status_label.text = "Flight\nSpeed %.2f m/s\nAoA %.1f°\nSideslip %.1f°\nFlap CD %.2f s" % [
		forward_speed,
		aoa_deg,
		sideslip_deg,
		flap_cooldown_remaining,
	]


func physics_tick(delta: float) -> void:
	flap_cooldown_remaining = maxf(flap_cooldown_remaining - delta, 0.0)
	_collect_inputs(delta)
	_update_aero_angles()
	var total_force := _get_gravity_force() + _get_aerodynamic_force() + _get_extra_drag_force()
	velocity += (total_force / maxf(mass, 0.001)) * delta
	_apply_direct_rotation(delta)
	move_and_slide()
	var floor_normal := _apply_collision_response()
	if floor_normal != Vector3.ZERO:
		_apply_q3_floor_friction(delta, floor_normal)
	_apply_camera_rotation()


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(
			camera_pitch - (event.relative.y * mouse_sensitivity),
			deg_to_rad(-75.0),
			deg_to_rad(60.0),
		)
		_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	if camera_rig != null:
		camera_rig.global_position = global_position + (Vector3.UP * DEFAULT_CAMERA_HEIGHT)
		camera_rig.global_rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	if first_person_camera != null:
		var first_person_position := global_position
		if collision_shape != null:
			first_person_position = collision_shape.global_position
		first_person_camera.global_position = first_person_position
		first_person_camera.global_rotation = Vector3(camera_pitch, camera_yaw, 0.0)


func place_at_view(view_transform: Transform3D) -> void:
	transform = Transform3D(view_transform.basis.orthonormalized(), view_transform.origin)
	var view_euler := view_transform.basis.get_euler()
	camera_yaw = view_euler.y
	camera_pitch = view_euler.x
	velocity = -transform.basis.z * 12.0
	_apply_camera_rotation()


func get_view_camera() -> Camera3D:
	return _get_active_camera()


func on_settings_changed() -> void:
	_apply_controller_settings()


func set_view_active(active: bool) -> void:
	view_active = active
	_apply_visual_state()


func _collect_inputs(delta: float) -> void:
	if camera_fly_by_wire_enabled:
		_update_camera_fly_by_wire_inputs(delta)
	else:
		pitch_control_input = Input.get_action_strength("player_back") - Input.get_action_strength("player_forward")
		roll_control_input = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
	if Input.is_action_just_pressed("player_jump"):
		_try_flap_impulse()


func _update_aero_angles() -> void:
	var air_velocity_local := global_basis.orthonormalized().transposed() * velocity
	var flow_forward := -air_velocity_local.z
	var flow_up := air_velocity_local.y
	var flow_right := air_velocity_local.x
	var forward_plane_speed := maxf(sqrt(flow_forward * flow_forward + flow_up * flow_up), 0.0001)
	aoa_deg = rad_to_deg(-atan2(flow_up, flow_forward))
	sideslip_deg = rad_to_deg(atan2(flow_right, forward_plane_speed))


func _get_gravity_force() -> Vector3:
	var gravity_direction: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var gravity_magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	return gravity_direction * gravity_magnitude * gravity_scale * mass


func _try_flap_impulse() -> void:
	if flap_cooldown_remaining > 0.0 or flap_impulse_strength <= 0.0:
		return
	velocity += _get_flap_impulse_axis() * flap_impulse_strength
	flap_cooldown_remaining = maxf(flap_cooldown, 0.0)


func _get_flap_impulse_axis() -> Vector3:
	var forward_axis := (-global_basis.z).normalized()
	var up_axis := global_basis.y.normalized()
	var angle: float = clampf(flap_impulse_angle_rad, 0.0, PI * 0.5)
	return ((forward_axis * cos(angle)) + (up_axis * sin(angle))).normalized()


func _get_aerodynamic_force() -> Vector3:
	var speed_squared := velocity.length_squared()
	if speed_squared < MIN_AERODYNAMIC_SPEED_SQUARED:
		return Vector3.ZERO
	var air_speed := sqrt(speed_squared)
	var airflow_direction := velocity / air_speed
	var dynamic_pressure := 0.5 * DEFAULT_AIR_DENSITY * speed_squared
	var lift_coefficient := _sample_table(DEFAULT_LIFT_TABLE, aoa_deg)
	var drag_coefficient := maxf(_sample_table(DEFAULT_DRAG_TABLE, aoa_deg), 0.0)
	var drag_force := -airflow_direction * dynamic_pressure * reference_area * drag_coefficient
	# Lift acts perpendicular to the relative wind (in the body's symmetry plane),
	# not along body up. Body-up lift would be tilted back by the angle of attack,
	# adding an along-flightpath retarding component that double-counts the induced
	# drag already baked into DEFAULT_DRAG_TABLE (the sideslip compensation keeps
	# the right axis square to the wind, so this stays in-plane). Fall back to body
	# up only if the wind runs along the right axis (degenerate cross product).
	var lift_axis := global_basis.x.cross(airflow_direction)
	if lift_axis.length_squared() < MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		lift_axis = global_basis.y
	lift_axis = lift_axis.normalized()
	var lift_force := lift_axis * dynamic_pressure * reference_area * lift_coefficient
	return drag_force + lift_force


func _get_extra_drag_force() -> Vector3:
	var speed_squared := velocity.length_squared()
	if speed_squared < MIN_AERODYNAMIC_SPEED_SQUARED:
		return Vector3.ZERO
	var air_speed := sqrt(speed_squared)
	var direction := velocity / air_speed
	var linear_component := DEFAULT_EXTRA_LINEAR_DRAG_LINEAR_COEFFICIENT * air_speed
	var quadratic_component := extra_linear_drag_quadratic_coefficient * speed_squared
	return -direction * reference_area * (linear_component + quadratic_component)


func _update_camera_fly_by_wire_inputs(delta: float) -> void:
	_update_fly_by_wire_inputs_for_target(delta, _get_camera_target_point())


func _get_camera_target_point() -> Vector3:
	var active_camera := _get_active_camera()
	if active_camera == null:
		return global_position + (-global_basis.z * camera_fly_by_wire_target_distance)
	var origin := active_camera.global_position
	var direction := (-active_camera.global_basis.z).normalized()
	var fallback := origin + direction * maxf(camera_fly_by_wire_target_distance, 1.0)
	var world := get_world_3d()
	if world == null:
		return fallback
	var query := PhysicsRayQueryParameters3D.create(origin, fallback)
	query.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	return hit.get("position", fallback) as Vector3


func _update_fly_by_wire_inputs_for_target(delta: float, target_point: Vector3) -> void:
	var frame_basis := global_basis.orthonormalized()
	var direction := _get_safe_world_direction(target_point - global_position, -frame_basis.z)
	var local_direction := frame_basis.transposed() * direction
	var turn_angle := _get_local_turn_angle(local_direction)
	var roll_target := _get_wings_level_roll_target(frame_basis)
	var pitch_target := 0.0
	if _get_world_horizontal_turn_angle(direction, -frame_basis.z) <= camera_fly_by_wire_pitch_window_rad:
		pitch_target = _get_nearest_pitch_target(local_direction)
	elif turn_angle > FBW_TURN_ANGLE_DEADBAND_RAD:
		roll_target = _get_lift_vector_roll_target(local_direction, turn_angle, frame_basis)
		pitch_target = _get_lift_aligned_pitch_target(turn_angle, local_direction)
	_move_fly_by_wire_inputs(delta, roll_target, pitch_target)


func _get_safe_world_direction(direction: Vector3, fallback: Vector3) -> Vector3:
	if direction.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		return fallback.normalized()
	return direction.normalized()


func _get_local_turn_angle(local_direction: Vector3) -> float:
	var forward_alignment := clampf(-local_direction.z, -1.0, 1.0)
	return acos(forward_alignment)


func _get_world_horizontal_turn_angle(direction: Vector3, forward: Vector3) -> float:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	if (
		flat_direction.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED
		or flat_forward.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED
	):
		return 0.0
	return flat_forward.normalized().angle_to(flat_direction.normalized())


func _get_lift_vector_roll_target(local_direction: Vector3, turn_angle: float, frame_basis: Basis) -> float:
	var transverse_length_squared := local_direction.x * local_direction.x + local_direction.y * local_direction.y
	if transverse_length_squared <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		return _get_wings_level_roll_target(frame_basis)

	var lift_vector_error := atan2(local_direction.x, local_direction.y)
	var turn_ratio := clampf(turn_angle / FBW_TURN_FULL_PULL_ANGLE_RAD, 0.0, 1.0)
	var lift_vector_roll := _get_roll_input_for_error(lift_vector_error, FBW_LEVEL_TURN_ROLL_GAIN, turn_ratio)
	var rollout := 1.0 - clampf(turn_angle / FBW_TURN_ROLLOUT_ANGLE_RAD, 0.0, 1.0)
	if rollout <= 0.0:
		return lift_vector_roll
	return lerpf(lift_vector_roll, _get_wings_level_roll_target(frame_basis), rollout)


func _get_wings_level_roll_target(frame_basis: Basis) -> float:
	var local_world_up := frame_basis.transposed() * Vector3.UP
	var bank_error := atan2(local_world_up.x, local_world_up.y)
	if absf(bank_error) <= FBW_WINGS_LEVEL_DEADBAND_RAD:
		return 0.0
	return _get_roll_input_for_error(bank_error, FBW_WINGS_LEVEL_ROLL_GAIN)


func _get_roll_input_for_error(roll_error: float, angle_to_rate_gain: float, rate_scale := 1.0) -> float:
	var desired_rate := clampf(
		roll_error * angle_to_rate_gain * clampf(rate_scale, 0.0, 1.0),
		-FBW_ROLL_MAX_DESIRED_RATE,
		FBW_ROLL_MAX_DESIRED_RATE
	)
	return clampf(desired_rate / maxf(roll_rate_rad, 0.001), -1.0, 1.0)


func _get_lift_aligned_pitch_target(turn_angle: float, local_direction: Vector3) -> float:
	var pitch_target := _get_turn_pull_pitch_target(turn_angle)
	var lift_alignment := _get_lift_alignment_factor(local_direction)
	var curved_alignment := lift_alignment * lift_alignment
	var pitch_scale := lerpf(FBW_TURN_MIN_UNALIGNED_PULL_RATIO, 1.0, curved_alignment)
	return pitch_target * pitch_scale


func _get_lift_alignment_factor(local_direction: Vector3) -> float:
	var transverse_length := sqrt(local_direction.x * local_direction.x + local_direction.y * local_direction.y)
	if transverse_length <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		return 1.0
	return clampf(local_direction.y / transverse_length, 0.0, 1.0)


func _get_nearest_pitch_target(local_direction: Vector3) -> float:
	var pitch_angle := atan2(local_direction.y, -local_direction.z)
	if absf(pitch_angle) <= FBW_TURN_MIN_PULL_ANGLE_RAD:
		return 0.0
	var desired_rate := clampf(
		pitch_angle * FBW_TURN_PITCH_ANGLE_TO_RATE_GAIN,
		-FBW_TURN_MAX_DESIRED_PITCH_RATE,
		FBW_TURN_MAX_DESIRED_PITCH_RATE
	)
	return clampf(desired_rate / maxf(pitch_rate_rad, 0.001), -1.0, 1.0)


func _get_turn_pull_pitch_target(turn_angle: float) -> float:
	if turn_angle <= FBW_TURN_MIN_PULL_ANGLE_RAD:
		return 0.0
	var desired_rate := clampf(
		turn_angle * FBW_TURN_PITCH_ANGLE_TO_RATE_GAIN,
		-FBW_TURN_MAX_DESIRED_PITCH_RATE,
		FBW_TURN_MAX_DESIRED_PITCH_RATE
	)
	return clampf(desired_rate / maxf(pitch_rate_rad, 0.001), -1.0, 1.0)


func _move_fly_by_wire_inputs(delta: float, roll_target: float, pitch_target: float) -> void:
	var pitch_step := maxf(FBW_DIRECTION_PITCH_RESPONSE_RATE * delta, 0.0)
	var roll_step := maxf(FBW_LEVEL_TURN_ROLL_RESPONSE_RATE * delta, pitch_step)
	pitch_control_input = move_toward(pitch_control_input, clampf(pitch_target, -1.0, 1.0), pitch_step)
	roll_control_input = move_toward(roll_control_input, clampf(roll_target, -1.0, 1.0), roll_step)


func _apply_direct_rotation(delta := 0.0) -> void:
	if delta > 0.0:
		var frame_basis := global_basis.orthonormalized()
		var pitch_delta := _get_aoa_limited_pitch_delta(pitch_control_input * pitch_rate_rad * delta)
		var roll_delta := roll_control_input * roll_rate_rad * delta
		var body_rotation := Basis.IDENTITY
		if not is_zero_approx(pitch_delta):
			body_rotation = Basis(frame_basis.x.normalized(), pitch_delta) * body_rotation
		if not is_zero_approx(roll_delta):
			body_rotation = Basis((-frame_basis.z).normalized(), roll_delta) * body_rotation
		if body_rotation != Basis.IDENTITY:
			global_basis = (body_rotation * frame_basis).orthonormalized()

	_apply_sideslip_compensation()


func _apply_sideslip_compensation() -> void:
	if not sideslip_compensation_enabled:
		return
	var axial := velocity.dot(-global_basis.z)
	var lateral := velocity.dot(global_basis.x)
	if axial * axial + lateral * lateral <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		return
	var skid := atan2(lateral, axial)
	if is_zero_approx(skid):
		return
	var correction: float = clampf(
		-skid,
		-sideslip_compensation_max_yaw_rad,
		sideslip_compensation_max_yaw_rad,
	)
	if is_zero_approx(correction):
		return
	global_basis = (Basis(global_basis.y, correction) * global_basis).orthonormalized()


func _get_aoa_limited_pitch_delta(requested_delta: float) -> float:
	var air_speed := velocity.length()
	if air_speed < MAX_LIFT_AOA_MIN_AIRSPEED:
		return requested_delta

	var current_aoa := deg_to_rad(aoa_deg)
	var limited_aoa := clampf(
		current_aoa + requested_delta,
		deg_to_rad(_negative_max_lift_aoa_deg),
		deg_to_rad(_positive_max_lift_aoa_deg)
	)
	return limited_aoa - current_aoa


func _apply_collision_response() -> Vector3:
	var floor_normal := Vector3.ZERO
	for collision_index in mini(get_slide_collision_count(), MAX_COLLISION_SLIDES):
		var normal := get_slide_collision(collision_index).get_normal()
		if normal.y >= FLOOR_NORMAL_Y:
			floor_normal = normal
		if velocity.dot(normal) < 0.0:
			velocity = _clip_velocity(velocity, normal, COLLISION_OVERBOUNCE)
	return floor_normal


func _apply_q3_floor_friction(delta: float, floor_normal: Vector3) -> void:
	var tangent_velocity := velocity.slide(floor_normal)
	var speed := tangent_velocity.length()
	if speed <= 0.0:
		return
	var drop := maxf(speed, Q3_FLOOR_STOP_SPEED) * Q3_FLOOR_FRICTION * delta
	var new_speed := maxf(speed - drop, 0.0)
	var normal_velocity := velocity - tangent_velocity
	velocity = normal_velocity + (tangent_velocity * (new_speed / speed))


func _clip_velocity(input_velocity: Vector3, plane_normal: Vector3, overbounce: float) -> Vector3:
	var backoff := input_velocity.dot(plane_normal)
	if backoff < 0.0:
		backoff *= overbounce
	else:
		backoff /= overbounce
	return input_velocity - (plane_normal * backoff)


func _sample_table(points: Array[Vector2], x_value: float) -> float:
	if points.is_empty():
		return 0.0
	if x_value <= points[0].x:
		return points[0].y
	var last_index := points.size() - 1
	if x_value >= points[last_index].x:
		return points[last_index].y
	for index in last_index:
		var left := points[index]
		var right := points[index + 1]
		if x_value <= right.x:
			var span := right.x - left.x
			if is_zero_approx(span):
				return right.y
			return lerpf(left.y, right.y, (x_value - left.x) / span)
	return points[last_index].y


func _refresh_max_lift_aoa_limits() -> void:
	var positive_found := false
	var negative_found := false
	var positive_best_coefficient := 0.0
	var negative_best_coefficient := 0.0
	var positive_limit := 15.0
	var negative_limit := -15.0

	for point in DEFAULT_LIFT_TABLE:
		if point.x > 0.0 and (not positive_found or point.y > positive_best_coefficient):
			positive_found = true
			positive_best_coefficient = point.y
			positive_limit = point.x

		if point.x < 0.0 and (not negative_found or point.y < negative_best_coefficient):
			negative_found = true
			negative_best_coefficient = point.y
			negative_limit = point.x

	if positive_found:
		_positive_max_lift_aoa_deg = positive_limit
	else:
		_positive_max_lift_aoa_deg = absf(negative_limit)

	if negative_found:
		_negative_max_lift_aoa_deg = negative_limit
	else:
		_negative_max_lift_aoa_deg = -absf(positive_limit)


func _apply_controller_settings() -> void:
	var camera_fov := Settings.get_controller_setting("fov", settings_controller_id)
	camera.fov = camera_fov
	if first_person_camera != null:
		first_person_camera.fov = camera_fov
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", settings_controller_id)
	spring_arm.spring_length = Settings.get_controller_setting("camera_distance", settings_controller_id)
	first_person_enabled = Settings.get_controller_setting("first_person", settings_controller_id) >= 0.5
	gravity_scale = Settings.get_controller_setting("gravity_scale", settings_controller_id)
	mass = Settings.get_controller_setting("mass", settings_controller_id)
	flap_impulse_strength = Settings.get_controller_setting("flap_impulse_strength", settings_controller_id)
	flap_impulse_angle_rad = deg_to_rad(Settings.get_controller_setting("flap_impulse_angle", settings_controller_id))
	flap_cooldown = Settings.get_controller_setting("flap_cooldown", settings_controller_id)
	flap_cooldown_remaining = minf(flap_cooldown_remaining, flap_cooldown)
	camera_fly_by_wire_enabled = Settings.get_controller_setting("camera_fly_by_wire", settings_controller_id) >= 0.5
	camera_fly_by_wire_target_distance = Settings.get_controller_setting("camera_fly_by_wire_target_distance", settings_controller_id)
	camera_fly_by_wire_pitch_window_rad = deg_to_rad(Settings.get_controller_setting("camera_fly_by_wire_pitch_window", settings_controller_id))
	sideslip_compensation_enabled = Settings.get_controller_setting("sideslip_compensation", settings_controller_id) >= 0.5
	sideslip_compensation_max_yaw_rad = deg_to_rad(Settings.get_controller_setting("sideslip_compensation_max_yaw", settings_controller_id))
	reference_area = Settings.get_controller_setting("reference_area", settings_controller_id)
	extra_linear_drag_quadratic_coefficient = Settings.get_controller_setting("extra_linear_drag_quadratic_coefficient", settings_controller_id)
	_apply_visual_state()


func _get_active_camera() -> Camera3D:
	if first_person_enabled and first_person_camera != null:
		return first_person_camera
	return camera


func _apply_visual_state() -> void:
	if camera != null:
		camera.current = view_active and not first_person_enabled
	if first_person_camera != null:
		first_person_camera.current = view_active and first_person_enabled
	if body_mesh != null:
		body_mesh.visible = view_active and not first_person_enabled

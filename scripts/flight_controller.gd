class_name FlightController
extends CharacterBody3D

const DEFAULT_CAMERA_DISTANCE := 5.0
const DEFAULT_GRAVITY_SCALE := 0.15
const DEFAULT_MASS := 4.0
const DEFAULT_FLAP_IMPULSE_STRENGTH := 4.7
const DEFAULT_FLAP_IMPULSE_ANGLE_DEGREES := 45.0
const DEFAULT_FLAP_COOLDOWN := 0.5
const DEFAULT_MAX_BANK_ANGLE_DEGREES := 45.0
const DEFAULT_SIDESLIP_COMPENSATION_ENABLED := 1.0
const DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES := 0.1
const Q3_FLOOR_FRICTION := 6.0
const Q3_FLOOR_STOP_SPEED := 3.81
const FLOOR_NORMAL_Y := 0.7
const HIGH_BANK_AOA_ALIGNMENT_START_RAD := PI / 3.0
const DEFAULT_REFERENCE_AREA := 0.275
const DEFAULT_EXTRA_LINEAR_DRAG_LINEAR_COEFFICIENT := 0.0
const DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT := 0.015
const DEFAULT_AIR_DENSITY := 1.225
const MAX_LIFT_AOA_MIN_AIRSPEED := 5.0
const MIN_AERODYNAMIC_SPEED_SQUARED := 0.0001
const MIN_DIRECTION_VECTOR_LENGTH_SQUARED := 0.000001
const MIN_HEADING_SPEED_SQUARED := 1.0
const COLLISION_OVERBOUNCE := 1.001
const MAX_COLLISION_SLIDES := 4
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
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var status_label: Label = $HUD/StatusLabel

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
var max_bank_angle_rad := deg_to_rad(DEFAULT_MAX_BANK_ANGLE_DEGREES)
var sideslip_compensation_enabled := DEFAULT_SIDESLIP_COMPENSATION_ENABLED >= 0.5
var sideslip_compensation_max_yaw_rad := deg_to_rad(DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES)
var mouse_sensitivity := Settings.DEFAULT_MOUSE_SENSITIVITY
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(-15.0)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	camera_rig.top_level = true
	collision_shape.shape = collision_shape.shape.duplicate()
	body_mesh.mesh = body_mesh.mesh.duplicate()
	spring_arm.add_excluded_object(get_rid())
	_apply_controller_settings()
	_refresh_max_lift_aoa_limits()
	Settings.settings_changed.connect(on_settings_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var forward_speed := velocity.dot(-global_basis.z)
	status_label.text = "Flight\nSpeed %.2f m/s\nAoA %.1f°\nSideslip %.1f°\nFlap CD %.2f s" % [
		forward_speed,
		aoa_deg,
		sideslip_deg,
		flap_cooldown_remaining,
	]


func _physics_process(delta: float) -> void:
	flap_cooldown_remaining = maxf(flap_cooldown_remaining - delta, 0.0)
	_collect_inputs()
	_update_aero_angles()
	var total_force := _get_gravity_force() + _get_aerodynamic_force() + _get_extra_drag_force()
	velocity += (total_force / maxf(mass, 0.001)) * delta
	_apply_direct_rotation()
	move_and_slide()
	var floor_normal := _apply_collision_response()
	if floor_normal != Vector3.ZERO:
		_apply_q3_floor_friction(delta, floor_normal)
	_apply_camera_rotation()


func _input(event: InputEvent) -> void:
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
		camera_rig.global_position = global_position
		camera_rig.global_rotation = Vector3(camera_pitch, camera_yaw, 0.0)


func place_at_view(view_transform: Transform3D) -> void:
	transform = Transform3D(view_transform.basis.orthonormalized(), view_transform.origin)
	var view_euler := view_transform.basis.get_euler()
	camera_yaw = view_euler.y
	camera_pitch = view_euler.x
	velocity = -transform.basis.z * 12.0
	_apply_camera_rotation()


func get_view_camera() -> Camera3D:
	return camera


func on_settings_changed() -> void:
	_apply_controller_settings()


func _collect_inputs() -> void:
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


func _apply_direct_rotation() -> void:
	# Weathervane the heading onto the flight path: the nose follows the
	# horizontal velocity. A bank tilts the lift vector (see _get_aerodynamic_force)
	# and curves this velocity sideways — and because the heading tracks it, the
	# aircraft turns. Seeding the heading from the body's own -Z instead (the old
	# behaviour) froze the yaw: the bank still tilted lift and built sideslip, but
	# the nose never came round, so it never turned. Fall back to the current
	# facing when there is no usable horizontal airspeed (hover or vertical dive).
	var heading_forward := velocity
	heading_forward.y = 0.0
	if heading_forward.length_squared() <= MIN_HEADING_SPEED_SQUARED:
		heading_forward = -global_basis.z
		heading_forward.y = 0.0
	if heading_forward.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		heading_forward = Vector3.FORWARD
	else:
		heading_forward = heading_forward.normalized()

	var camera_forward := -camera.global_basis.z
	var camera_flat_forward := Vector3(camera_forward.x, 0.0, camera_forward.z)
	var yaw_error := 0.0
	if camera_flat_forward.length_squared() > MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		camera_flat_forward = camera_flat_forward.normalized()
		yaw_error = atan2(
			heading_forward.cross(camera_flat_forward).dot(Vector3.UP),
			heading_forward.dot(camera_flat_forward)
		)

	var target_bank_angle := clampf(-yaw_error, -max_bank_angle_rad, max_bank_angle_rad)
	var target_aoa := _get_bank_scaled_aoa(_get_max_lift_limited_aoa(), target_bank_angle)
	if absf(target_bank_angle) < HIGH_BANK_AOA_ALIGNMENT_START_RAD:
		var target_forward := (heading_forward * cos(target_aoa) + Vector3.UP * sin(target_aoa)).normalized()
		var target_right := target_forward.cross(Vector3.UP)
		if target_right.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
			target_right = global_basis.x
		else:
			target_right = target_right.normalized()
		var target_up := target_right.cross(target_forward).normalized()
		target_right = Basis(target_forward, target_bank_angle) * target_right
		target_up = Basis(target_forward, target_bank_angle) * target_up
		global_basis = Basis(target_right, target_up, -target_forward).orthonormalized()
	else:
		var air_speed := velocity.length()
		var airflow_direction := -global_basis.z
		if air_speed > sqrt(MIN_AERODYNAMIC_SPEED_SQUARED):
			airflow_direction = velocity / air_speed
		var target_right := airflow_direction.cross(Vector3.UP)
		if target_right.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
			target_right = global_basis.x
		else:
			target_right = target_right.normalized()
		var target_up := target_right.cross(airflow_direction).normalized()
		target_right = Basis(airflow_direction, target_bank_angle) * target_right
		target_up = Basis(airflow_direction, target_bank_angle) * target_up
		var aoa_rotation := Basis(target_right, target_aoa)
		var target_forward := aoa_rotation * airflow_direction
		target_up = aoa_rotation * target_up
		global_basis = Basis(target_right, target_up, -target_forward).orthonormalized()

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


func _get_max_lift_limited_aoa() -> float:
	var air_speed := velocity.length()
	if air_speed < MAX_LIFT_AOA_MIN_AIRSPEED:
		return camera_pitch

	return deg_to_rad(clampf(
		rad_to_deg(camera_pitch),
		_negative_max_lift_aoa_deg,
		_positive_max_lift_aoa_deg,
	))


func _get_bank_scaled_aoa(target_aoa: float, target_bank_angle: float) -> float:
	if target_aoa >= 0.0 or max_bank_angle_rad <= 0.0:
		return target_aoa
	var bank_fraction: float = clampf(absf(target_bank_angle) / max_bank_angle_rad, 0.0, 1.0)
	return target_aoa * (1.0 - bank_fraction)


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
	camera.fov = Settings.get_controller_setting("fov", Settings.CHARACTER_FLIGHT)
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", Settings.CHARACTER_FLIGHT)
	spring_arm.spring_length = Settings.get_controller_setting("camera_distance", Settings.CHARACTER_FLIGHT)
	gravity_scale = Settings.get_controller_setting("gravity_scale", Settings.CHARACTER_FLIGHT)
	mass = Settings.get_controller_setting("mass", Settings.CHARACTER_FLIGHT)
	flap_impulse_strength = Settings.get_controller_setting("flap_impulse_strength", Settings.CHARACTER_FLIGHT)
	flap_impulse_angle_rad = deg_to_rad(Settings.get_controller_setting("flap_impulse_angle", Settings.CHARACTER_FLIGHT))
	flap_cooldown = Settings.get_controller_setting("flap_cooldown", Settings.CHARACTER_FLIGHT)
	flap_cooldown_remaining = minf(flap_cooldown_remaining, flap_cooldown)
	max_bank_angle_rad = deg_to_rad(Settings.get_controller_setting("max_bank_angle", Settings.CHARACTER_FLIGHT))
	sideslip_compensation_enabled = Settings.get_controller_setting("sideslip_compensation", Settings.CHARACTER_FLIGHT) >= 0.5
	sideslip_compensation_max_yaw_rad = deg_to_rad(Settings.get_controller_setting("sideslip_compensation_max_yaw", Settings.CHARACTER_FLIGHT))
	reference_area = Settings.get_controller_setting("reference_area", Settings.CHARACTER_FLIGHT)
	extra_linear_drag_quadratic_coefficient = Settings.get_controller_setting("extra_linear_drag_quadratic_coefficient", Settings.CHARACTER_FLIGHT)

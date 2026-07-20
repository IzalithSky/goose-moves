class_name FlightController
extends CharacterBody3D

const DEFAULT_CAMERA_DISTANCE := 5.0
const DEFAULT_GRAVITY_SCALE := 0.15
const DEFAULT_MASS := 4.0
const DEFAULT_MAX_THRUST := 18.8
const DEFAULT_FLAP_DURATION := 1.0
const Q3_FLOOR_FRICTION := 6.0
const Q3_FLOOR_STOP_SPEED := 3.81
const FLOOR_NORMAL_Y := 0.7
const CAMERA_ROLL_MAX_BANK_RAD := PI * 0.25
const DEFAULT_REFERENCE_AREA := 0.275
const DEFAULT_EXTRA_LINEAR_DRAG_LINEAR_COEFFICIENT := 0.0
const DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT := 0.015
const DEFAULT_AIR_DENSITY := 1.225
const MIN_AERODYNAMIC_SPEED_SQUARED := 0.0001
const MIN_DIRECTION_VECTOR_LENGTH_SQUARED := 0.000001
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
const DEFAULT_THRUST_TABLE: Array[Vector2] = [
	Vector2(0.0, 1.0),
	Vector2(28.6281185150146, 0.904809594154358),
	Vector2(45.6349220275879, 0.8567134141922),
	Vector2(61.5079383850098, 0.802605211734772),
	Vector2(79.3650817871094, 0.754509031772614),
	Vector2(103.741493225098, 0.679358720779419),
	Vector2(132.653060913086, 0.583166360855103),
	Vector2(163.548751831055, 0.498997986316681),
	Vector2(210.03401184082, 0.381763517856598),
	Vector2(390.306121826172, 0.0420841686427593),
]

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var status_label: Label = $HUD/StatusLabel

var flap_time_remaining := 0.0
var aoa_deg := 0.0
var sideslip_deg := 0.0
var mass := DEFAULT_MASS
var max_thrust := DEFAULT_MAX_THRUST
var reference_area := DEFAULT_REFERENCE_AREA
var gravity_scale := DEFAULT_GRAVITY_SCALE
var extra_linear_drag_quadratic_coefficient := DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT
var flap_duration := DEFAULT_FLAP_DURATION
var mouse_sensitivity := Settings.DEFAULT_MOUSE_SENSITIVITY
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(-15.0)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	camera_rig.top_level = true
	collision_shape.shape = collision_shape.shape.duplicate()
	body_mesh.mesh = body_mesh.mesh.duplicate()
	_apply_controller_settings()
	Settings.settings_changed.connect(on_settings_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var forward_speed := velocity.dot(-global_basis.z)
	status_label.text = "Flight\nSpeed %.2f m/s\nAoA %.1f°\nSideslip %.1f°\nFlap %.2f s" % [
		forward_speed,
		aoa_deg,
		sideslip_deg,
		flap_time_remaining,
	]


func _physics_process(delta: float) -> void:
	_collect_inputs()
	flap_time_remaining = maxf(flap_time_remaining - delta, 0.0)
	_update_aero_angles()
	var total_force := _get_gravity_force() + _get_thrust_force() + _get_aerodynamic_force() + _get_extra_drag_force()
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
		flap_time_remaining = maxf(flap_duration, 0.0)


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


func _get_thrust_force() -> Vector3:
	if flap_time_remaining <= 0.0:
		return Vector3.ZERO
	var forward_axis := (-global_basis.z).normalized()
	var up_axis := global_basis.y.normalized()
	var flap_axis := (forward_axis + up_axis).normalized()
	var forward_speed := absf(velocity.dot(forward_axis))
	var thrust_scale := maxf(_sample_table(DEFAULT_THRUST_TABLE, forward_speed), 0.0)
	return flap_axis * max_thrust * thrust_scale


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
	var lift_axis := global_basis.y.normalized()
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
	var heading_forward := -global_basis.z
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

	var target_bank_angle := clampf(-yaw_error * 0.5, -CAMERA_ROLL_MAX_BANK_RAD, CAMERA_ROLL_MAX_BANK_RAD)
	var target_forward := (heading_forward * cos(camera_pitch) + Vector3.UP * sin(camera_pitch)).normalized()
	var target_right := target_forward.cross(Vector3.UP)
	if target_right.length_squared() <= MIN_DIRECTION_VECTOR_LENGTH_SQUARED:
		target_right = global_basis.x
	else:
		target_right = target_right.normalized()
	var target_up := target_right.cross(target_forward).normalized()
	target_right = Basis(target_forward, target_bank_angle) * target_right
	target_up = Basis(target_forward, target_bank_angle) * target_up
	global_basis = Basis(target_right, target_up, -target_forward).orthonormalized()


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


func _apply_controller_settings() -> void:
	camera.fov = Settings.get_controller_setting("fov", Settings.CHARACTER_FLIGHT)
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", Settings.CHARACTER_FLIGHT)
	spring_arm.spring_length = Settings.get_controller_setting("camera_distance", Settings.CHARACTER_FLIGHT)
	gravity_scale = Settings.get_controller_setting("gravity_scale", Settings.CHARACTER_FLIGHT)
	mass = Settings.get_controller_setting("mass", Settings.CHARACTER_FLIGHT)
	max_thrust = Settings.get_controller_setting("max_thrust", Settings.CHARACTER_FLIGHT)
	flap_duration = Settings.get_controller_setting("flap_duration", Settings.CHARACTER_FLIGHT)
	reference_area = Settings.get_controller_setting("reference_area", Settings.CHARACTER_FLIGHT)
	extra_linear_drag_quadratic_coefficient = Settings.get_controller_setting("extra_linear_drag_quadratic_coefficient", Settings.CHARACTER_FLIGHT)

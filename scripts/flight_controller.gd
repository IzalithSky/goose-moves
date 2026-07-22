class_name FlightController
extends CharacterBody3D

const FLIGHT_MOVEMENT_MOTOR := preload("res://scripts/flight_movement_motor.gd")
const DEFAULT_CAMERA_DISTANCE := FLIGHT_MOVEMENT_MOTOR.DEFAULT_CAMERA_DISTANCE
const DEFAULT_CAMERA_HEIGHT := FLIGHT_MOVEMENT_MOTOR.DEFAULT_CAMERA_HEIGHT
const DEFAULT_GRAVITY_SCALE := FLIGHT_MOVEMENT_MOTOR.DEFAULT_GRAVITY_SCALE
const DEFAULT_MASS := FLIGHT_MOVEMENT_MOTOR.DEFAULT_MASS
const DEFAULT_FLAP_IMPULSE_STRENGTH := FLIGHT_MOVEMENT_MOTOR.DEFAULT_FLAP_IMPULSE_STRENGTH
const DEFAULT_FLAP_IMPULSE_ANGLE_DEGREES := FLIGHT_MOVEMENT_MOTOR.DEFAULT_FLAP_IMPULSE_ANGLE_DEGREES
const DEFAULT_FLAP_COOLDOWN := FLIGHT_MOVEMENT_MOTOR.DEFAULT_FLAP_COOLDOWN
const DEFAULT_PITCH_RATE_DEGREES_PER_SECOND := FLIGHT_MOVEMENT_MOTOR.DEFAULT_PITCH_RATE_DEGREES_PER_SECOND
const DEFAULT_ROLL_RATE_DEGREES_PER_SECOND := FLIGHT_MOVEMENT_MOTOR.DEFAULT_ROLL_RATE_DEGREES_PER_SECOND
const DEFAULT_FIRST_PERSON_ENABLED := FLIGHT_MOVEMENT_MOTOR.DEFAULT_FIRST_PERSON_ENABLED
const DEFAULT_CAMERA_FLY_BY_WIRE_ENABLED := FLIGHT_MOVEMENT_MOTOR.DEFAULT_CAMERA_FLY_BY_WIRE_ENABLED
const DEFAULT_CAMERA_FLY_BY_WIRE_TARGET_DISTANCE := FLIGHT_MOVEMENT_MOTOR.DEFAULT_CAMERA_FLY_BY_WIRE_TARGET_DISTANCE
const DEFAULT_CAMERA_FLY_BY_WIRE_PITCH_WINDOW_DEGREES := FLIGHT_MOVEMENT_MOTOR.DEFAULT_CAMERA_FLY_BY_WIRE_PITCH_WINDOW_DEGREES
const DEFAULT_SIDESLIP_COMPENSATION_ENABLED := FLIGHT_MOVEMENT_MOTOR.DEFAULT_SIDESLIP_COMPENSATION_ENABLED
const DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES := FLIGHT_MOVEMENT_MOTOR.DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES
const FBW_DIRECTION_PITCH_RESPONSE_RATE := FLIGHT_MOVEMENT_MOTOR.FBW_DIRECTION_PITCH_RESPONSE_RATE
const FBW_LEVEL_TURN_ROLL_RESPONSE_RATE := FLIGHT_MOVEMENT_MOTOR.FBW_LEVEL_TURN_ROLL_RESPONSE_RATE
const FBW_LEVEL_TURN_ROLL_GAIN := FLIGHT_MOVEMENT_MOTOR.FBW_LEVEL_TURN_ROLL_GAIN
const FBW_WINGS_LEVEL_ROLL_GAIN := FLIGHT_MOVEMENT_MOTOR.FBW_WINGS_LEVEL_ROLL_GAIN
const FBW_ROLL_MAX_DESIRED_RATE := FLIGHT_MOVEMENT_MOTOR.FBW_ROLL_MAX_DESIRED_RATE
const FBW_TURN_FULL_PULL_ANGLE_RAD := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_FULL_PULL_ANGLE_RAD
const FBW_TURN_ROLLOUT_ANGLE_RAD := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_ROLLOUT_ANGLE_RAD
const FBW_TURN_MIN_UNALIGNED_PULL_RATIO := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_MIN_UNALIGNED_PULL_RATIO
const FBW_TURN_PITCH_ANGLE_TO_RATE_GAIN := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_PITCH_ANGLE_TO_RATE_GAIN
const FBW_TURN_MAX_DESIRED_PITCH_RATE := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_MAX_DESIRED_PITCH_RATE
const FBW_TURN_MIN_PULL_ANGLE_RAD := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_MIN_PULL_ANGLE_RAD
const FBW_TURN_ANGLE_DEADBAND_RAD := FLIGHT_MOVEMENT_MOTOR.FBW_TURN_ANGLE_DEADBAND_RAD
const FBW_WINGS_LEVEL_DEADBAND_RAD := FLIGHT_MOVEMENT_MOTOR.FBW_WINGS_LEVEL_DEADBAND_RAD
const Q3_FLOOR_FRICTION := FLIGHT_MOVEMENT_MOTOR.Q3_FLOOR_FRICTION
const Q3_FLOOR_STOP_SPEED := FLIGHT_MOVEMENT_MOTOR.Q3_FLOOR_STOP_SPEED
const FLOOR_NORMAL_Y := FLIGHT_MOVEMENT_MOTOR.FLOOR_NORMAL_Y
const DEFAULT_REFERENCE_AREA := FLIGHT_MOVEMENT_MOTOR.DEFAULT_REFERENCE_AREA
const DEFAULT_EXTRA_LINEAR_DRAG_LINEAR_COEFFICIENT := FLIGHT_MOVEMENT_MOTOR.DEFAULT_EXTRA_LINEAR_DRAG_LINEAR_COEFFICIENT
const DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT := FLIGHT_MOVEMENT_MOTOR.DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT
const DEFAULT_AIR_DENSITY := FLIGHT_MOVEMENT_MOTOR.DEFAULT_AIR_DENSITY
const MAX_LIFT_AOA_MIN_AIRSPEED := FLIGHT_MOVEMENT_MOTOR.MAX_LIFT_AOA_MIN_AIRSPEED
const MIN_AERODYNAMIC_SPEED_SQUARED := FLIGHT_MOVEMENT_MOTOR.MIN_AERODYNAMIC_SPEED_SQUARED
const MIN_DIRECTION_VECTOR_LENGTH_SQUARED := FLIGHT_MOVEMENT_MOTOR.MIN_DIRECTION_VECTOR_LENGTH_SQUARED
const COLLISION_OVERBOUNCE := FLIGHT_MOVEMENT_MOTOR.COLLISION_OVERBOUNCE
const MAX_COLLISION_SLIDES := FLIGHT_MOVEMENT_MOTOR.MAX_COLLISION_SLIDES
const DEFAULT_LIFT_TABLE := FLIGHT_MOVEMENT_MOTOR.DEFAULT_LIFT_TABLE
const DEFAULT_DRAG_TABLE := FLIGHT_MOVEMENT_MOTOR.DEFAULT_DRAG_TABLE

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var status_label: Label = $HUD/StatusLabel

var motor := FLIGHT_MOVEMENT_MOTOR.new()
var _pending_view_transform := Transform3D.IDENTITY
var _has_pending_view_transform := false

var flap_cooldown_remaining:
	get:
		return motor.flap_cooldown_remaining
	set(value):
		motor.flap_cooldown_remaining = value

var aoa_deg:
	get:
		return motor.aoa_deg
	set(value):
		motor.aoa_deg = value

var sideslip_deg:
	get:
		return motor.sideslip_deg
	set(value):
		motor.sideslip_deg = value

@warning_ignore("unused_private_class_variable")
var _positive_max_lift_aoa_deg:
	get:
		return motor._positive_max_lift_aoa_deg
	set(value):
		motor._positive_max_lift_aoa_deg = value

@warning_ignore("unused_private_class_variable")
var _negative_max_lift_aoa_deg:
	get:
		return motor._negative_max_lift_aoa_deg
	set(value):
		motor._negative_max_lift_aoa_deg = value

var mass:
	get:
		return motor.mass
	set(value):
		motor.mass = value

var reference_area:
	get:
		return motor.reference_area
	set(value):
		motor.reference_area = value

var gravity_scale:
	get:
		return motor.gravity_scale
	set(value):
		motor.gravity_scale = value

var extra_linear_drag_quadratic_coefficient:
	get:
		return motor.extra_linear_drag_quadratic_coefficient
	set(value):
		motor.extra_linear_drag_quadratic_coefficient = value

var flap_impulse_strength:
	get:
		return motor.flap_impulse_strength
	set(value):
		motor.flap_impulse_strength = value

var flap_impulse_angle_rad:
	get:
		return motor.flap_impulse_angle_rad
	set(value):
		motor.flap_impulse_angle_rad = value

var flap_cooldown:
	get:
		return motor.flap_cooldown
	set(value):
		motor.flap_cooldown = value

var pitch_rate_rad:
	get:
		return motor.pitch_rate_rad
	set(value):
		motor.pitch_rate_rad = value

var roll_rate_rad:
	get:
		return motor.roll_rate_rad
	set(value):
		motor.roll_rate_rad = value

var first_person_enabled:
	get:
		return motor.first_person_enabled
	set(value):
		motor.first_person_enabled = value
		motor.set_view_active(true)

var camera_fly_by_wire_enabled:
	get:
		return motor.camera_fly_by_wire_enabled
	set(value):
		motor.camera_fly_by_wire_enabled = value

var camera_fly_by_wire_target_distance:
	get:
		return motor.camera_fly_by_wire_target_distance
	set(value):
		motor.camera_fly_by_wire_target_distance = value

var camera_fly_by_wire_pitch_window_rad:
	get:
		return motor.camera_fly_by_wire_pitch_window_rad
	set(value):
		motor.camera_fly_by_wire_pitch_window_rad = value

var sideslip_compensation_enabled:
	get:
		return motor.sideslip_compensation_enabled
	set(value):
		motor.sideslip_compensation_enabled = value

var sideslip_compensation_max_yaw_rad:
	get:
		return motor.sideslip_compensation_max_yaw_rad
	set(value):
		motor.sideslip_compensation_max_yaw_rad = value

var mouse_sensitivity:
	get:
		return motor.mouse_sensitivity
	set(value):
		motor.mouse_sensitivity = value

var camera_yaw:
	get:
		return motor.camera_yaw
	set(value):
		motor.camera_yaw = value

var camera_pitch:
	get:
		return motor.camera_pitch
	set(value):
		motor.camera_pitch = value

var pitch_control_input:
	get:
		return motor.pitch_control_input
	set(value):
		motor.pitch_control_input = value

var roll_control_input:
	get:
		return motor.roll_control_input
	set(value):
		motor.roll_control_input = value


func _ready() -> void:
	motor.setup(self, {
		"collision_shape": collision_shape,
		"body_mesh": body_mesh,
		"camera_rig": camera_rig,
		"camera": camera,
		"first_person_camera": first_person_camera,
		"spring_arm": spring_arm,
		"status_label": status_label,
	}, Settings.CHARACTER_FLIGHT)
	if _has_pending_view_transform:
		motor.place_at_view(_pending_view_transform)
		_has_pending_view_transform = false
	Settings.settings_changed.connect(on_settings_changed)


func _process(delta: float) -> void:
	motor.process_tick(delta)


func _physics_process(delta: float) -> void:
	motor.physics_tick(delta)


func _input(event: InputEvent) -> void:
	motor.handle_input(event)


func on_settings_changed() -> void:
	motor.on_settings_changed()


func _apply_camera_rotation() -> void:
	motor._apply_camera_rotation()

func place_at_view(view_transform: Transform3D) -> void:
	_pending_view_transform = view_transform
	_has_pending_view_transform = true
	if motor.body == null:
		transform = Transform3D(view_transform.basis.orthonormalized(), view_transform.origin)
		velocity = -transform.basis.z * 12.0
		return
	motor.place_at_view(view_transform)
	_has_pending_view_transform = false

func get_view_camera() -> Camera3D:
	return motor.get_view_camera()

func _collect_inputs(delta: float) -> void:
	motor._collect_inputs(delta)

func _update_aero_angles() -> void:
	motor._update_aero_angles()

func _get_gravity_force() -> Vector3:
	return motor._get_gravity_force()

func _try_flap_impulse() -> void:
	motor._try_flap_impulse()

func _get_flap_impulse_axis() -> Vector3:
	return motor._get_flap_impulse_axis()

func _get_aerodynamic_force() -> Vector3:
	return motor._get_aerodynamic_force()

func _get_extra_drag_force() -> Vector3:
	return motor._get_extra_drag_force()

func _update_camera_fly_by_wire_inputs(delta: float) -> void:
	motor._update_camera_fly_by_wire_inputs(delta)

func _get_camera_target_point() -> Vector3:
	return motor._get_camera_target_point()

func _update_fly_by_wire_inputs_for_target(delta: float, target_point: Vector3) -> void:
	motor._update_fly_by_wire_inputs_for_target(delta, target_point)

func _get_safe_world_direction(direction: Vector3, fallback: Vector3) -> Vector3:
	return motor._get_safe_world_direction(direction, fallback)

func _get_local_turn_angle(local_direction: Vector3) -> float:
	return motor._get_local_turn_angle(local_direction)

func _get_lift_vector_roll_target(local_direction: Vector3, turn_angle: float, frame_basis: Basis) -> float:
	return motor._get_lift_vector_roll_target(local_direction, turn_angle, frame_basis)

func _get_wings_level_roll_target(frame_basis: Basis) -> float:
	return motor._get_wings_level_roll_target(frame_basis)

func _get_roll_input_for_error(roll_error: float, angle_to_rate_gain: float, rate_scale := 1.0) -> float:
	return motor._get_roll_input_for_error(roll_error, angle_to_rate_gain, rate_scale)

func _get_lift_aligned_pitch_target(turn_angle: float, local_direction: Vector3) -> float:
	return motor._get_lift_aligned_pitch_target(turn_angle, local_direction)

func _get_lift_alignment_factor(local_direction: Vector3) -> float:
	return motor._get_lift_alignment_factor(local_direction)

func _get_turn_pull_pitch_target(turn_angle: float) -> float:
	return motor._get_turn_pull_pitch_target(turn_angle)

func _move_fly_by_wire_inputs(delta: float, roll_target: float, pitch_target: float) -> void:
	motor._move_fly_by_wire_inputs(delta, roll_target, pitch_target)

func _apply_direct_rotation(delta := 0.0) -> void:
	motor._apply_direct_rotation(delta)

func _apply_sideslip_compensation() -> void:
	motor._apply_sideslip_compensation()

func _get_aoa_limited_pitch_delta(requested_delta: float) -> float:
	return motor._get_aoa_limited_pitch_delta(requested_delta)

func _apply_collision_response() -> Vector3:
	return motor._apply_collision_response()

func _apply_q3_floor_friction(delta: float, floor_normal: Vector3) -> void:
	motor._apply_q3_floor_friction(delta, floor_normal)

func _clip_velocity(input_velocity: Vector3, plane_normal: Vector3, overbounce: float) -> Vector3:
	return motor._clip_velocity(input_velocity, plane_normal, overbounce)

func _sample_table(points: Array[Vector2], x_value: float) -> float:
	return motor._sample_table(points, x_value)

func _refresh_max_lift_aoa_limits() -> void:
	motor._refresh_max_lift_aoa_limits()

func _apply_controller_settings() -> void:
	motor._apply_controller_settings()

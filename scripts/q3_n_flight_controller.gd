class_name Q3NFlightController
extends CharacterBody3D

const DEFAULT_FLIGHT_HOLD_THRESHOLD := 0.3
const DEFAULT_FLIGHT_NO_CONTACT_THRESHOLD := 0.3
const FLIGHT_COLLISION_SIZE := Vector3(1.2, 1.2, 1.2)
const Q3_MOVEMENT_MOTOR := preload("res://scripts/q3_movement_motor.gd")
const FLIGHT_MOVEMENT_MOTOR := preload("res://scripts/flight_movement_motor.gd")
const Q3_MOVEMENT_HUD := preload("res://scripts/q3_movement_hud.gd")

enum Mode {
	Q3,
	FLIGHT,
}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var third_person_spring_arm: SpringArm3D = $Head/ThirdPersonSpringArm
@onready var third_person_camera: Camera3D = $Head/ThirdPersonSpringArm/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var character_collider_visual: MeshInstance3D = $CharacterColliderVisual
@onready var q3_hud: Q3_MOVEMENT_HUD = $Q3HUD
@onready var flight_body_mesh: MeshInstance3D = $FlightBodyMesh
@onready var flight_camera_rig: Node3D = $FlightCameraRig
@onready var flight_camera: Camera3D = $FlightCameraRig/SpringArm3D/Camera3D
@onready var flight_first_person_camera: Camera3D = $FlightFirstPersonCamera
@onready var flight_spring_arm: SpringArm3D = $FlightCameraRig/SpringArm3D
@onready var flight_hud: CanvasLayer = $FlightHUD
@onready var flight_status_label: Label = $FlightHUD/StatusLabel

var q3_motor := Q3_MOVEMENT_MOTOR.new()
var flight_motor := FLIGHT_MOVEMENT_MOTOR.new()
var mode := Mode.Q3
var flight_hold_threshold := DEFAULT_FLIGHT_HOLD_THRESHOLD
var flight_no_contact_threshold := DEFAULT_FLIGHT_NO_CONTACT_THRESHOLD
var flap_hold_time := 0.0
var no_surface_contact_time := 0.0


func _ready() -> void:
	flight_motor.setup(self, {
		"collision_shape": collision_shape,
		"body_mesh": flight_body_mesh,
		"camera_rig": flight_camera_rig,
		"camera": flight_camera,
		"first_person_camera": flight_first_person_camera,
		"spring_arm": flight_spring_arm,
		"status_label": flight_status_label,
	}, Settings.CHARACTER_Q3_N_FLIGHT, false)
	q3_motor.setup(self, {
		"head": head,
		"camera": camera,
		"third_person_spring_arm": third_person_spring_arm,
		"third_person_camera": third_person_camera,
		"collision_shape": collision_shape,
		"character_collider_visual": character_collider_visual,
		"hud": q3_hud,
	}, Settings.CHARACTER_Q3_N_FLIGHT)
	_sync_q3_body_size_to_flight()
	Settings.settings_changed.connect(on_settings_changed)
	_apply_controller_settings()
	_enter_q3(false)


func _process(delta: float) -> void:
	if mode == Mode.FLIGHT:
		flight_motor.process_tick(delta)
	else:
		q3_motor.process_tick(delta)


func _physics_process(delta: float) -> void:
	if mode == Mode.FLIGHT:
		flight_motor.physics_tick(delta)
		if get_slide_collision_count() > 0:
			_enter_q3(true)
		return

	_update_flap_hold(delta)
	q3_motor.physics_tick(delta)
	_update_no_surface_contact_time(delta)
	if _can_activate_flight():
		_enter_flight()


func _input(event: InputEvent) -> void:
	if mode == Mode.FLIGHT:
		flight_motor.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.Q3:
		q3_motor.handle_unhandled_input(event)


func place_at_view(view_transform: Transform3D) -> void:
	var euler := view_transform.basis.get_euler()
	position = view_transform.origin - (Vector3.UP * _get_q3_eye_height())
	rotation = Vector3(0.0, euler.y, 0.0)
	var view_head := get_node_or_null("Head") as Node3D
	if view_head:
		view_head.rotation = Vector3(euler.x, 0.0, 0.0)


func get_view_camera() -> Camera3D:
	if mode == Mode.FLIGHT:
		return flight_motor.get_view_camera()
	if q3_motor.third_person_enabled:
		return third_person_camera
	return camera


func on_settings_changed() -> void:
	q3_motor.on_settings_changed()
	_sync_q3_body_size_to_flight()
	flight_motor.on_settings_changed()
	_apply_controller_settings()
	if mode == Mode.Q3:
		_set_q3_visuals()


func _apply_controller_settings() -> void:
	flight_hold_threshold = Settings.get_controller_setting(
		"flight_hold_threshold",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	flight_no_contact_threshold = Settings.get_controller_setting(
		"flight_no_contact_threshold",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)


func _update_flap_hold(delta: float) -> void:
	if Input.is_action_pressed("player_jump"):
		flap_hold_time += delta
	else:
		flap_hold_time = 0.0


func _update_no_surface_contact_time(delta: float) -> void:
	if _is_touching_surface():
		no_surface_contact_time = 0.0
	else:
		no_surface_contact_time += delta


func _can_activate_flight() -> bool:
	return (
		flap_hold_time >= flight_hold_threshold
		and no_surface_contact_time >= flight_no_contact_threshold
	)


func _is_touching_surface() -> bool:
	return is_on_floor() or is_on_wall() or is_on_ceiling() or get_slide_collision_count() > 0


func _enter_flight() -> void:
	if mode == Mode.FLIGHT:
		return
	var preserved_velocity := velocity
	var preserved_position := global_position
	var view_transform := get_view_camera().global_transform
	var flight_basis := _get_takeoff_flight_basis(view_transform.basis, preserved_velocity)
	var view_euler := view_transform.basis.get_euler()
	if _body_would_overlap_with_basis(flight_basis):
		flight_basis = Basis(Vector3.UP, view_euler.y).orthonormalized()
	global_basis = flight_basis
	global_position = preserved_position
	flight_motor.camera_yaw = view_euler.y
	flight_motor.camera_pitch = clampf(
		view_euler.x,
		deg_to_rad(-75.0),
		deg_to_rad(60.0),
	)
	velocity = preserved_velocity
	mode = Mode.FLIGHT
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	flap_hold_time = 0.0
	flight_motor._apply_camera_rotation()
	flight_motor._update_aero_angles()
	_set_flight_visuals()


func _get_takeoff_flight_basis(view_basis: Basis, takeoff_velocity: Vector3) -> Basis:
	var horizontal_forward := -view_basis.orthonormalized().z
	horizontal_forward.y = 0.0
	if horizontal_forward.length_squared() <= 0.0001:
		horizontal_forward = Vector3(takeoff_velocity.x, 0.0, takeoff_velocity.z)
	if horizontal_forward.length_squared() <= 0.0001:
		horizontal_forward = -global_basis.z
		horizontal_forward.y = 0.0
	if horizontal_forward.length_squared() <= 0.0001:
		horizontal_forward = Vector3.FORWARD
	horizontal_forward = horizontal_forward.normalized()

	var right_axis := horizontal_forward.cross(Vector3.UP).normalized()
	var velocity_in_pitch_plane := takeoff_velocity - (right_axis * takeoff_velocity.dot(right_axis))
	var forward_axis := horizontal_forward
	if velocity_in_pitch_plane.length_squared() > 0.0001:
		forward_axis = velocity_in_pitch_plane.normalized()
	var up_axis := right_axis.cross(forward_axis).normalized()
	return Basis(right_axis, up_axis, -forward_axis).orthonormalized()


func _sync_q3_body_size_to_flight() -> void:
	q3_motor.set_character_size(FLIGHT_COLLISION_SIZE)


func _body_would_overlap_with_basis(candidate_basis: Basis) -> bool:
	if not is_inside_tree():
		return false
	var original_basis := global_basis
	global_basis = candidate_basis
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = safe_margin
	var overlaps := not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	global_basis = original_basis
	return overlaps


func _enter_q3(snap_upright: bool) -> void:
	var preserved_velocity := velocity
	if snap_upright:
		var upright_yaw := _get_upright_yaw()
		rotation = Vector3(0.0, upright_yaw, 0.0)
		q3_motor.yaw = upright_yaw
		q3_motor.pitch = clampf(
			flight_motor.camera_pitch,
			deg_to_rad(-89.0),
			deg_to_rad(89.0),
		)
		head.rotation = Vector3(q3_motor.pitch, 0.0, 0.0)
	velocity = preserved_velocity
	mode = Mode.Q3
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(q3_motor.max_slope_angle)
	floor_snap_length = q3_motor.step_height
	flap_hold_time = 0.0
	no_surface_contact_time = 0.0
	_set_q3_visuals()


func _set_q3_visuals() -> void:
	flight_motor.set_view_active(false)
	flight_hud.visible = false
	camera.current = not q3_motor.third_person_enabled
	third_person_camera.current = q3_motor.third_person_enabled
	character_collider_visual.visible = q3_motor.third_person_enabled


func _set_flight_visuals() -> void:
	flight_hud.visible = true
	camera.current = false
	third_person_camera.current = false
	flight_motor.set_view_active(true)
	character_collider_visual.visible = false


func _get_upright_yaw() -> float:
	var forward := Vector3(velocity.x, 0.0, velocity.z)
	if forward.length_squared() <= 0.0001:
		forward = -global_basis.z
		forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return rotation.y
	forward = forward.normalized()
	return atan2(-forward.x, -forward.z)


func _get_q3_eye_height() -> float:
	return (
		q3_motor.character_size.y
		* Q3_MOVEMENT_MOTOR.Q3_STANDING_EYE_HEIGHT
		/ Q3_MOVEMENT_MOTOR.Q3_STANDING_HULL_HEIGHT
	)

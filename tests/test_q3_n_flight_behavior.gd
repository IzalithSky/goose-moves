extends "res://tests/q3_test.gd"

const CONTROLLER_SCENE := preload("res://scenes/q3_n_flight_controller.tscn")

var c: Q3NFlightController
var phase := "direct_transitions"
var phase_frame := 0
var last_q3_position := Vector3.ZERO
var checked_no_contact_gate := false


func _ready() -> void:
	add_static_box(Vector3(24, 0.2, 24), Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)))
	add_static_box(Vector3(1, 6, 8), Transform3D(Basis.IDENTITY, Vector3(0, 3, -6)))
	c = CONTROLLER_SCENE.instantiate()
	c.position = Vector3(0, 3, 0)
	add_child(c)
	Input.action_release("player_jump")


func _goto(next: String) -> void:
	phase = next
	phase_frame = 0


func step() -> void:
	phase_frame += 1
	call("_" + phase)


func _has_hybrid_setting(key: String) -> bool:
	for def in Settings.get_controller_setting_defs(Settings.CHARACTER_Q3_N_FLIGHT):
		if str(def["key"]) == key:
			return true
	return false


func _hybrid_setting_default(key: String) -> float:
	for def in Settings.get_controller_setting_defs(Settings.CHARACTER_Q3_N_FLIGHT):
		if str(def["key"]) == key:
			return float(def["default"])
	return -1.0


func _get_pitch_axis_from_view(view_basis: Basis) -> Vector3:
	var horizontal_forward := -view_basis.orthonormalized().z
	horizontal_forward.y = 0.0
	return horizontal_forward.normalized().cross(Vector3.UP).normalized()


func _project_onto_pitch_plane(direction: Vector3, pitch_axis: Vector3) -> Vector3:
	return direction - (pitch_axis * direction.dot(pitch_axis))


func _direct_transitions() -> void:
	if phase_frame < 2:
		return
	check("hybrid settings hide Q3 size X", not _has_hybrid_setting("character_size_x"))
	check("hybrid settings expose no-contact flight gate", _has_hybrid_setting("flight_no_contact_threshold"))
	check("hybrid settings expose flight first-person camera", _has_hybrid_setting("first_person"))
	check("hybrid settings expose body bounce toggle", _has_hybrid_setting("body_bounce"))
	check("hybrid settings expose body bounce impact speed", _has_hybrid_setting("body_bounce_min_normal_speed"))
	check("hybrid settings expose body bounce knockdown time", _has_hybrid_setting("body_bounce_knockdown_duration"))
	check("hybrid settings expose body bounce restitution", _has_hybrid_setting("body_bounce_restitution"))
	check_approx("hybrid FOV defaults to 80", _hybrid_setting_default("fov"), 80.0, 0.001)
	check_approx("hybrid body bounce defaults enabled", _hybrid_setting_default("body_bounce"), 1.0, 0.001)
	check_approx("hybrid body bounce impact defaults to 14 m/s", _hybrid_setting_default("body_bounce_min_normal_speed"), 14.0, 0.001)
	check_approx("hybrid body bounce knockdown defaults to 1.2s", _hybrid_setting_default("body_bounce_knockdown_duration"), 1.2, 0.001)
	check_approx(
		"hybrid Q3 movement defaults CPM-like",
		_hybrid_setting_default("movement_mode"),
		Q3CharacterController.MovementMode.WARSOW_CLASSIC,
		0.001,
	)
	check_approx("hybrid Q3 defaults to third-person", _hybrid_setting_default("third_person"), 1.0, 0.001)
	check_approx(
		"hybrid flight defaults to third-person",
		_hybrid_setting_default("first_person"),
		0.0,
		0.001,
	)
	check_approx(
		"hybrid no-contact gate defaults to 0.3s",
		c.DEFAULT_FLIGHT_NO_CONTACT_THRESHOLD,
		0.3,
		0.001,
	)
	check_approx(
		"hybrid fixed size setting uses flight size",
		Settings.get_controller_setting("character_size_y", Settings.CHARACTER_Q3_N_FLIGHT),
		c.FLIGHT_COLLISION_SIZE.y,
		0.001,
	)
	check_vec3("hybrid Q3 hull matches flight collision size", c.q3_motor.body_shape.size, c.FLIGHT_COLLISION_SIZE, 0.001)
	check_vec3("hybrid Q3 character size matches flight collision size", c.q3_motor.character_size, c.FLIGHT_COLLISION_SIZE, 0.001)
	check_approx("hybrid Q3 hull stays feet anchored", c.collision_shape.position.y, c.FLIGHT_COLLISION_SIZE.y * 0.5, 0.001)
	c.body_bounce_restitution = 0.5
	check_vec3(
		"hybrid body bounce reflects by surface normal",
		c._get_body_bounce_velocity(Vector3(2, 0, -12), Vector3(0, 0, 1)),
		Vector3(1, 0, 6),
		0.001,
	)

	c.velocity = Vector3(3, 4, -5)
	c.global_basis = (
		Basis(Vector3.FORWARD, deg_to_rad(40.0))
		* Basis(Vector3.RIGHT, deg_to_rad(25.0))
	).orthonormalized()
	var q3_view_camera := c.get_view_camera()
	var q3_view_transform := q3_view_camera.global_transform
	var q3_view_fov := q3_view_camera.fov
	var takeoff_pitch_axis := _get_pitch_axis_from_view(q3_view_camera.global_basis)
	c._enter_flight()
	check("direct transition enters flight mode", c.mode == c.Mode.FLIGHT)
	check_vec3("Q3 -> flight preserves velocity", c.velocity, Vector3(3, 4, -5), 0.001)
	check("Q3 -> flight starts camera blend", c.camera_transition_active)
	check("Q3 -> flight uses transition camera during blend", c.transition_camera.current)
	check_vec3("Q3 -> flight camera blend starts at Q3 view", c.transition_camera.global_position, q3_view_transform.origin, 0.001)
	check_approx("Q3 -> flight camera blend starts at Q3 FOV", c.transition_camera.fov, q3_view_fov, 0.001)
	var flight_view_position := c.flight_camera.global_position
	c._update_camera_transition(c.CAMERA_TRANSITION_DURATION * 0.5)
	check("Q3 -> flight camera blend moves away from Q3 view", c.transition_camera.global_position.distance_to(q3_view_transform.origin) > 0.001)
	check("Q3 -> flight camera blend has not snapped to flight view", c.transition_camera.global_position.distance_to(flight_view_position) > 0.001)
	c._update_camera_transition(c.CAMERA_TRANSITION_DURATION)
	check("Q3 -> flight camera blend finishes", not c.camera_transition_active)
	check("Q3 -> flight camera hands off to flight camera", c.flight_camera.current)
	check_vec3(
		"Q3 -> flight pitches nose along takeoff velocity",
		_project_onto_pitch_plane(-c.global_basis.z, takeoff_pitch_axis).normalized(),
		_project_onto_pitch_plane(c.velocity, takeoff_pitch_axis).normalized(),
		0.001,
	)
	c.flight_motor.first_person_enabled = true
	c._set_flight_visuals()
	c.flight_motor._apply_camera_rotation()
	check("hybrid flight first-person camera becomes active", c.get_view_camera() == c.flight_first_person_camera)
	check("hybrid flight first-person camera is current", c.flight_first_person_camera.current)
	check("hybrid flight third-person camera is not current in first person", not c.flight_camera.current)
	check("hybrid flight body hides in first person", not c.flight_body_mesh.visible)
	c.flight_motor.first_person_enabled = false
	c._set_flight_visuals()
	check("hybrid flight third-person camera becomes active again", c.get_view_camera() == c.flight_camera)
	check("hybrid flight body shows in third person", c.flight_body_mesh.visible)

	var flight_view_transform := c.get_view_camera().global_transform
	var flight_view_fov := c.get_view_camera().fov
	c._enter_q3(true)
	check("direct transition returns to Q3 mode", c.mode == c.Mode.Q3)
	check_vec3("flight -> Q3 preserves velocity", c.velocity, Vector3(3, 4, -5), 0.001)
	check_approx("flight -> Q3 snaps pitch upright", c.rotation.x, 0.0, 0.001)
	check_approx("flight -> Q3 snaps roll upright", c.rotation.z, 0.0, 0.001)
	check("flight -> Q3 starts camera blend", c.camera_transition_active)
	check("flight -> Q3 uses transition camera during blend", c.transition_camera.current)
	check_vec3("flight -> Q3 camera blend starts at flight view", c.transition_camera.global_position, flight_view_transform.origin, 0.001)
	check_approx("flight -> Q3 camera blend starts at flight FOV", c.transition_camera.fov, flight_view_fov, 0.001)
	var q3_return_camera := c._get_q3_view_camera()
	var q3_return_position := q3_return_camera.global_position
	c._update_camera_transition(c.CAMERA_TRANSITION_DURATION * 0.5)
	check("flight -> Q3 camera blend moves away from flight view", c.transition_camera.global_position.distance_to(flight_view_transform.origin) > 0.001)
	check("flight -> Q3 camera blend has not snapped to Q3 view", c.transition_camera.global_position.distance_to(q3_return_position) > 0.001)
	c._update_camera_transition(c.CAMERA_TRANSITION_DURATION)
	check("flight -> Q3 camera blend finishes", not c.camera_transition_active)
	check("flight -> Q3 camera hands off to Q3 camera", q3_return_camera.current)
	Input.action_release("player_jump")
	Input.action_release("player_crouch")
	c.global_position = Vector3(4, 0.2, 4)
	c.velocity = Vector3.ZERO
	c.rotation = Vector3.ZERO
	c.head.rotation = Vector3.ZERO
	c.q3_motor.pitch = 0.0
	c.q3_motor.yaw = 0.0
	c._enter_q3(false)
	c.flight_hold_threshold = 0.0
	c.flight_no_contact_threshold = 0.1
	_goto("ground_gate_settle")


func _ground_gate_settle() -> void:
	if not c.is_on_floor():
		return
	Input.action_press("player_jump")
	Input.action_press("player_crouch")
	_goto("ground_gate_blocks_flight")


func _ground_gate_blocks_flight() -> void:
	if phase_frame < 12:
		return
	check("held flap cannot activate flight while grounded", c.mode == c.Mode.Q3)
	check_approx("grounded contact keeps no-contact timer reset", c.no_surface_contact_time, 0.0, 0.001)
	Input.action_release("player_jump")
	Input.action_release("player_crouch")
	c.global_position = Vector3(4, 0.2, 4)
	c.velocity = Vector3.ZERO
	c._enter_q3(false)
	_goto("low_hold_settle")


func _low_hold_settle() -> void:
	if not c.is_on_floor():
		return
	c.head.rotation = Vector3(deg_to_rad(-70.0), 0.0, 0.0)
	c.q3_motor.pitch = c.head.rotation.x
	c.flight_hold_threshold = 0.04
	c.flight_no_contact_threshold = 0.08
	c.flap_hold_time = 0.0
	c.no_surface_contact_time = 0.0
	checked_no_contact_gate = false
	last_q3_position = c.global_position
	Input.action_press("player_jump")
	_goto("low_hold_to_flight")


func _low_hold_to_flight() -> void:
	if c.mode == c.Mode.Q3:
		if (
			not checked_no_contact_gate
			and c.flap_hold_time >= c.flight_hold_threshold
			and c.no_surface_contact_time < c.flight_no_contact_threshold
		):
			check("held flap waits for airborne no-contact gate", c.mode == c.Mode.Q3)
			checked_no_contact_gate = true
		last_q3_position = c.global_position
		return
	check("low transition observed no-contact gate", checked_no_contact_gate)
	check("low held jump enters flight", c.mode == c.Mode.FLIGHT)
	check("low Q3 -> flight does not teleport", c.global_position.distance_to(last_q3_position) < 0.35)
	Input.action_release("player_jump")
	c._enter_q3(true)
	c.global_position = Vector3(0, 8, 0)
	c.velocity = Vector3.ZERO
	c.flight_hold_threshold = 0.05
	c.flight_no_contact_threshold = 0.05
	Input.action_press("player_jump")
	_goto("hold_to_flight")


func _hold_to_flight() -> void:
	if phase_frame < 2:
		check("short jump hold stays in Q3", c.mode == c.Mode.Q3)
		return
	if c.mode != c.Mode.FLIGHT:
		return
	check("held jump enters flight after threshold", c.mode == c.Mode.FLIGHT)
	Input.action_release("player_jump")
	c.global_position = Vector3(0, 3, 0)
	c.velocity = Vector3(2, 0, -12)
	c.global_basis = Basis.IDENTITY
	c._enter_flight()
	_goto("flight_contact_returns_q3")


func _flight_contact_returns_q3() -> void:
	if phase_frame < 20 and c.mode == c.Mode.FLIGHT:
		return
	check("flight contact with wall returns to Q3", c.mode == c.Mode.Q3)
	check_approx("contact return snaps pitch upright", c.rotation.x, 0.0, 0.001)
	check_approx("contact return snaps roll upright", c.rotation.z, 0.0, 0.001)
	check("contact return keeps tangential momentum", absf(c.velocity.x) > 0.5)
	Input.action_release("player_jump")
	c.body_bounce_enabled = true
	c.body_bounce_min_normal_speed = 5.0
	c.body_bounce_knockdown_duration = 0.25
	c.body_bounce_restitution = 0.5
	c.knockdown_time_remaining = 0.0
	c.q3_motor.control_enabled = true
	c.global_position = Vector3(0, 3, 0)
	c.velocity = Vector3(2, 0, -12)
	c.global_basis = Basis.IDENTITY
	c._enter_flight()
	_goto("flight_contact_bounces")


func _flight_contact_bounces() -> void:
	if phase_frame < 20 and c.mode == c.Mode.FLIGHT:
		return
	check("flight body bounce returns to Q3", c.mode == c.Mode.Q3)
	check("flight body bounce starts knockdown", c.knockdown_time_remaining > 0.0)
	check("flight body bounce disables Q3 control", not c.q3_motor.control_enabled)
	check("flight body bounce reflects away from wall", c.velocity.z > 0.0)
	check("flight body bounce keeps tangential velocity", c.velocity.x > 0.0)
	check("knockdown HUD shows active state", c.q3_hud.knockdown_sign_label.text == "+")
	Input.action_press("player_forward")
	check("knockdown suppresses Q3 movement input", c.q3_motor._get_movement_input().is_zero_approx())
	Input.action_release("player_forward")
	c._update_knockdown_timer(c.body_bounce_knockdown_duration)
	c._update_knockdown_hud()
	check("knockdown restores Q3 control", c.q3_motor.control_enabled)
	check("knockdown HUD clears active state", c.q3_hud.knockdown_sign_label.text == "-")
	finish()

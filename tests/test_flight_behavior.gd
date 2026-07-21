extends "res://tests/q3_test.gd"
# Flight controller: keyboard pitch requests AoA, A/D rolls the aircraft without
# a bank clamp, and slip/skid compensation coordinates the resulting turn.
#
# Frame model (see docs/testing.md): this node parents the controller and runs
# first, so state set here is seen by the controller the same frame.

const CONTROLLER_SCENE := preload("res://scenes/flight_controller.tscn")

var c
var max_bank_deg := 0.0
var max_abs_sideslip_deg := 0.0


func _ready() -> void:
	var pre_ready_controller := CONTROLLER_SCENE.instantiate() as FlightController
	var pre_ready_view := Transform3D(Basis.IDENTITY, Vector3(3.0, 4.0, 5.0))
	pre_ready_controller.place_at_view(pre_ready_view)
	check_vec3("pre-ready place_at_view sets flight spawn position", pre_ready_controller.position, pre_ready_view.origin, 0.001)
	check_vec3("pre-ready place_at_view seeds flight velocity", pre_ready_controller.velocity, Vector3(0.0, 0.0, -12.0), 0.001)
	pre_ready_controller.queue_free()

	c = CONTROLLER_SCENE.instantiate()
	add_child(c)
	# Anchor the aerodynamics to the code defaults so the test is independent of
	# any persisted user settings (mass/area/flap are otherwise loaded from
	# Settings and vary by machine).
	c.mass = c.DEFAULT_MASS
	c.reference_area = c.DEFAULT_REFERENCE_AREA
	c.gravity_scale = c.DEFAULT_GRAVITY_SCALE
	c.extra_linear_drag_quadratic_coefficient = c.DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT
	c.flap_impulse_strength = c.DEFAULT_FLAP_IMPULSE_STRENGTH
	c.flap_impulse_angle_rad = deg_to_rad(c.DEFAULT_FLAP_IMPULSE_ANGLE_DEGREES)
	c.flap_cooldown = c.DEFAULT_FLAP_COOLDOWN
	c.flap_cooldown_remaining = 0.0
	c.camera_fly_by_wire_enabled = false
	c.camera_fly_by_wire_target_distance = c.DEFAULT_CAMERA_FLY_BY_WIRE_TARGET_DISTANCE
	c.sideslip_compensation_enabled = c.DEFAULT_SIDESLIP_COMPENSATION_ENABLED >= 0.5
	c.sideslip_compensation_max_yaw_rad = deg_to_rad(c.DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES)
	# High up with nothing to collide with: pure airborne flight.
	c.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	c.velocity = Vector3(0, 0, -18.0)
	c.camera_yaw = 0.0
	c.camera_pitch = deg_to_rad(-15.0)
	c._apply_camera_rotation()
	Input.action_release("player_forward")
	Input.action_release("player_back")
	Input.action_release("player_left")
	Input.action_release("player_right")
	Input.action_press("player_back")
	Input.action_press("player_right")


func _flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	if v.length_squared() <= 1e-6:
		return Vector3.FORWARD
	return v.normalized()


func _has_flight_setting(key: String) -> bool:
	for def in Settings.get_controller_setting_defs(Settings.CHARACTER_FLIGHT):
		if str(def["key"]) == key:
			return true
	return false


func _heading_change_from_start_deg() -> float:
	return rad_to_deg(_flat_dir(Vector3(0.0, 0.0, -1.0)).angle_to(_flat_dir(c.velocity)))


func _check_knife_edge_pitch(test_name: String, pitch_input: float, expected_aoa_deg: float) -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_camera_yaw: float = c.camera_yaw
	var saved_camera_pitch: float = c.camera_pitch
	var saved_pitch_input: float = c.pitch_control_input
	var saved_roll_input: float = c.roll_control_input
	var saved_max_yaw: float = c.sideslip_compensation_max_yaw_rad
	c.global_basis = (Basis(Vector3(0.0, 0.0, -1.0), deg_to_rad(90.0)) * Basis.IDENTITY).orthonormalized()
	c.velocity = Vector3(0.0, 0.0, -18.0)
	c.camera_yaw = 0.0
	c.camera_pitch = deg_to_rad(-15.0)
	c.pitch_control_input = pitch_input
	c.roll_control_input = 0.0
	c.sideslip_compensation_max_yaw_rad = PI
	c._apply_camera_rotation()
	c._update_aero_angles()
	c._apply_direct_rotation(1.0)
	c._update_aero_angles()
	check_approx(test_name + " AoA is limited at knife edge", c.aoa_deg, expected_aoa_deg, 0.1)
	check_approx("knife-edge sideslip is compensated", c.sideslip_deg, 0.0, 0.1)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.camera_yaw = saved_camera_yaw
	c.camera_pitch = saved_camera_pitch
	c.pitch_control_input = saved_pitch_input
	c.roll_control_input = saved_roll_input
	c.sideslip_compensation_max_yaw_rad = saved_max_yaw
	c._apply_camera_rotation()
	c._update_aero_angles()


func _check_sideslip_compensation(test_name: String, basis: Basis, test_velocity: Vector3) -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_enabled: bool = c.sideslip_compensation_enabled
	var saved_max_yaw: float = c.sideslip_compensation_max_yaw_rad
	c.global_basis = basis.orthonormalized()
	c.velocity = test_velocity
	c.sideslip_compensation_enabled = true
	c.sideslip_compensation_max_yaw_rad = PI
	c._apply_sideslip_compensation()
	var axial: float = c.velocity.dot(-c.global_basis.z)
	var lateral: float = c.velocity.dot(c.global_basis.x)
	check(test_name + " aligns yaw-plane velocity", absf(lateral) < 0.001)
	check(test_name + " leaves velocity ahead after yaw", axial > 0.0)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.sideslip_compensation_enabled = saved_enabled
	c.sideslip_compensation_max_yaw_rad = saved_max_yaw
	c._update_aero_angles()


func _check_pitch_uses_body_right_axis() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_camera_yaw: float = c.camera_yaw
	var saved_camera_pitch: float = c.camera_pitch
	var saved_pitch_input: float = c.pitch_control_input
	var saved_roll_input: float = c.roll_control_input
	c.global_basis = (Basis(Vector3(0.0, 0.0, -1.0), deg_to_rad(90.0)) * Basis.IDENTITY).orthonormalized()
	var before_basis: Basis = c.global_basis
	var pitch_delta := deg_to_rad(30.0)
	var expected_basis := (Basis(before_basis.x.normalized(), pitch_delta) * before_basis).orthonormalized()
	c.velocity = Vector3.ZERO
	c.camera_yaw = 0.0
	c.camera_pitch = 0.0
	c.pitch_control_input = 1.0
	c.roll_control_input = 0.0
	c._apply_camera_rotation()
	c._apply_direct_rotation(pitch_delta / c.pitch_rate_rad)
	check_vec3("S pitches around body right", -c.global_basis.z, -expected_basis.z, 0.001)
	check_vec3("body-right pitch preserves body right axis", c.global_basis.x, expected_basis.x, 0.001)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.camera_yaw = saved_camera_yaw
	c.camera_pitch = saved_camera_pitch
	c.pitch_control_input = saved_pitch_input
	c.roll_control_input = saved_roll_input
	c._apply_camera_rotation()
	c._update_aero_angles()


func _check_key_pitch_aoa_limiter() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_pitch_input: float = c.pitch_control_input
	var saved_roll_input: float = c.roll_control_input
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3(0.0, 0.0, -18.0)
	c.pitch_control_input = 1.0
	c.roll_control_input = 0.0
	c._update_aero_angles()
	c._apply_direct_rotation(1.0)
	c._update_aero_angles()
	check_approx(
		"S pitch-up command is max-lift limited",
		c.aoa_deg,
		c._positive_max_lift_aoa_deg,
		0.1
	)
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3(0.0, 0.0, -18.0)
	c.pitch_control_input = -1.0
	c._update_aero_angles()
	c._apply_direct_rotation(1.0)
	c._update_aero_angles()
	check_approx(
		"W pitch-down command is max-lift limited",
		c.aoa_deg,
		c._negative_max_lift_aoa_deg,
		0.1
	)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.pitch_control_input = saved_pitch_input
	c.roll_control_input = saved_roll_input
	c._update_aero_angles()


func _check_roll_input_has_no_bank_limit() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_pitch_input: float = c.pitch_control_input
	var saved_roll_input: float = c.roll_control_input
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3.ZERO
	c.pitch_control_input = 0.0
	c.roll_control_input = 1.0
	c._apply_direct_rotation(deg_to_rad(90.0) / c.roll_rate_rad)
	check_approx("D rolls to knife edge without bank clamp", absf(c.global_basis.x.y), 1.0, 0.01)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.pitch_control_input = saved_pitch_input
	c.roll_control_input = saved_roll_input
	c._update_aero_angles()


func _check_roll_uses_body_forward_axis() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_pitch_input: float = c.pitch_control_input
	var saved_roll_input: float = c.roll_control_input
	c.global_basis = (Basis(Vector3.RIGHT, deg_to_rad(35.0)) * Basis.IDENTITY).orthonormalized()
	var before_basis: Basis = c.global_basis
	var roll_delta := deg_to_rad(30.0)
	var expected_basis := (Basis((-before_basis.z).normalized(), roll_delta) * before_basis).orthonormalized()
	c.velocity = Vector3.ZERO
	c.pitch_control_input = 0.0
	c.roll_control_input = 1.0
	c._apply_direct_rotation(roll_delta / c.roll_rate_rad)
	check_vec3("D rolls around body forward", c.global_basis.x, expected_basis.x, 0.001)
	check_vec3("body-forward roll preserves nose axis", -c.global_basis.z, -expected_basis.z, 0.001)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.pitch_control_input = saved_pitch_input
	c.roll_control_input = saved_roll_input
	c._update_aero_angles()


func _check_camera_target_fallback() -> void:
	var saved_transform: Transform3D = c.global_transform
	var saved_camera_yaw: float = c.camera_yaw
	var saved_camera_pitch: float = c.camera_pitch
	var saved_target_distance: float = c.camera_fly_by_wire_target_distance
	c.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 200.0, 0.0))
	c.camera_yaw = deg_to_rad(35.0)
	c.camera_pitch = 0.0
	c.camera_fly_by_wire_target_distance = 80.0
	c._apply_camera_rotation()
	var expected: Vector3 = c.camera.global_position + (-c.camera.global_basis.z * c.camera_fly_by_wire_target_distance)
	check_vec3("camera FBW target falls back along camera look", c._get_camera_target_point(), expected, 0.001)
	c.global_transform = saved_transform
	c.camera_yaw = saved_camera_yaw
	c.camera_pitch = saved_camera_pitch
	c.camera_fly_by_wire_target_distance = saved_target_distance
	c._apply_camera_rotation()


func _check_camera_rig_is_elevated() -> void:
	var expected_position: Vector3 = c.global_position + (Vector3.UP * c.DEFAULT_CAMERA_HEIGHT)
	check_vec3("flight camera rig follows above the character", c.camera_rig.global_position, expected_position, 0.001)


func _check_first_person_camera_toggle() -> void:
	check("flight settings expose first-person camera", _has_flight_setting("first_person"))
	c.first_person_enabled = true
	c._apply_camera_rotation()
	check("flight first-person camera becomes active", c.get_view_camera() == c.first_person_camera)
	check("flight first-person camera is current", c.first_person_camera.current)
	check("flight third-person camera is not current in first person", not c.camera.current)
	check("flight body mesh is hidden in first person", not c.body_mesh.visible)
	check_vec3(
		"flight first-person camera follows collision center",
		c.first_person_camera.global_position,
		c.collision_shape.global_position,
		0.001
	)
	var expected_target: Vector3 = (
		c.first_person_camera.global_position
		+ (-c.first_person_camera.global_basis.z * c.camera_fly_by_wire_target_distance)
	)
	check_vec3("flight FBW target uses first-person view", c._get_camera_target_point(), expected_target, 0.001)
	c.first_person_enabled = false
	c._apply_camera_rotation()
	check("flight third-person camera becomes active again", c.get_view_camera() == c.camera)
	check("flight third-person camera is current again", c.camera.current)
	check("flight body mesh is visible outside first person", c.body_mesh.visible)


func _check_fly_by_wire_uses_body_target_direction() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_position: Vector3 = c.global_position
	var saved_velocity: Vector3 = c.velocity
	var saved_pitch_input: float = c.pitch_control_input
	var saved_roll_input: float = c.roll_control_input
	c.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 200.0, 0.0))
	c.velocity = Vector3(0.0, 0.0, -18.0)
	c.pitch_control_input = 0.0
	c.roll_control_input = 0.0
	c._update_fly_by_wire_inputs_for_target(1.0, c.global_position + (c.global_basis.x * 100.0))
	check("camera FBW rolls right toward body-right target", c.roll_control_input > 0.1)
	check("camera FBW pulls while rolling toward side target", c.pitch_control_input > 0.1)

	c.pitch_control_input = 0.0
	c.roll_control_input = 0.0
	c._update_fly_by_wire_inputs_for_target(1.0, c.global_position + (c.global_basis.y * 100.0))
	check("camera FBW pulls up toward body-up target", c.pitch_control_input > 0.1)
	check("camera FBW does not roll for body-up target", absf(c.roll_control_input) < 0.01)

	c.global_basis = (Basis(Vector3.RIGHT, deg_to_rad(35.0)) * Basis.IDENTITY).orthonormalized()
	c.pitch_control_input = 0.0
	c.roll_control_input = 0.0
	c._update_fly_by_wire_inputs_for_target(1.0, c.global_position + (c.global_basis.x * 100.0))
	check("camera FBW side target remains body-relative when pitched", c.roll_control_input > 0.1)
	c.global_basis = saved_basis
	c.global_position = saved_position
	c.velocity = saved_velocity
	c.pitch_control_input = saved_pitch_input
	c.roll_control_input = saved_roll_input
	c._update_aero_angles()


func _signed_yaw_delta_deg(before_basis: Basis, after_basis: Basis) -> float:
	var before_forward: Vector3 = -before_basis.z
	var after_forward: Vector3 = -after_basis.z
	return rad_to_deg(atan2(
		before_forward.cross(after_forward).dot(before_basis.y),
		before_forward.dot(after_forward)
	))


func _check_sideslip_yaw_limit() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_enabled: bool = c.sideslip_compensation_enabled
	var saved_max_yaw: float = c.sideslip_compensation_max_yaw_rad
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3(10.0, 0.0, -10.0)
	c.sideslip_compensation_enabled = true
	c.sideslip_compensation_max_yaw_rad = deg_to_rad(5.0)
	var before_basis: Basis = c.global_basis
	c._apply_sideslip_compensation()
	check_approx("sideslip compensation yaw is capped per frame", _signed_yaw_delta_deg(before_basis, c.global_basis), -5.0, 0.001)
	var remaining_lateral: float = c.velocity.dot(c.global_basis.x)
	check("limited sideslip compensation leaves residual skid", absf(remaining_lateral) > 0.001)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.sideslip_compensation_enabled = saved_enabled
	c.sideslip_compensation_max_yaw_rad = saved_max_yaw
	c._update_aero_angles()


func _check_sideslip_compensation_toggle() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_enabled: bool = c.sideslip_compensation_enabled
	var saved_max_yaw: float = c.sideslip_compensation_max_yaw_rad
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3(10.0, 0.0, -10.0)
	c.sideslip_compensation_enabled = false
	c.sideslip_compensation_max_yaw_rad = PI
	var before_basis: Basis = c.global_basis
	c._apply_sideslip_compensation()
	check_approx("disabled sideslip compensation applies no yaw", _signed_yaw_delta_deg(before_basis, c.global_basis), 0.0, 0.001)
	check_approx("disabled sideslip compensation leaves skid unchanged", c.velocity.dot(c.global_basis.x), 10.0, 0.001)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.sideslip_compensation_enabled = saved_enabled
	c.sideslip_compensation_max_yaw_rad = saved_max_yaw
	c._update_aero_angles()


func _check_flap_impulse() -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_strength: float = c.flap_impulse_strength
	var saved_angle: float = c.flap_impulse_angle_rad
	var saved_cooldown: float = c.flap_cooldown
	var saved_cooldown_remaining: float = c.flap_cooldown_remaining
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3.ZERO
	c.flap_impulse_strength = 10.0
	c.flap_impulse_angle_rad = deg_to_rad(45.0)
	c.flap_cooldown = 0.5
	c.flap_cooldown_remaining = 0.0
	c._try_flap_impulse()
	var expected_component: float = 10.0 / sqrt(2.0)
	check_vec3(
		"flap impulse applies along forward/up angle",
		c.velocity,
		Vector3(0.0, expected_component, -expected_component),
		0.001
	)
	check_approx("flap impulse starts cooldown", c.flap_cooldown_remaining, 0.5)
	var velocity_after_first: Vector3 = c.velocity
	c._try_flap_impulse()
	check_vec3("flap cooldown blocks repeated impulse", c.velocity, velocity_after_first, 0.001)
	c.flap_cooldown_remaining = 0.0
	c.flap_impulse_angle_rad = deg_to_rad(90.0)
	c._try_flap_impulse()
	check_vec3(
		"straight-up flap impulse uses local up",
		c.velocity,
		velocity_after_first + Vector3.UP * 10.0,
		0.001
	)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.flap_impulse_strength = saved_strength
	c.flap_impulse_angle_rad = saved_angle
	c.flap_cooldown = saved_cooldown
	c.flap_cooldown_remaining = saved_cooldown_remaining
	c._update_aero_angles()


func step() -> void:
	# Bank angle: how far the body right axis has tilted out of horizontal.
	max_bank_deg = maxf(max_bank_deg, absf(rad_to_deg(asin(clampf(c.global_basis.x.y, -1.0, 1.0)))))
	# Track worst skid once past the initial settling transient.
	if frame > 30:
		max_abs_sideslip_deg = maxf(max_abs_sideslip_deg, absf(c.sideslip_deg))

	if frame == 3:
		check("S maps to pitch-up input", c.pitch_control_input > 0.9)
		check("D maps to roll-right input", c.roll_control_input > 0.9)
		_check_knife_edge_pitch("S pitch-up", 1.0, c._positive_max_lift_aoa_deg)
		_check_knife_edge_pitch("W pitch-down", -1.0, c._negative_max_lift_aoa_deg)
		_check_pitch_uses_body_right_axis()
		_check_key_pitch_aoa_limiter()
		_check_roll_input_has_no_bank_limit()
		_check_roll_uses_body_forward_axis()
		_check_camera_rig_is_elevated()
		_check_camera_target_fallback()
		_check_first_person_camera_toggle()
		_check_fly_by_wire_uses_body_target_direction()
		_check_sideslip_compensation("forward axial sideslip", Basis.IDENTITY, Vector3(4.0, 0.0, -10.0))
		_check_sideslip_compensation("negative axial sideslip", Basis.IDENTITY, Vector3(3.0, 0.0, 8.0))
		var banked_basis := Basis(Vector3.FORWARD, deg_to_rad(90.0))
		_check_sideslip_compensation(
			"knife-edge sideslip",
			banked_basis,
			(-banked_basis.z * -8.0) + (banked_basis.x * 3.0) + (banked_basis.y * 5.0)
		)
		_check_sideslip_yaw_limit()
		_check_sideslip_compensation_toggle()
		_check_flap_impulse()

	if frame == 30:
		Input.action_release("player_right")

	if frame >= 180:
		Input.action_release("player_back")
		Input.action_release("player_right")
		check("banked lift turns the heading from the original path",
			_heading_change_from_start_deg() > 10.0)
		check("keyboard roll banks past the former 45 degree clamp", max_bank_deg > 45.0)
		check("still flying (airspeed retained)", c.velocity.length() > 3.0)
		# Auto-yaw sideslip compensation: the banked turn stays coordinated.
		check("banked turn keeps limited sideslip bounded",
			max_abs_sideslip_deg < 15.0)
		finish()

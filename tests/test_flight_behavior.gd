extends "res://tests/q3_test.gd"
# Flight controller: a held bank must turn the aircraft toward the look
# direction. Lift is applied along the body up axis, so banking tilts the lift
# vector; its horizontal component curves the velocity, and the heading
# weathervanes onto that velocity — so the aircraft comes round.
#
# Regression guard for the frozen-yaw bug: seeding the heading from the body's
# own -Z kept the yaw constant, so a bank built sideslip but never turned (0
# deg/s). Here the only horizontal force is banked lift (no thrust/flap is
# triggered), so any heading change is that lift turning the plane.
#
# Frame model (see docs/testing.md): this node parents the controller and runs
# first, so state set here is seen by the controller the same frame.

const CONTROLLER_SCENE := preload("res://scenes/flight_controller.tscn")

var c
var baseline_error_deg := 0.0
var max_bank_deg := 0.0
var max_abs_sideslip_deg := 0.0


func _ready() -> void:
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
	c.max_bank_angle_rad = deg_to_rad(90.0)
	c.sideslip_compensation_enabled = c.DEFAULT_SIDESLIP_COMPENSATION_ENABLED >= 0.5
	c.sideslip_compensation_max_yaw_rad = deg_to_rad(c.DEFAULT_SIDESLIP_COMPENSATION_MAX_YAW_DEGREES)
	# High up with nothing to collide with: pure airborne flight.
	c.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	c.velocity = Vector3(0, 0, -18.0)
	# Look ~35 deg off the current heading (drives the bank) with the nose held
	# above the flight path (positive AoA -> lift to bank with).
	c.camera_yaw = deg_to_rad(35.0)
	c.camera_pitch = deg_to_rad(12.0)
	c._apply_camera_rotation()


func _flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	if v.length_squared() <= 1e-6:
		return Vector3.FORWARD
	return v.normalized()


func _alignment_error_deg() -> float:
	return rad_to_deg(_flat_dir(-c.global_basis.z).angle_to(_flat_dir(-c.camera.global_basis.z)))


func _horizontal_speed() -> float:
	return Vector2(c.velocity.x, c.velocity.z).length()


func _check_knife_edge_pitch(requested_pitch_deg: float, expected_aoa_deg: float) -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_camera_yaw: float = c.camera_yaw
	var saved_camera_pitch: float = c.camera_pitch
	var saved_bank_limit: float = c.max_bank_angle_rad
	var saved_max_yaw: float = c.sideslip_compensation_max_yaw_rad
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3(0.0, 0.0, -18.0)
	c.camera_yaw = PI
	c.camera_pitch = deg_to_rad(requested_pitch_deg)
	c.max_bank_angle_rad = deg_to_rad(90.0)
	c.sideslip_compensation_max_yaw_rad = PI
	c._apply_camera_rotation()
	c._apply_direct_rotation()
	c._update_aero_angles()
	check_approx("knife-edge AoA follows character pitch", c.aoa_deg, expected_aoa_deg, 0.1)
	check_approx("knife-edge sideslip is compensated", c.sideslip_deg, 0.0, 0.1)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.camera_yaw = saved_camera_yaw
	c.camera_pitch = saved_camera_pitch
	c.max_bank_angle_rad = saved_bank_limit
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


func _check_bank_limit(limit_deg: float) -> void:
	var saved_basis: Basis = c.global_basis
	var saved_velocity: Vector3 = c.velocity
	var saved_camera_yaw: float = c.camera_yaw
	var saved_camera_pitch: float = c.camera_pitch
	var saved_bank_limit: float = c.max_bank_angle_rad
	c.global_basis = Basis.IDENTITY
	c.velocity = Vector3(0.0, 0.0, -18.0)
	c.camera_yaw = PI
	c.camera_pitch = 0.0
	c.max_bank_angle_rad = deg_to_rad(limit_deg)
	c._apply_camera_rotation()
	c._apply_direct_rotation()
	var bank_deg: float = absf(rad_to_deg(asin(clampf(c.global_basis.x.y, -1.0, 1.0))))
	check_approx("bank limit applies at %.0f degrees" % limit_deg, bank_deg, limit_deg, 0.1)
	c.global_basis = saved_basis
	c.velocity = saved_velocity
	c.camera_yaw = saved_camera_yaw
	c.camera_pitch = saved_camera_pitch
	c.max_bank_angle_rad = saved_bank_limit
	c._apply_camera_rotation()
	c._update_aero_angles()


func _check_pitch_down_bank_scaling() -> void:
	var saved_bank_limit: float = c.max_bank_angle_rad
	c.max_bank_angle_rad = deg_to_rad(90.0)
	var pitch_down: float = deg_to_rad(-30.0)
	var pitch_up: float = deg_to_rad(30.0)
	check_approx("pitch down is full at zero bank", rad_to_deg(c._get_bank_scaled_aoa(pitch_down, 0.0)), -30.0, 0.001)
	check_approx("pitch down is half at half bank", rad_to_deg(c._get_bank_scaled_aoa(pitch_down, deg_to_rad(45.0))), -15.0, 0.001)
	check_approx("pitch down is zero at max bank", rad_to_deg(c._get_bank_scaled_aoa(pitch_down, deg_to_rad(90.0))), 0.0, 0.001)
	check_approx("pitch up ignores bank scaling", rad_to_deg(c._get_bank_scaled_aoa(pitch_up, deg_to_rad(90.0))), 30.0, 0.001)
	c.max_bank_angle_rad = saved_bank_limit


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
	max_bank_deg = maxf(max_bank_deg, rad_to_deg(asin(clampf(c.global_basis.x.y, -1.0, 1.0))))
	# Track worst skid once past the initial settling transient.
	if frame > 30:
		max_abs_sideslip_deg = maxf(max_abs_sideslip_deg, absf(c.sideslip_deg))

	if frame == 3:
		baseline_error_deg = _alignment_error_deg()
		check("starts misaligned with the look direction", baseline_error_deg > 25.0)
		_check_knife_edge_pitch(45.0, c._positive_max_lift_aoa_deg)
		_check_knife_edge_pitch(-45.0, 0.0)
		_check_pitch_down_bank_scaling()
		_check_sideslip_compensation("forward axial sideslip", Basis.IDENTITY, Vector3(4.0, 0.0, -10.0))
		_check_sideslip_compensation("negative axial sideslip", Basis.IDENTITY, Vector3(3.0, 0.0, 8.0))
		var banked_basis := Basis(Vector3.FORWARD, deg_to_rad(90.0))
		_check_sideslip_compensation(
			"knife-edge sideslip",
			banked_basis,
			(-banked_basis.z * -8.0) + (banked_basis.x * 3.0) + (banked_basis.y * 5.0)
		)
		_check_bank_limit(30.0)
		_check_bank_limit(c.DEFAULT_MAX_BANK_ANGLE_DEGREES)
		_check_sideslip_yaw_limit()
		_check_sideslip_compensation_toggle()
		_check_flap_impulse()

	if frame >= 540:
		# A frozen-yaw controller leaves the error unchanged; a weathervaning one
		# curves the heading toward the look direction under banked lift.
		check("banked lift turns the heading toward the look direction",
			_alignment_error_deg() < baseline_error_deg - 10.0)
		check("aircraft rolled into a bank while turning", max_bank_deg > 3.0)
		check("still flying (horizontal speed retained)", _horizontal_speed() > 3.0)
		# Auto-yaw sideslip compensation: the banked turn stays coordinated.
		check("banked turn keeps limited sideslip bounded",
			max_abs_sideslip_deg < 5.0)
		finish()

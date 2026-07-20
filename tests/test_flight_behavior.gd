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
	# any persisted user settings (mass/area/thrust are otherwise loaded from
	# Settings and vary by machine).
	c.mass = c.DEFAULT_MASS
	c.reference_area = c.DEFAULT_REFERENCE_AREA
	c.gravity_scale = c.DEFAULT_GRAVITY_SCALE
	c.max_thrust = c.DEFAULT_MAX_THRUST
	c.extra_linear_drag_quadratic_coefficient = c.DEFAULT_EXTRA_LINEAR_DRAG_QUADRATIC_COEFFICIENT
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


func step() -> void:
	# Bank angle: how far the body right axis has tilted out of horizontal.
	max_bank_deg = maxf(max_bank_deg, rad_to_deg(asin(clampf(c.global_basis.x.y, -1.0, 1.0))))
	# Track worst skid once past the initial settling transient.
	if frame > 30:
		max_abs_sideslip_deg = maxf(max_abs_sideslip_deg, absf(c.sideslip_deg))

	if frame == 3:
		baseline_error_deg = _alignment_error_deg()
		check("starts misaligned with the look direction", baseline_error_deg > 25.0)

	if frame >= 540:
		# A frozen-yaw controller leaves the error unchanged; a weathervaning one
		# curves the heading toward the look direction under banked lift.
		check("banked lift turns the heading toward the look direction",
			_alignment_error_deg() < baseline_error_deg - 10.0)
		check("aircraft rolled into a bank while turning", max_bank_deg > 3.0)
		check("still flying (horizontal speed retained)", _horizontal_speed() > 3.0)
		# Auto-yaw sideslip compensation: the banked turn stays coordinated.
		check("banked turn holds near-zero sideslip (coordinated)",
			max_abs_sideslip_deg < 1.0)
		finish()

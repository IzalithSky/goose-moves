extends "res://tests/q3_test.gd"
# Pins the CharacterBody3D behaviors the Q3 controller is built around
# (verified on Godot 4.6.1 + Jolt). None of these are controller code — they
# are engine facts. If a Godot upgrade breaks this suite, the post-move
# velocity handling in q3_character_controller.gd must be re-reviewed.

var body: CharacterBody3D
var coast_speed := 0.0


func _ready() -> void:
	add_static_box(Vector3(60, 1, 60), Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	add_static_box(Vector3(30, 1, 10), Transform3D(Basis(Vector3.BACK, deg_to_rad(30.0)), Vector3(100, 0, 0)))
	body = add_probe_body()
	body.global_position = Vector3(100, 1.2, 0)


func _renormalizing_project(plane_normal: Vector3) -> void:
	# Q3 WalkMove-style projection: slide, then restore the pre-slide magnitude.
	var speed := body.velocity.length()
	body.velocity = body.velocity.slide(plane_normal)
	if not body.velocity.is_zero_approx():
		body.velocity = body.velocity.normalized() * speed


func step() -> void:
	if frame <= 12:
		body.velocity = Vector3(0, -5, 0)
		body.move_and_slide()
		if frame == 12:
			check("settled on the 30 deg ramp", body.is_on_floor())
			check_vec3("ramp floor normal", body.get_floor_normal(),
				Vector3(-0.5, cos(deg_to_rad(30.0)), 0.0), 1e-3)
			coast_speed = 10.0
			body.velocity = Vector3(signf(body.get_floor_normal().x) * coast_speed, 0.0, 0.0)
	elif frame <= 17:
		# Fact 1: grounded move_and_slide flattens velocity.y whenever the body
		# ends the call on the floor without moving up ("reset the gravity
		# accumulation"). Combined with a renormalizing PRE-move projection this
		# costs exactly cos(slope) per frame — which is why the controller
		# projects AFTER move_and_slide using the pre-move magnitude.
		_renormalizing_project(body.get_floor_normal())
		check_approx("pre-move projection preserves |v| (frame %d)" % frame,
			body.velocity.length(), coast_speed, 1e-3)
		body.move_and_slide()
		check("still on floor (frame %d)" % frame, body.is_on_floor())
		check_approx("move_and_slide flattened velocity.y (frame %d)" % frame,
			body.velocity.y, 0.0, 1e-4)
		coast_speed *= body.get_floor_normal().y
		check_approx("speed decayed by cos(slope) (frame %d)" % frame,
			body.velocity.length(), coast_speed, 1e-2)
	elif frame == 18:
		body.global_position = Vector3(0, 5, 0)
		body.velocity = Vector3(0, -1, 0)
		body.move_and_slide()
		check("airborne after teleporting high", not body.is_on_floor())
	elif frame == 19:
		# Fact 2: move_and_slide applies no gravity, friction, or damping of
		# its own — the script is the only source of forces.
		body.global_position = Vector3(0, 0.5, 0)
		body.velocity = Vector3(8, -8, 0)
		body.move_and_slide()
		check("no contact 0.37 m above the floor", not body.is_on_floor())
		check_vec3("airborne move_and_slide leaves velocity untouched",
			body.velocity, Vector3(8, -8, 0))
		check_approx("travelled exactly velocity*dt",
			body.global_position.y, 0.5 - 8.0 * DT, 1e-4)
		# Fact 3: apply_floor_snap grounds a falling body from anywhere within
		# floor_snap_length, teleporting it down without clipping velocity.
		body.apply_floor_snap()
		check("apply_floor_snap grounded the falling body", body.is_on_floor())
		check("apply_floor_snap teleported to the floor", body.global_position.y < 0.01)
		check_vec3("apply_floor_snap left velocity unclipped", body.velocity, Vector3(8, -8, 0))
	elif frame == 20:
		# Consequence of fact 3: a renormalizing projection right after a
		# snap-landing converts fall speed into horizontal speed. The
		# controller must clip (not renormalize) on landing frames.
		_renormalizing_project(body.get_floor_normal())
		check_approx("snap-landing + renormalize converts fall speed to horizontal",
			body.velocity.length(), sqrt(128.0), 1e-3)
		check_approx("converted velocity is fully horizontal", body.velocity.y, 0.0, 1e-4)
		# Fact 4: a real-collision landing inside move_and_slide clips velocity
		# Q3-style (into-plane component removed, no renormalize).
		body.global_position = Vector3(10, 0.05, 0)
		body.velocity = Vector3(8, -8, 0)
	elif frame == 21:
		body.move_and_slide()
		check("real-collision landing grounds the body", body.is_on_floor())
		check_vec3("real-collision landing clips velocity (no renormalize)",
			body.velocity, Vector3(8, 0, 0), 5e-3)
		finish()

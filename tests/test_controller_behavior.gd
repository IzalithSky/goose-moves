extends "res://tests/q3_test.gd"
# Full-controller simulation: the real controller scene on built fixtures,
# driven with programmatic input across physics frames. Hard checks assert
# Q3-correct behavior (docs/q3-movement.md).
#
# Frame model (empirical): this node is the controller's parent and processes
# first, so velocity injected here is seen by the controller the same frame.
# Input.action_press updates strengths immediately, but is_action_just_pressed
# only fires on the NEXT physics frame — jump effects appear one frame after
# the press, and are asserted one frame after that.

const CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const U := 0.3048 / 8.0
const Q3_APEX := 1.7374        # 270^2/(2*800) in metres: exact parabola apex

var c
var phase := "settle"
var phase_frame := 0
var floor_y := 0.0
var vy_prev := 0.0
var apex := 0.0
var injected := false
var expected := 0.0
var bhop_speed := 0.0
var autojump_started := false
var autojump_landed := false
var crouch_slide_landed := false
var crouch_slide_landing_speed := 0.0


func _ready() -> void:
	add_static_box(Vector3(40, 1, 40), Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	add_static_box(Vector3(30, 1, 30), Transform3D(Basis.IDENTITY, Vector3(40, -0.5, 0)), true)
	add_static_box(Vector3(1, 4, 30), Transform3D(Basis.IDENTITY, Vector3(46, 2, 0)))
	add_static_box(Vector3(40, 1, 12),
		Transform3D(Basis(Vector3.BACK, deg_to_rad(30.0)), Vector3(100, 0, 0)), true)
	c = CONTROLLER_SCENE.instantiate()
	c.position = Vector3(0, 0.05, 0)
	add_child(c)
	c.auto_jump = false


func _goto(next: String) -> void:
	phase = next
	phase_frame = 0


func _horizontal_speed() -> float:
	return Vector2(c.velocity.x, c.velocity.z).length()


func step() -> void:
	phase_frame += 1
	call("_" + phase)


func _settle() -> void:
	if phase_frame < 10:
		return
	check("settled on the plain floor", c.is_on_floor())
	check("idle velocity is zero", c.velocity.length() < 0.01)
	floor_y = c.global_position.y
	check_approx("standing at floor height", floor_y, 0.0, 0.01)
	check("player hull uses Q3's box shape", c.body_shape is BoxShape3D)
	check_approx("player hull width = 30 u", c.body_shape.size.x, 30.0 * U)
	check_approx("player hull depth = 30 u", c.body_shape.size.z, 30.0 * U)
	_goto("idle")


func _idle() -> void:
	if phase_frame < 30:
		return
	# no force is double-applied while grounded: the body neither sinks nor
	# accumulates velocity over 30 untouched frames
	check("no velocity accumulation while grounded", c.velocity.length() < 0.01)
	check_approx("no position drift while grounded", c.global_position.y, floor_y, 0.005)
	check("still grounded after idling", c.is_on_floor())
	c.velocity = Vector3(5, 0, 0)
	expected = 5.0
	_goto("ground_friction")


func _ground_friction() -> void:
	# replicate PM_Friction per tick: drop = max(speed, stopspeed)*friction*dt
	expected = maxf(expected - maxf(expected, c.stop_speed) * c.friction * DT, 0.0)
	if phase_frame < 10:
		return
	check_approx("coasting decays exactly by PM_Friction (10 ticks)",
		_horizontal_speed(), expected, expected * 0.01 + 0.001)
	c.velocity = Vector3.ZERO
	Input.action_press("player_jump")
	_goto("jump")


func _jump() -> void:
	if phase_frame == 1:
		return  # the controller consumes the jump press during this frame
	if phase_frame == 2:
		Input.action_release("player_jump")
		check_approx("jump frame stores vy after one air gravity tick",
			c.velocity.y, c.jump_velocity - c.gravity * DT, 1e-4)
		check("jump left the ground", not c.is_on_floor())
		vy_prev = c.velocity.y
		apex = c.global_position.y
		return
	apex = maxf(apex, c.global_position.y)
	if phase_frame <= 4:
		check_approx("airborne gravity is a single g*dt per tick (frame %d)" % phase_frame,
			vy_prev - c.velocity.y, c.gravity * DT, 1e-4)
		vy_prev = c.velocity.y
	if not injected and c.velocity.y < -2.0:
		c.velocity.x = 8.0  # horizontal speed for the landing checks
		injected = true
	if not c.is_on_floor():
		return
	check_approx("jump apex matches Q3's trapezoid integration",
		apex - floor_y, Q3_APEX, 0.02)
	# the landing frame must clip fall speed away, never convert it to
	# horizontal speed (the old apply_floor_snap + renormalize bug)
	check_approx("landing keeps horizontal speed exactly (no fall-speed conversion)",
		_horizontal_speed(), 8.0, 0.05)
	check_approx("landing zeroed vertical speed", c.velocity.y, 0.0, 0.01)
	Input.action_press("player_jump")
	_goto("bhop")


func _bhop() -> void:
	if phase_frame == 1:
		# input latency: the controller ticks once grounded before the jump
		# arrives, costing exactly one PM_Friction tick — record the result
		bhop_speed = c.velocity.x
		check_approx("one grounded tick before the bhop jump costs one friction tick",
			bhop_speed, 8.0 * (1.0 - c.friction * DT), 1e-3)
		return
	Input.action_release("player_jump")
	# PM_CheckJump precedes PM_Friction and hands the frame to the air path:
	# the tick that consumes the jump must not touch horizontal speed
	check_approx("bhop jump frame applies no ground friction", c.velocity.x, bhop_speed, 1e-4)
	check_approx("bhop jump frame set vy again",
		c.velocity.y, c.jump_velocity - c.gravity * DT, 1e-4)
	check("bhop left the ground", not c.is_on_floor())
	c.global_position = Vector3(40, 0.05, 0)
	c.velocity = Vector3(0, -1, 0)
	_goto("slick_settle")


func _slick_settle() -> void:
	if phase_frame < 6:
		return
	check("settled on the slick pad", c.is_on_floor())
	check("flat slick detected by the ground trace", c.floor_is_slick)
	c.velocity = Vector3(5, 0, 0)
	expected = 5.0
	_goto("slick_flat")


func _slick_flat() -> void:
	# Q3 slick ground: no friction, air accel, gravity while walking. On flat
	# ice speed must hold exactly: gravity has no component along a flat floor.
	if phase_frame < 10:
		return
	var horizontal_speed := _horizontal_speed()
	check("no friction on slick: speed did not decay", horizontal_speed >= 4.99)
	check("slick speed bounded (no runaway gain)", horizontal_speed <= 5.3)
	check("flat slick holds speed exactly", absf(horizontal_speed - 5.0) <= 0.01)
	Input.action_press("player_jump")
	_goto("slick_jump")


func _slick_jump() -> void:
	if phase_frame == 1:
		return  # controller consumes the jump press this frame
	Input.action_release("player_jump")
	# PM_CheckJump runs before the slick branch: ice is jumpable in Q3
	check_approx("can jump off slick ground",
		c.velocity.y, c.jump_velocity - c.gravity * DT, 1e-4)
	c.global_position = Vector3(102, 2.3, 0)
	c.velocity = Vector3(0, -1, 0)
	_goto("slope_settle")


func _slope_settle() -> void:
	if phase_frame < 14:
		return
	check("settled on the slick 30 deg ramp", c.is_on_floor())
	check_approx("ramp floor normal", c.get_floor_normal().y, cos(deg_to_rad(30.0)), 1e-3)
	check("sloped slick detected by the ground trace", c.floor_is_slick)
	var downhill: Vector3 = Vector3.DOWN.slide(c.get_floor_normal()).normalized()
	c.velocity = downhill * 5.0
	expected = 5.0
	_goto("slope_coast")


func _slope_coast() -> void:
	# Q3 ice slope: gravity accelerates the slide by ~g*sin(slope) per tick;
	# the pre-fix controller instead decayed by cos(slope) per frame.
	var g_dt: float = c.gravity * DT
	var sin_slope := sqrt(1.0 - pow(cos(deg_to_rad(30.0)), 2.0))
	expected = sqrt((expected * expected) + (2.0 * expected * g_dt * sin_slope) + (g_dt * g_dt))
	if phase_frame < 10:
		return
	check("still on the ramp", c.is_on_floor())
	check_approx("slick downhill gains ~g*sin(slope) per tick (no cos-decay)",
		c.velocity.length(), expected, expected * 0.02)
	check("gained speed sliding downhill on ice", c.velocity.length() > 5.5)
	c.global_position = Vector3(43, 0.05, -3)
	c.velocity = Vector3(0, -1, 0)
	_goto("wall_settle")


func _wall_settle() -> void:
	if phase_frame < 6:
		return
	check("settled before the wall", c.is_on_floor())
	c.velocity = Vector3(6, 0, 6)
	_goto("wall_hit")


func _wall_hit() -> void:
	if absf(c.velocity.x) < 1.0:
		check("wall removed the into-wall velocity component", absf(c.velocity.x) < 0.5)
		check("wall slide kept the tangential component", c.velocity.z > 5.0)
		check("grounded wall hit costs the into-wall component",
			absf(_horizontal_speed() - 6.0) <= 0.4)
		c.global_position = Vector3(0, 0.05, 0)
		c.velocity = Vector3(0, -1, 0)
		_goto("crouch_settle")
		return
	if phase_frame > 40:
		fail("never reached the wall")
		finish()


func _crouch_settle() -> void:
	if phase_frame < 6:
		return
	check("back on the plain floor", c.is_on_floor())
	Input.action_press("player_crouch")
	_goto("crouch_down")


func _crouch_down() -> void:
	if phase_frame < 2:
		return
	check("crouch flag set while held", c.is_crouching)
	check_approx("crouch hull height = 40 u", c.body_shape.size.y, 40.0 * U)
	check_approx("crouch hull stays feet-anchored", c.collision_shape.position.y, 20.0 * U)
	check_approx("crouch eye height = 36 u", c.head.position.y, 36.0 * U)
	Input.action_release("player_crouch")
	_goto("crouch_up")


func _crouch_up() -> void:
	if phase_frame < 2:
		return
	check("stood back up with clear headroom", not c.is_crouching)
	check_approx("standing hull height = 56 u", c.body_shape.size.y, 56.0 * U)
	check_approx("standing eye height = 50 u", c.head.position.y, 50.0 * U)
	c.auto_jump = true
	c.velocity = Vector3(8, 0, 0)
	Input.action_press("player_jump")
	_goto("autojump")


func _autojump() -> void:
	if not autojump_started:
		if c.is_on_floor():
			return
		autojump_started = true
		check("held jump starts autojump without a fresh press", c.velocity.y > 0.0)
		return
	if not autojump_landed:
		if not c.is_on_floor():
			return
		autojump_landed = true
		return
	Input.action_release("player_jump")
	c.auto_jump = false
	check("held autojump fires again immediately after landing", not c.is_on_floor())
	check_approx("autojump landing frame skips ground friction and starts a jump",
		c.velocity.y, c.jump_velocity - c.gravity * DT, 1e-4)
	check_approx("autojump preserves landing speed without a friction tick", c.velocity.x, 8.0, 1e-4)
	c.global_position = Vector3(0, 2, 0)
	c.velocity = Vector3(8, -1, 0)
	c.crouch_slide_enabled = true
	Input.action_press("player_crouch")
	_goto("crouch_slide")


func _crouch_slide() -> void:
	if not c.is_crouch_sliding:
		if phase_frame > 2:
			fail("crouch slide did not arm while airborne")
			finish()
		return
	if not crouch_slide_landed:
		if not c.is_on_floor():
			return
		crouch_slide_landed = true
		crouch_slide_landing_speed = c.velocity.x
		return
	Input.action_release("player_crouch")
	c.crouch_slide_enabled = false
	check("armed crouch slide remains active on landing", c.is_crouch_sliding)
	check_approx("crouch slide landing tick applies zero ground friction",
		c.velocity.x, crouch_slide_landing_speed, 1e-4)
	finish()

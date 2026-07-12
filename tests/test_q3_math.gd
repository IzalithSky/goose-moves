extends "res://tests/q3_test.gd"
# Controller math vs the source-verified Q3 reference
# (references/Quake-III-Arena/code/game/bg_pmove.c, docs/q3-movement.md).
# Pure function checks — the controller instance never runs a physics frame.

const CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const U := 0.3048 / 8.0  # metres per Q3 unit

var c


func _ready() -> void:
	c = CONTROLLER_SCENE.instantiate()
	add_child(c)
	c.set_physics_process(false)
	c.set_process(false)


func step() -> void:
	_constants()
	_friction()
	_accelerate()
	_projection()
	_wish_speed()
	finish()


func _constants() -> void:
	check_approx("move_speed = 320 u/s", c.move_speed, 320.0 * U)
	check_approx("gravity = 800 u/s^2", c.gravity, 800.0 * U)
	check_approx("jump_velocity = 270 u/s", c.jump_velocity, 270.0 * U)
	check_approx("stop_speed = 100 u/s", c.stop_speed, 100.0 * U)
	check_approx("step_height = 18 u", c.step_height, 18.0 * U)
	check_approx("ground trace = 0.25 u", c.Q3_GROUND_TRACE_DISTANCE, 0.25 * U)
	check_approx("ground acceleration = 10", c.ground_acceleration, 10.0)
	check_approx("air acceleration = 1", c.air_acceleration, 1.0)
	check_approx("friction = 6", c.friction, 6.0)
	check_approx("water acceleration = 4", c.water_acceleration, 4.0)
	check_approx("water friction = 1", c.water_friction, 1.0)
	check_approx("swim scale = 0.5", c.swim_speed_scale, 0.5)
	check_approx("crouch scale = 0.25", c.crouch_speed_scale, 0.25)
	check_approx("walk scale = 64/127", c.walk_speed_scale, 64.0 / 127.0)
	check_approx("max slope angle from MIN_WALK_NORMAL 0.7",
		cos(deg_to_rad(c.max_slope_angle)), 0.7, 1e-5)


func _friction() -> void:
	c.water_level = 0
	c.water_type = &""

	c.velocity = Vector3(320.0 * U, 0, 0)
	c._apply_friction(DT, true)
	check_approx("ground friction above stopspeed: v *= 1 - friction*dt",
		c.velocity.x, 320.0 * U * (1.0 - 6.0 * DT))

	c.velocity = Vector3(2.0, 0, 0)
	c._apply_friction(DT, true)
	check_approx("below stopspeed: drop = stopspeed*friction*dt",
		c.velocity.x, 2.0 - (100.0 * U) * 6.0 * DT)

	c.velocity = Vector3(3.0, -1.5, 0)
	c._apply_friction(DT, true)
	var factor := (3.0 - (100.0 * U) * 6.0 * DT) / 3.0
	check_approx("walking friction measures horizontal speed only",
		c.velocity.x, 3.0 * factor)
	check_approx("...but scales the vertical component too (PM_Friction)",
		c.velocity.y, -1.5 * factor)

	c.velocity = Vector3(10, 0, 0)
	c._apply_friction(DT, false)
	check_vec3("no friction airborne and dry", c.velocity, Vector3(10, 0, 0), 1e-6)

	c.water_level = 1
	c.velocity = Vector3(320.0 * U, 0, 0)
	c._apply_friction(DT, true)
	check_approx("wading: water friction stacks on ground friction",
		c.velocity.x, 320.0 * U * (1.0 - 6.0 * DT - 1.0 * 1.0 * DT))

	c.water_level = 3
	c.velocity = Vector3(4, 2, 0)
	c._apply_friction(DT, false)
	check_vec3("swimming: drop = speed*waterfriction*level*dt on the full 3D vector",
		c.velocity, Vector3(4, 2, 0) * (1.0 - 3.0 * DT))

	# project extension, not VQ3 (Q3 uses pm_waterfriction for all liquids)
	c.water_type = &"slime"
	c.water_level = 2
	c.velocity = Vector3(4, 0, 0)
	c._apply_friction(DT, false)
	check_approx("slime friction extension: coefficient 12 x level",
		c.velocity.x, 4.0 * (1.0 - 12.0 * 2.0 * DT))

	c.water_level = 0
	c.water_type = &""


func _accelerate() -> void:
	var wish_speed: float = c.move_speed

	c.velocity = Vector3.ZERO
	c._accelerate(Vector3(1, 0, 0), wish_speed, 10.0, DT)
	check_approx("ground accel from rest: accel*dt*wishspeed",
		c.velocity.x, 10.0 * DT * wish_speed)

	c.velocity = Vector3(15, 0, 0)
	c._accelerate(Vector3(1, 0, 0), wish_speed, 10.0, DT)
	check_approx("no accel at or above wishspeed along wishdir", c.velocity.x, 15.0, 1e-6)

	c.velocity = Vector3(wish_speed - 0.05, 0, 0)
	c._accelerate(Vector3(1, 0, 0), wish_speed, 10.0, DT)
	check_approx("accel clamps to the remaining addspeed", c.velocity.x, wish_speed, 1e-5)

	c.velocity = Vector3.ZERO
	c._accelerate(Vector3(1, 0, 0), wish_speed, 1.0, DT)
	check_approx("air accel coefficient 1", c.velocity.x, 1.0 * DT * wish_speed)

	c.velocity = Vector3(0, 0, 20)
	c._accelerate(Vector3(1, 0, 0), wish_speed, 1.0, DT)
	check_approx("cap is on dot(v, wishdir), not |v| — the strafe-jump property",
		c.velocity.x, 1.0 * DT * wish_speed)


func _projection() -> void:
	c.velocity = Vector3(8, -6, 0)
	c._project_velocity_onto_plane(Vector3.UP)
	check_vec3("projection preserves |v| by default (WalkMove renormalize)",
		c.velocity, Vector3(10, 0, 0))

	var normal := Vector3(-0.5, cos(deg_to_rad(30.0)), 0.0)
	c.velocity = Vector3(10, 0, 0)
	c._project_velocity_onto_plane(normal)
	check_approx("slope projection keeps speed", c.velocity.length(), 10.0)
	check_approx("slope projection ends on the plane", c.velocity.dot(normal), 0.0, 1e-4)

	c.velocity = Vector3(3, 0, 0)
	c._project_velocity_onto_plane(Vector3.UP, 12.0)
	check_vec3("explicit speed argument overrides the preserved magnitude",
		c.velocity, Vector3(12, 0, 0))


func _wish_speed() -> void:
	check_approx("wishspeed: zero input", c._get_wish_speed(Vector2.ZERO), 0.0, 1e-6)
	check_approx("wishspeed: single axis = full speed",
		c._get_wish_speed(Vector2(0, 1)), c.move_speed)
	check_approx("wishspeed: diagonal has no sqrt2 distortion (PM_CmdScale)",
		c._get_wish_speed(Vector2(1, 1)), c.move_speed)

	Input.action_press("player_walk")
	check_approx("wishspeed: walk = 64/127 of run (cl_run 0 command values)",
		c._get_wish_speed(Vector2(0, 1)), c.move_speed * 64.0 / 127.0, 1e-3)
	Input.action_release("player_walk")

	Input.action_press("player_crouch")
	check_approx("wishspeed: held vertical input lowers horizontal wishspeed (CmdScale quirk)",
		c._get_wish_speed(Vector2(0, 1)), c.move_speed / sqrt(2.0), 1e-3)
	Input.action_release("player_crouch")

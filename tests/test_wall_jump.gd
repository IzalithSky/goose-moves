extends "res://tests/q3_test.gd"

const CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")

var c
var phase_frame := 0


func _ready() -> void:
	add_static_box(Vector3(12, 1, 12), Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	add_static_box(Vector3(0.5, 6, 8), Transform3D(Basis.IDENTITY, Vector3(0.25, 3, 0)))
	c = CONTROLLER_SCENE.instantiate()
	c.position = Vector3(-1.0, 2.0, 0.0)
	add_child(c)
	c.wall_jump_enabled = true
	c.velocity = Vector3(6.0, -1.0, 0.0)


func step() -> void:
	phase_frame += 1
	if phase_frame == 1:
		Input.action_press("player_special")
	if c.wall_jump_cooldown_remaining <= 0.0:
		if phase_frame > 12:
			Input.action_release("player_special")
			fail("Special did not trigger a nearby airborne wall jump")
			finish()
		return

	Input.action_release("player_special")
	var minimum_speed: float = (
		c.WARSOW_WALK_SPEED * c.Q3_METERS_PER_UNIT + c.move_speed
	) * 0.5
	check("wall jump redirects horizontal velocity away from the wall", c.velocity.x < 0.0)
	check("wall jump enforces Warsow's horizontal speed minimum",
		Vector2(c.velocity.x, c.velocity.z).length() >= minimum_speed - 1e-4)
	check_approx("wall jump applies 330 u/s then one gravity tick",
		c.velocity.y,
		c.WARSOW_WALL_JUMP_UP_SPEED * c.Q3_METERS_PER_UNIT - c.gravity * DT,
		1e-4)
	check_approx("wall jump starts Warsow's 1300 ms cooldown",
		c.wall_jump_cooldown_remaining,
		c.WARSOW_WALL_JUMP_COOLDOWN,
		1e-4)
	finish()

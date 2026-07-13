extends "res://tests/q3_test.gd"

const CONTROLLER_SCENE := preload("res://scenes/platformer_controller.tscn")

var controller
var phase := "settle"
var phase_frame := 0
var run_speed := 0.0
var jump_vertical_previous := 0.0


func _ready() -> void:
	Settings.set_character_controller(Settings.CHARACTER_PLATFORMER)
	add_static_box(Vector3(80.0, 0.2, 30.0), Transform3D(Basis.IDENTITY, Vector3(0.0, -0.1, 0.0)))
	var burning := add_static_box(Vector3(8.0, 0.1, 8.0), Transform3D(Basis.IDENTITY, Vector3(15.0, 0.05, 0.0)))
	burning.set_meta("platformer_surface", &"burning")
	_add_water_volume()
	controller = CONTROLLER_SCENE.instantiate()
	controller.position = Vector3(0.0, 0.1, 0.0)
	add_child(controller)


func step() -> void:
	phase_frame += 1
	call("_" + phase)


func _settle() -> void:
	if phase_frame < 8:
		return
	check("platformer settles on the floor", controller.is_on_floor())
	controller.action = controller.Action.WALKING
	controller.forward_speed = 10.0
	controller._sync_slide_from_forward()
	_goto("coast")


func _coast() -> void:
	check("released input enters decelerating state", controller.action == controller.Action.DECELERATING)
	check_approx("one runtime coast tick applies only configured deceleration",
		controller.forward_speed, 9.5, 0.01)
	Input.action_press("player_forward")
	_goto("run")


func _run() -> void:
	if phase_frame < 30:
		return
	Input.action_release("player_forward")
	check("ground input enters walking action", controller.action == controller.Action.WALKING)
	check("walking builds positive polar speed", controller.forward_speed > 10.0)
	var velocity_direction := Vector2(controller.velocity.x, controller.velocity.z).normalized()
	var facing_direction := Vector2(sin(controller.face_yaw), cos(controller.face_yaw)).normalized()
	check("runtime horizontal velocity follows facing", velocity_direction.dot(facing_direction) > 0.999)
	run_speed = controller.forward_speed
	Input.action_press("player_jump")
	_goto("jump")


func _jump() -> void:
	if phase_frame == 1:
		return
	check("jump input enters an airborne platformer action", controller.action == controller.Action.JUMP)
	var launch_input_speed: float = run_speed - (controller.ground_deceleration * 0.5)
	check_approx("jump launch applies the 0.8 horizontal multiplier once",
		controller.forward_speed, launch_input_speed * 0.8, 0.01)
	check_approx("jump launch applies one base-plus-speed vertical impulse",
		controller.vertical_speed, controller.jump_velocity + (launch_input_speed * 0.25), 0.01)
	jump_vertical_previous = controller.vertical_speed
	_goto("jump_hold")


func _jump_hold() -> void:
	check_approx("held jump does not reapply launch force on frame %d" % phase_frame,
		jump_vertical_previous - controller.vertical_speed, controller.gravity * 0.5, 0.01)
	jump_vertical_previous = controller.vertical_speed
	if phase_frame < 4:
		return
	Input.action_release("player_jump")
	_goto("land")


func _land() -> void:
	if not controller.is_on_floor():
		return
	check("jump returns to a grounded action", not controller._is_air_action(controller.action))
	check("landing arms the double-jump chain", controller.jump_chain == 1)
	controller.global_position = Vector3(15.0, 0.3, 0.0)
	controller.velocity = Vector3.DOWN
	controller.vertical_speed = -4.0
	_goto("burning")


func _burning() -> void:
	if phase_frame < 6:
		return
	if controller.action != controller.Action.LAVA_BOOST:
		if phase_frame < 20:
			return
		fail("burning surface did not trigger lava boost")
		finish()
		return
	check("burning surface selects lava boost", controller.current_surface == &"burning")
	check("lava boost launches upward", controller.vertical_speed > 60.0)
	controller.global_position = Vector3(30.0, 1.0, 0.0)
	controller.velocity = Vector3.ZERO
	controller.forward_speed = 0.0
	controller.vertical_speed = 0.0
	_goto("water")


func _water() -> void:
	if phase_frame < 4:
		return
	check("water volume selects water medium", controller.current_medium == &"water")
	check("water volume enters swimming action", controller.action == controller.Action.SWIMMING)
	check_approx("idle swimmer uses configured buoyancy", controller.vertical_speed, controller.buoyancy, 0.1)
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	finish()


func _goto(next_phase: String) -> void:
	phase = next_phase
	phase_frame = 0


func _add_water_volume() -> void:
	var area := Area3D.new()
	area.position = Vector3(30.0, 1.5, 0.0)
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("platformer_medium", &"water")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 4.0, 8.0)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

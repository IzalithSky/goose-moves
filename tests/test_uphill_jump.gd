extends "res://tests/q3_test.gd"

const CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")

var c
var phase := "settle"
var phase_frame := 0


func _ready() -> void:
	add_static_box(Vector3(200, 1, 12),
		Transform3D(Basis(Vector3.BACK, deg_to_rad(44.0)), Vector3.ZERO))
	c = CONTROLLER_SCENE.instantiate()
	c.position = Vector3(-20, -17, 0)
	add_child(c)


func _goto(next: String) -> void:
	phase = next
	phase_frame = 0


func step() -> void:
	phase_frame += 1
	call("_" + phase)


func _settle() -> void:
	if phase_frame < 30:
		return
	check("settled on the walkable 44 degree ramp", c.is_on_floor())
	var uphill := Vector3.UP.slide(c.get_floor_normal()).normalized()
	c.velocity = uphill * 12.0
	Input.action_press("player_right")
	Input.action_press("player_jump")
	_goto("jump")


func _jump() -> void:
	if phase_frame == 1:
		Input.action_release("player_right")
		return
	Input.action_release("player_jump")
	check_approx("jump always works while moving uphill",
		c.velocity.y, c.jump_velocity - c.gravity * DT, 1e-4)
	check("uphill jump leaves the ramp", not c.is_on_floor())
	finish()

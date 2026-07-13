extends "res://tests/q3_test.gd"
# Warsow ramp/ledge double jump: grounded upward carry is added to jump speed,
# and carry above 180 u/s forces airborne instead (gs_pmove.cpp:1030, :1171).

const CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")

var c
var phase := "settle"
var phase_frame := 0
var jump_entry_velocity_y := 0.0
var launch_velocity := Vector3.ZERO


func _ready() -> void:
	add_static_box(Vector3(200, 1, 12),
		Transform3D(Basis(Vector3.BACK, deg_to_rad(44.0)), Vector3.ZERO))
	c = CONTROLLER_SCENE.instantiate()
	c.position = Vector3(-20, -17, 0)
	add_child(c)
	c.movement_mode = c.MovementMode.WARSOW_CLASSIC


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
	c.velocity = uphill * 5.0
	Input.action_press("player_jump")
	_goto("double_jump")


func _double_jump() -> void:
	if phase_frame == 1:
		# The controller consumes the press this frame; the grounded uphill
		# carry it sees is last frame's on-plane velocity.
		jump_entry_velocity_y = c.velocity.y
		check("grounded upward carry sits inside the 180 u/s window",
			jump_entry_velocity_y > 0.0
			and jump_entry_velocity_y <= c.WARSOW_GROUND_DETACH_SPEED * c.Q3_METERS_PER_UNIT)
		return
	Input.action_release("player_jump")
	check_approx("Warsow jump adds jump speed to the grounded upward carry",
		c.velocity.y,
		jump_entry_velocity_y + c.jump_velocity - c.gravity * DT,
		1e-4)
	check("double jump leaves the ramp", not c.is_on_floor())
	_goto("resettle")


func _resettle() -> void:
	if phase_frame == 1:
		c.velocity = Vector3.ZERO
	if not c.is_on_floor():
		if phase_frame > 240:
			fail("did not resettle on the ramp")
			finish()
		return
	var uphill := Vector3.UP.slide(c.get_floor_normal()).normalized()
	launch_velocity = uphill * 12.0
	check("launch carry exceeds the 180 u/s detach bound",
		launch_velocity.y > c.WARSOW_GROUND_DETACH_SPEED * c.Q3_METERS_PER_UNIT)
	c.velocity = launch_velocity
	Input.action_press("player_jump")
	_goto("detach")


func _detach() -> void:
	if phase_frame < 3:
		return
	Input.action_release("player_jump")
	check("carry above 180 u/s forces airborne — grounded jump does not fire",
		c.velocity.y < launch_velocity.y)
	check("detached carry keeps rising ballistically", c.velocity.y > 0.0)
	finish()

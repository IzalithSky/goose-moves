extends "res://tests/q3_test.gd"

const CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const RAMP_ANGLE := 55.0

var c
var enabled_run := false
var run_frame := 0
var disabled_velocity_y := 0.0


func _ready() -> void:
	add_static_box(
		Vector3(20, 1, 12),
		Transform3D(Basis(Vector3.BACK, deg_to_rad(RAMP_ANGLE)), Vector3.ZERO),
	)
	c = CONTROLLER_SCENE.instantiate()
	add_child(c)
	_start_run(false)


func step() -> void:
	run_frame += 1
	var ramp_normal := _get_steep_ramp_normal()
	if ramp_normal != Vector3.ZERO:
		if not enabled_run:
			disabled_velocity_y = c.velocity.y
			check("disabled steep-ramp launch keeps the normal airborne vertical result",
				disabled_velocity_y <= 0.0)
			_start_run(true)
			return
		check("test fixture contacts a non-walkable upward slope",
			ramp_normal.y >= c.WARSOW_PLANE_INTERACTION_EPSILON
			and ramp_normal.y < cos(c.floor_max_angle))
		check("enabled steep-ramp collision launches upward", c.velocity.y > 0.0)
		check("profile toggle changes the steep-ramp vertical response",
			c.velocity.y > disabled_velocity_y)
		finish()
		return
	if run_frame > 60:
		fail("never contacted the steep ramp")
		finish()


func _start_run(enabled: bool) -> void:
	enabled_run = enabled
	run_frame = 0
	c.ramp_launch_enabled = enabled
	c.global_position = Vector3(-3.0, 0.5, 0.0)
	c.velocity = Vector3(12.0, -1.0, 0.0)


func _get_steep_ramp_normal() -> Vector3:
	for collision_index in c.get_slide_collision_count():
		var plane_normal: Vector3 = c.get_slide_collision(collision_index).get_normal()
		if (
			plane_normal.y >= c.WARSOW_PLANE_INTERACTION_EPSILON
			and plane_normal.y < cos(c.floor_max_angle)
		):
			return plane_normal
	return Vector3.ZERO

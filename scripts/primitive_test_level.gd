extends Node3D

const SPECTATOR_CAMERA_SCENE := preload("res://scenes/controllers/spectator_camera.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/menus/pause_menu.tscn")


func _ready() -> void:
	var spectator_camera := SPECTATOR_CAMERA_SCENE.instantiate() as Camera3D
	spectator_camera.position = Vector3(22.0, 18.0, 24.0)
	spectator_camera.rotation_degrees = Vector3(-27.84, 40.24, 0.0)
	add_child(spectator_camera)
	add_child(PAUSE_MENU_SCENE.instantiate())

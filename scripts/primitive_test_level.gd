extends Node3D

const Q3_CHARACTER_CONTROLLER_SCENE := preload("res://scenes/controllers/q3_character_controller.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/menus/pause_menu.tscn")


func _ready() -> void:
	var player := Q3_CHARACTER_CONTROLLER_SCENE.instantiate() as CharacterBody3D
	player.position = Vector3(0.0, 1.0, 20.0)
	add_child(player)
	add_child(PAUSE_MENU_SCENE.instantiate())

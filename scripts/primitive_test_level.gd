extends Node3D

const Q3_CHARACTER_CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const SPECTATOR_CAMERA_SCENE := preload("res://scenes/spectator_camera.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const DEFAULT_Q3_POSITION := Vector3(0.0, 1.0, 20.0)
const Q3_STANDING_EYE_RATIO := (
	Q3CharacterController.Q3_STANDING_EYE_HEIGHT
	/ Q3CharacterController.Q3_STANDING_HULL_HEIGHT
)

var active_character: Node3D
var active_character_id := ""


func _ready() -> void:
	Settings.settings_changed.connect(on_settings_changed)
	_spawn_character(Settings.character_controller, _default_view_transform())
	add_child(PAUSE_MENU_SCENE.instantiate())


func on_settings_changed() -> void:
	if active_character_id != Settings.character_controller:
		_swap_character(Settings.character_controller)


func _swap_character(character_id: String) -> void:
	var view_transform := _active_view_transform()
	if active_character:
		remove_child(active_character)
		active_character.queue_free()
		active_character = null
	_spawn_character(character_id, view_transform)


func _spawn_character(character_id: String, view_transform: Transform3D) -> void:
	active_character_id = Settings.CHARACTER_SPECTATOR if character_id == Settings.CHARACTER_SPECTATOR else Settings.CHARACTER_Q3
	if active_character_id == Settings.CHARACTER_SPECTATOR:
		active_character = SPECTATOR_CAMERA_SCENE.instantiate() as Node3D
		active_character.transform = view_transform
	else:
		active_character = Q3_CHARACTER_CONTROLLER_SCENE.instantiate() as Node3D
		_place_q3_at_view(active_character, view_transform)
	add_child(active_character)
	if get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _default_view_transform() -> Transform3D:
	var view_transform := Transform3D.IDENTITY
	view_transform.origin = DEFAULT_Q3_POSITION + (Vector3.UP * _get_q3_eye_height())
	return view_transform


func _active_view_transform() -> Transform3D:
	if not active_character:
		return _default_view_transform()
	if active_character_id == Settings.CHARACTER_Q3:
		var q3_character := active_character as Q3CharacterController
		var camera := (
			q3_character.third_person_camera
			if q3_character.third_person_enabled
			else q3_character.camera
		)
		if camera:
			return camera.global_transform
	return active_character.global_transform


func _place_q3_at_view(character: Node3D, view_transform: Transform3D) -> void:
	var euler := view_transform.basis.get_euler()
	character.position = view_transform.origin - (Vector3.UP * _get_q3_eye_height())
	character.rotation = Vector3(0.0, euler.y, 0.0)
	var head := character.get_node_or_null("Head") as Node3D
	if head:
		head.rotation = Vector3(euler.x, 0.0, 0.0)


func _get_q3_eye_height() -> float:
	return (
		Settings.get_controller_setting("character_size_y", Settings.CHARACTER_Q3)
		* Q3_STANDING_EYE_RATIO
	)

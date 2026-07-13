extends Node3D

const Q3_CHARACTER_CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const PLATFORMER_CONTROLLER_SCENE := preload("res://scenes/platformer_controller.tscn")
const SPECTATOR_CAMERA_SCENE := preload("res://scenes/spectator_camera.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const DEFAULT_Q3_POSITION := Vector3(0.0, 1.0, 20.0)
const LABELED_FIXTURE_ROOTS := [
	"Cubes",
	"Stairs",
	"Ramps",
	"Kerbs",
	"LimitSlopes",
	"SurfaceFlags",
	"PlatformerSurfaces",
	"SurfaceClassSlopes",
	"Volumes",
]
const Q3_STANDING_EYE_RATIO := (
	Q3CharacterController.Q3_STANDING_EYE_HEIGHT
	/ Q3CharacterController.Q3_STANDING_HULL_HEIGHT
)

var active_character: Node3D
var active_character_id := ""


func _ready() -> void:
	_add_fixture_labels()
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
	active_character_id = character_id if character_id in Settings.CONTROLLER_SECTIONS else Settings.CHARACTER_Q3
	if active_character_id == Settings.CHARACTER_SPECTATOR:
		active_character = SPECTATOR_CAMERA_SCENE.instantiate() as Node3D
		active_character.transform = view_transform
	elif active_character_id == Settings.CHARACTER_PLATFORMER:
		active_character = PLATFORMER_CONTROLLER_SCENE.instantiate() as Node3D
		active_character.call("place_at_view", view_transform)
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
	if active_character_id == Settings.CHARACTER_PLATFORMER:
		var platformer_camera := active_character.call("get_view_camera") as Camera3D
		return platformer_camera.global_transform
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


func _add_fixture_labels() -> void:
	var labels_root := $FixtureLabels as Node3D
	for root_path in LABELED_FIXTURE_ROOTS:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		for fixture in root.get_children():
			if fixture is CSGBox3D or fixture is Area3D:
				_add_fixture_label(labels_root, fixture as Node3D)


func _add_fixture_label(labels_root: Node3D, fixture: Node3D) -> void:
	var label := Label3D.new()
	label.name = "%sLabel" % fixture.name
	label.text = _fixture_label_text(fixture)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.no_depth_test = false
	label.pixel_size = 0.012
	label.font_size = 42
	label.outline_size = 10
	label.modulate = Color(1.0, 0.96, 0.78, 1.0)
	label.set_meta("fixture_path", fixture.get_path())
	labels_root.add_child(label)
	label.global_position = fixture.global_position + (Vector3.UP * _fixture_label_height(fixture))


func _fixture_label_text(fixture: Node) -> String:
	return _humanize_name(str(fixture.name))


func _fixture_label_height(fixture: Node3D) -> float:
	if fixture is CSGBox3D:
		var box := fixture as CSGBox3D
		var half_size := box.size * 0.5
		var fixture_basis := box.global_transform.basis
		return (
			absf(fixture_basis.x.y) * half_size.x
			+ absf(fixture_basis.y.y) * half_size.y
			+ absf(fixture_basis.z.y) * half_size.z
			+ 0.65
		)
	if fixture is Area3D:
		var shape_node := fixture.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return (shape_node.shape as BoxShape3D).size.y * 0.5 + 0.65
	return 1.0


func _humanize_name(value: String) -> String:
	var result := ""
	for index in value.length():
		var character := value[index]
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			result += " "
		result += character
	return result.replace("_", " ")

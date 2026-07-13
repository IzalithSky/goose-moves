extends Node

signal bindings_changed
signal actions_changed

const SAVE_PATH := "user://keybindings.cfg"
const SECTION := "bindings"
const MAX_BINDINGS := 2
const CHARACTER_Q3 := "q3"
const CHARACTER_SPECTATOR := "spectator"
const SECTIONS := {
	CHARACTER_Q3: "bindings_q3",
	CHARACTER_SPECTATOR: "bindings_spectator",
}
const Q3_ACTIONS: Array[String] = [
	"player_forward",
	"player_back",
	"player_left",
	"player_right",
	"player_jump",
	"player_crouch",
	"player_walk",
]
const SPECTATOR_ACTIONS: Array[String] = [
	"player_forward",
	"player_back",
	"player_left",
	"player_right",
	"player_jump",
	"player_crouch",
]
const ALL_ACTIONS: Array[String] = [
	"player_forward",
	"player_back",
	"player_left",
	"player_right",
	"player_jump",
	"player_crouch",
	"player_walk",
]
const Q3_ACTION_LABELS := {
	"player_forward": "Move Forward",
	"player_back": "Move Back",
	"player_left": "Move Left",
	"player_right": "Move Right",
	"player_jump": "Jump",
	"player_crouch": "Crouch",
	"player_walk": "Slow Walk",
}
const SPECTATOR_ACTION_LABELS := {
	"player_forward": "Move Forward",
	"player_back": "Move Back",
	"player_left": "Move Left",
	"player_right": "Move Right",
	"player_jump": "Move Up",
	"player_crouch": "Move Down",
}
const DEFAULT_BINDINGS := {
	"player_forward": [KEY_W, -1],
	"player_back": [KEY_S, -1],
	"player_left": [KEY_A, -1],
	"player_right": [KEY_D, -1],
	"player_jump": [KEY_SPACE, -1],
	"player_crouch": [KEY_CTRL, -1],
	"player_walk": [KEY_SHIFT, -1],
}

var bindings_by_controller: Dictionary = {}
var active_controller_id := CHARACTER_Q3


func _ready() -> void:
	reset_to_defaults(false)
	load_bindings()
	apply_to_input_map()
	Settings.settings_changed.connect(on_settings_changed)


func get_actions(controller_id := "") -> Array[String]:
	var normalized_controller := _normalize_controller(active_controller_id if controller_id.is_empty() else controller_id)
	if normalized_controller == CHARACTER_SPECTATOR:
		return SPECTATOR_ACTIONS.duplicate()
	return Q3_ACTIONS.duplicate()


func get_action_label(action: String, controller_id := "") -> String:
	var normalized_controller := _normalize_controller(active_controller_id if controller_id.is_empty() else controller_id)
	if normalized_controller == CHARACTER_SPECTATOR:
		return str(SPECTATOR_ACTION_LABELS.get(action, action))
	return str(Q3_ACTION_LABELS.get(action, action))


func get_bindings(action: String, controller_id := "") -> Array:
	var normalized_controller := _normalize_controller(active_controller_id if controller_id.is_empty() else controller_id)
	var bindings := bindings_by_controller.get(normalized_controller, {}) as Dictionary
	return (bindings.get(action, [-1, -1]) as Array).duplicate(true)


func set_binding(action: String, slot: int, binding: Variant) -> void:
	if not action in get_actions() or slot < 0 or slot >= MAX_BINDINGS:
		return

	var normalized: Variant = _normalize_binding(binding)
	if normalized is int and int(normalized) < 0:
		return
	var slots := get_bindings(action)
	slots[slot] = normalized
	var bindings := bindings_by_controller[active_controller_id] as Dictionary
	bindings[action] = slots
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func clear_action(action: String) -> void:
	if not action in get_actions():
		return
	var bindings := bindings_by_controller[active_controller_id] as Dictionary
	bindings[action] = [-1, -1]
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func reset_to_defaults(save := true) -> void:
	bindings_by_controller = {}
	for controller_id in SECTIONS:
		var bindings := {}
		for action in get_actions(controller_id):
			bindings[action] = (DEFAULT_BINDINGS[action] as Array).duplicate(true)
		bindings_by_controller[controller_id] = bindings
	active_controller_id = _normalize_controller(Settings.character_controller)
	apply_to_input_map()
	if save:
		save_bindings()
		bindings_changed.emit()


func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	if config.has_section(SECTION):
		_load_controller_bindings(config, SECTION, CHARACTER_Q3)
	for controller_id in SECTIONS:
		_load_controller_bindings(config, str(SECTIONS[controller_id]), controller_id)


func save_bindings() -> void:
	var config := ConfigFile.new()
	for controller_id in SECTIONS:
		var section := str(SECTIONS[controller_id])
		for action in get_actions(controller_id):
			config.set_value(section, action, get_bindings(action, controller_id))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save keybindings: %s" % error_string(error))


func apply_to_input_map() -> void:
	for action in ALL_ACTIONS:
		if not InputMap.has_action(action):
			push_warning("Input action missing from project settings: %s" % action)
			continue
		InputMap.action_erase_events(action)
	for action in get_actions():
		for binding in get_bindings(action):
			var input_event := _binding_to_input_event(binding)
			if input_event != null:
				InputMap.action_add_event(action, input_event)


func on_settings_changed() -> void:
	var controller_id := _normalize_controller(Settings.character_controller)
	if active_controller_id == controller_id:
		return
	active_controller_id = controller_id
	apply_to_input_map()
	actions_changed.emit()


func _normalize_binding(binding: Variant) -> Variant:
	if binding is Dictionary and str((binding as Dictionary).get("type", "")) == "mouse":
		var button_index := int((binding as Dictionary).get("button_index", -1))
		if button_index > 0:
			return {
				"type": "mouse",
				"button_index": button_index,
			}
	if binding is int and int(binding) > 0:
		return int(binding)
	return -1


func _binding_to_input_event(binding: Variant) -> InputEvent:
	if binding is int and int(binding) > 0:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(binding) as Key
		return key_event
	if binding is Dictionary and str((binding as Dictionary).get("type", "")) == "mouse":
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int((binding as Dictionary).get("button_index", -1)) as MouseButton
		return mouse_event
	return null


func _load_controller_bindings(config: ConfigFile, section: String, controller_id: String) -> void:
	if not config.has_section(section):
		return
	var bindings := bindings_by_controller[controller_id] as Dictionary
	for action in get_actions(controller_id):
		if not config.has_section_key(section, action):
			continue
		var saved: Variant = config.get_value(section, action)
		if saved is Array:
			var saved_slots := saved as Array
			var slots: Array = [-1, -1]
			for slot in mini(saved_slots.size(), MAX_BINDINGS):
				slots[slot] = _normalize_binding(saved_slots[slot])
			bindings[action] = slots
		elif saved is int:
			bindings[action] = [_normalize_binding(saved), -1]


func _normalize_controller(value: String) -> String:
	if value == CHARACTER_SPECTATOR:
		return CHARACTER_SPECTATOR
	return CHARACTER_Q3

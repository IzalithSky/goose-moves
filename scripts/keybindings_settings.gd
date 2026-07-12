extends Node

signal bindings_changed

const SAVE_PATH := "user://keybindings.cfg"
const SECTION := "bindings"
const MAX_BINDINGS := 2
const ACTIONS: Array[String] = [
	"player_forward",
	"player_back",
	"player_left",
	"player_right",
	"player_jump",
	"player_crouch",
	"player_walk",
]
const ACTION_LABELS := {
	"player_forward": "Move Forward",
	"player_back": "Move Back",
	"player_left": "Move Left",
	"player_right": "Move Right",
	"player_jump": "Jump",
	"player_crouch": "Crouch",
	"player_walk": "Slow Walk",
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

var bindings: Dictionary = {}


func _ready() -> void:
	reset_to_defaults(false)
	load_bindings()
	apply_to_input_map()


func get_bindings(action: String) -> Array:
	return (bindings.get(action, [-1, -1]) as Array).duplicate(true)


func set_binding(action: String, slot: int, binding: Variant) -> void:
	if not action in ACTIONS or slot < 0 or slot >= MAX_BINDINGS:
		return

	var normalized: Variant = _normalize_binding(binding)
	if normalized is int and int(normalized) < 0:
		return
	var slots := get_bindings(action)
	slots[slot] = normalized
	bindings[action] = slots
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func clear_action(action: String) -> void:
	if not action in ACTIONS:
		return
	bindings[action] = [-1, -1]
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func reset_to_defaults(save := true) -> void:
	bindings = DEFAULT_BINDINGS.duplicate(true)
	apply_to_input_map()
	if save:
		save_bindings()
		bindings_changed.emit()


func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	for action in ACTIONS:
		if not config.has_section_key(SECTION, action):
			continue
		var saved: Variant = config.get_value(SECTION, action)
		if saved is Array:
			var saved_slots := saved as Array
			var slots: Array = [-1, -1]
			for slot in mini(saved_slots.size(), MAX_BINDINGS):
				slots[slot] = _normalize_binding(saved_slots[slot])
			bindings[action] = slots
		elif saved is int:
			bindings[action] = [_normalize_binding(saved), -1]


func save_bindings() -> void:
	var config := ConfigFile.new()
	for action in ACTIONS:
		config.set_value(SECTION, action, get_bindings(action))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save keybindings: %s" % error_string(error))


func apply_to_input_map() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			push_warning("Input action missing from project settings: %s" % action)
			continue
		InputMap.action_erase_events(action)
		for binding in get_bindings(action):
			var input_event := _binding_to_input_event(binding)
			if input_event != null:
				InputMap.action_add_event(action, input_event)


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

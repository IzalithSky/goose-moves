extends Node

signal bindings_changed

const SAVE_PATH := "user://keybindings.cfg"
const SECTION := "bindings"
const ACTIONS: Array[String] = [
	"spectator_forward",
	"spectator_back",
	"spectator_left",
	"spectator_right",
	"spectator_up",
	"spectator_down",
]
const ACTION_LABELS := {
	"spectator_forward": "Move Forward",
	"spectator_back": "Move Back",
	"spectator_left": "Move Left",
	"spectator_right": "Move Right",
	"spectator_up": "Move Up",
	"spectator_down": "Move Down",
}
const DEFAULT_BINDINGS := {
	"spectator_forward": KEY_W,
	"spectator_back": KEY_S,
	"spectator_left": KEY_A,
	"spectator_right": KEY_D,
	"spectator_up": KEY_R,
	"spectator_down": KEY_F,
}

var bindings: Dictionary = {}


func _ready() -> void:
	reset_to_defaults(false)
	load_bindings()
	apply_to_input_map()


func get_binding(action: String) -> int:
	return int(bindings.get(action, -1))


func set_binding(action: String, keycode: int) -> void:
	if not action in ACTIONS or keycode <= 0:
		return
	bindings[action] = keycode
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func reset_to_defaults(save := true) -> void:
	bindings = DEFAULT_BINDINGS.duplicate()
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
		var saved_value := int(config.get_value(SECTION, action, -1))
		if saved_value > 0:
			bindings[action] = saved_value


func save_bindings() -> void:
	var config := ConfigFile.new()
	for action in ACTIONS:
		config.set_value(SECTION, action, get_binding(action))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save keybindings: %s" % error_string(error))


func apply_to_input_map() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			push_warning("Input action missing from project settings: %s" % action)
			continue
		InputMap.action_erase_events(action)
		var keycode := get_binding(action)
		if keycode <= 0:
			continue
		var input_event := InputEventKey.new()
		input_event.physical_keycode = keycode as Key
		InputMap.action_add_event(action, input_event)

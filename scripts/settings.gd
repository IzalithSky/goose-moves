extends Node

signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_MOUSE_SENSITIVITY := 0.003
const DEFAULT_FOV := 100.0
const MIN_FOV := 60.0
const MAX_FOV := 140.0
const CHARACTER_Q3 := "q3"
const CHARACTER_SPECTATOR := "spectator"
const CONTROLLER_SECTIONS := {
	CHARACTER_Q3: "controller_q3",
	CHARACTER_SPECTATOR: "controller_spectator",
}
const CONTROLLER_LABELS := {
	CHARACTER_Q3: "Q3",
	CHARACTER_SPECTATOR: "Spectator",
}
const Q3_SETTING_DEFS: Array[Dictionary] = [
	{"key": "fov", "label": "Field of view", "default": DEFAULT_FOV, "min": MIN_FOV, "max": MAX_FOV, "step": 1.0, "format": "%.0f°", "control": "slider"},
	{"key": "mouse_sensitivity", "label": "Mouse sensitivity", "default": DEFAULT_MOUSE_SENSITIVITY, "min": 0.001, "max": 0.02, "step": 0.001, "format": "%.3f", "control": "slider"},
	{"key": "move_speed", "label": "Move speed", "default": 320.0 * 0.3048 / 8.0, "min": 0.0, "max": 30.0, "step": 0.1, "format": "%.2f"},
	{"key": "ground_acceleration", "label": "Ground acceleration", "default": 10.0, "min": 0.0, "max": 40.0, "step": 0.1, "format": "%.1f"},
	{"key": "air_acceleration", "label": "Air acceleration", "default": 1.0, "min": 0.0, "max": 10.0, "step": 0.1, "format": "%.1f"},
	{"key": "friction", "label": "Friction", "default": 6.0, "min": 0.0, "max": 20.0, "step": 0.1, "format": "%.1f"},
	{"key": "stop_speed", "label": "Stop speed", "default": 100.0 * 0.3048 / 8.0, "min": 0.0, "max": 15.0, "step": 0.1, "format": "%.2f"},
	{"key": "gravity", "label": "Gravity", "default": 800.0 * 0.3048 / 8.0, "min": 0.0, "max": 80.0, "step": 0.1, "format": "%.2f"},
	{"key": "jump_velocity", "label": "Jump velocity", "default": 270.0 * 0.3048 / 8.0, "min": 0.0, "max": 30.0, "step": 0.1, "format": "%.2f"},
	{"key": "step_height", "label": "Step height", "default": 18.0 * 0.3048 / 8.0, "min": 0.0, "max": 2.0, "step": 0.01, "format": "%.2f"},
	{"key": "max_slope_angle", "label": "Max slope angle", "default": 45.572996, "min": 0.0, "max": 89.0, "step": 0.1, "format": "%.1f°"},
	{"key": "crouch_speed_scale", "label": "Crouch speed scale", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01, "format": "%.2f"},
	{"key": "walk_speed_scale", "label": "Walk speed scale", "default": 64.0 / 127.0, "min": 0.0, "max": 1.0, "step": 0.01, "format": "%.2f"},
	{"key": "swim_speed_scale", "label": "Swim speed scale", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01, "format": "%.2f"},
	{"key": "water_acceleration", "label": "Water acceleration", "default": 4.0, "min": 0.0, "max": 20.0, "step": 0.1, "format": "%.1f"},
	{"key": "water_friction", "label": "Water friction", "default": 1.0, "min": 0.0, "max": 20.0, "step": 0.1, "format": "%.1f"},
	{"key": "slime_friction", "label": "Slime friction", "default": 12.0, "min": 0.0, "max": 40.0, "step": 0.1, "format": "%.1f"},
]
const SPECTATOR_SETTING_DEFS: Array[Dictionary] = [
	{"key": "fov", "label": "Field of view", "default": DEFAULT_FOV, "min": MIN_FOV, "max": MAX_FOV, "step": 1.0, "format": "%.0f°", "control": "slider"},
	{"key": "mouse_sensitivity", "label": "Mouse sensitivity", "default": DEFAULT_MOUSE_SENSITIVITY, "min": 0.001, "max": 0.02, "step": 0.001, "format": "%.3f", "control": "slider"},
	{"key": "move_speed", "label": "Move speed", "default": 12.0, "min": 0.0, "max": 50.0, "step": 0.1, "format": "%.2f"},
]

var fullscreen := false
var character_controller := CHARACTER_Q3
var controller_settings: Dictionary = {}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	fullscreen = false
	character_controller = CHARACTER_Q3
	_reset_controller_settings()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		fullscreen = bool(config.get_value(SECTION, "fullscreen", false))
		character_controller = _normalize_character_controller(str(config.get_value(SECTION, "character_controller", CHARACTER_Q3)))
		_migrate_global_controller_settings(config)
		_load_controller_settings(config)
	apply_window_mode()


func set_controller_setting(key: String, value: float, controller_id := "") -> void:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var def := _get_setting_def(normalized_controller, key)
	if def.is_empty():
		return
	var settings := controller_settings[normalized_controller] as Dictionary
	settings[key] = clampf(value, float(def["min"]), float(def["max"]))
	save_settings()
	settings_changed.emit()


func get_controller_setting(key: String, controller_id := "") -> float:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var settings := controller_settings.get(normalized_controller, {}) as Dictionary
	var def := _get_setting_def(normalized_controller, key)
	return float(settings.get(key, def.get("default", 0.0)))


func get_controller_setting_defs(controller_id := "") -> Array[Dictionary]:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	if normalized_controller == CHARACTER_SPECTATOR:
		return SPECTATOR_SETTING_DEFS
	return Q3_SETTING_DEFS


func get_character_label(controller_id := "") -> String:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	return str(CONTROLLER_LABELS[normalized_controller])


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_window_mode()
	save_settings()
	settings_changed.emit()


func set_character_controller(value: String) -> void:
	var normalized := _normalize_character_controller(value)
	if character_controller == normalized:
		return
	character_controller = normalized
	save_settings()
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "character_controller", character_controller)
	for controller_id in CONTROLLER_SECTIONS:
		var section := str(CONTROLLER_SECTIONS[controller_id])
		var settings := controller_settings[controller_id] as Dictionary
		for def in get_controller_setting_defs(controller_id):
			var key := str(def["key"])
			config.set_value(section, key, settings[key])
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save settings: %s" % error_string(error))


func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)


func _normalize_character_controller(value: String) -> String:
	if value == CHARACTER_SPECTATOR:
		return CHARACTER_SPECTATOR
	return CHARACTER_Q3


func _reset_controller_settings() -> void:
	controller_settings = {}
	for controller_id in CONTROLLER_SECTIONS:
		var settings := {}
		for def in get_controller_setting_defs(controller_id):
			settings[str(def["key"])] = float(def["default"])
		controller_settings[controller_id] = settings


func _load_controller_settings(config: ConfigFile) -> void:
	for controller_id in CONTROLLER_SECTIONS:
		var section := str(CONTROLLER_SECTIONS[controller_id])
		var settings := controller_settings[controller_id] as Dictionary
		for def in get_controller_setting_defs(controller_id):
			var key := str(def["key"])
			if config.has_section_key(section, key):
				settings[key] = clampf(float(config.get_value(section, key, def["default"])), float(def["min"]), float(def["max"]))


func _migrate_global_controller_settings(config: ConfigFile) -> void:
	if config.has_section_key(SECTION, "mouse_sensitivity"):
		var sensitivity := clampf(float(config.get_value(SECTION, "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)), 0.001, 0.02)
		(controller_settings[CHARACTER_Q3] as Dictionary)["mouse_sensitivity"] = sensitivity
		(controller_settings[CHARACTER_SPECTATOR] as Dictionary)["mouse_sensitivity"] = sensitivity
	if config.has_section_key(SECTION, "fov"):
		(controller_settings[CHARACTER_Q3] as Dictionary)["fov"] = clampf(float(config.get_value(SECTION, "fov", DEFAULT_FOV)), MIN_FOV, MAX_FOV)
		(controller_settings[CHARACTER_SPECTATOR] as Dictionary)["fov"] = clampf(float(config.get_value(SECTION, "fov", DEFAULT_FOV)), MIN_FOV, MAX_FOV)


func _get_setting_def(controller_id: String, key: String) -> Dictionary:
	for def in get_controller_setting_defs(controller_id):
		if str(def["key"]) == key:
			return def
	return {}

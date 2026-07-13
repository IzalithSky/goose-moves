extends Node

signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const PRESET_SAVE_VERSION := 1
const BUILTIN_PRESETS_DIR := "res://data/settings_presets"
const USER_PRESETS_DIR := "user://settings_presets"
const DEFAULT_PRESET_ID := "default"
const SOURCE_BUILTIN := "builtin"
const SOURCE_USER := "user"
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
var selected_presets: Dictionary = {}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	fullscreen = false
	character_controller = CHARACTER_Q3
	_reset_controller_settings()
	_reset_selected_presets()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		fullscreen = bool(config.get_value(SECTION, "fullscreen", false))
		character_controller = _normalize_character_controller(str(config.get_value(SECTION, "character_controller", CHARACTER_Q3)))
		_migrate_global_controller_settings(config)
		_load_controller_settings(config)
		_load_selected_presets(config)
		_apply_selected_presets()
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


func preset_path(source: String, id: String, controller_id := "") -> String:
	_ensure_user_preset_dir()
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var root_dir := BUILTIN_PRESETS_DIR if source == SOURCE_BUILTIN else USER_PRESETS_DIR
	var dir := "%s/%s" % [root_dir, normalized_controller]
	return "%s/%s.json" % [dir, id]


func list_presets(controller_id := "") -> Array[Dictionary]:
	_ensure_user_preset_dir()
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var entries: Array[Dictionary] = []
	_append_preset_entries(entries, SOURCE_BUILTIN, "%s/%s" % [BUILTIN_PRESETS_DIR, normalized_controller], normalized_controller)
	_append_preset_entries(entries, SOURCE_USER, "%s/%s" % [USER_PRESETS_DIR, normalized_controller], normalized_controller)
	return entries


func load_preset(source: String, id: String, controller_id := "") -> Dictionary:
	return _read_preset_json(preset_path(source, id, controller_id))


func apply_preset(payload: Dictionary, controller_id := "") -> bool:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	if not _apply_preset_values(payload, normalized_controller):
		return false
	save_settings()
	settings_changed.emit()
	return true


func apply_preset_entry(source: String, id: String, controller_id := "") -> bool:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var payload := load_preset(source, id, normalized_controller)
	if payload.is_empty() or not _apply_preset_values(payload, normalized_controller):
		return false
	selected_presets[normalized_controller] = {
		"source": source,
		"id": id,
	}
	save_settings()
	settings_changed.emit()
	return true


func get_selected_preset(controller_id := "") -> Dictionary:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	return (selected_presets.get(normalized_controller, {}) as Dictionary).duplicate(true)


func current_preset_payload(display_name := "Custom", controller_id := "") -> Dictionary:
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var values := {}
	var settings := controller_settings[normalized_controller] as Dictionary
	for def in get_controller_setting_defs(normalized_controller):
		var key := str(def["key"])
		values[key] = float(settings[key])
	return {
		"version": PRESET_SAVE_VERSION,
		"name": display_name,
		"controller": normalized_controller,
		"settings": values,
		"keybindings": KeybindingsSettings.get_bindings_payload(normalized_controller),
	}


func save_user_preset(display_name: String, controller_id := "") -> Dictionary:
	_ensure_user_preset_dir()
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var clean_name := display_name.strip_edges()
	var id := sanitize_preset_id(clean_name)
	if id.is_empty():
		push_error("Cannot save settings preset with empty name.")
		return {}

	var payload := current_preset_payload(clean_name, normalized_controller)
	payload["source"] = SOURCE_USER
	payload["id"] = id
	var file := FileAccess.open(preset_path(SOURCE_USER, id, normalized_controller), FileAccess.WRITE)
	if file == null:
		push_error("Could not save settings preset %s (error %s)." % [id, FileAccess.get_open_error()])
		return {}
	file.store_string(JSON.stringify(payload, "\t"))
	selected_presets[normalized_controller] = {
		"source": SOURCE_USER,
		"id": id,
	}
	save_settings()
	return {"source": SOURCE_USER, "id": id, "name": clean_name, "controller": normalized_controller}


func delete_user_preset(id: String, controller_id := "") -> Error:
	_ensure_user_preset_dir()
	var normalized_controller := _normalize_character_controller(character_controller if controller_id.is_empty() else controller_id)
	var path := preset_path(SOURCE_USER, id, normalized_controller)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var error := DirAccess.remove_absolute(path)
	if error == OK:
		var selected := selected_presets.get(normalized_controller, {}) as Dictionary
		if selected.get("source", "") == SOURCE_USER and selected.get("id", "") == id:
			selected_presets[normalized_controller] = {
				"source": SOURCE_BUILTIN,
				"id": DEFAULT_PRESET_ID,
			}
			save_settings()
	return error


func sanitize_preset_id(preset_name: String) -> String:
	var id := ""
	for character in preset_name.strip_edges().to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			id += character
		elif character == " " or character == "-" or character == "_":
			id += "_"
	while id.contains("__"):
		id = id.replace("__", "_")
	return id.lstrip("_").rstrip("_")


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
		var selected := selected_presets.get(controller_id, {}) as Dictionary
		config.set_value(section, "preset_source", str(selected.get("source", SOURCE_BUILTIN)))
		config.set_value(section, "preset_id", str(selected.get("id", DEFAULT_PRESET_ID)))
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


func _reset_selected_presets() -> void:
	selected_presets = {}
	for controller_id in CONTROLLER_SECTIONS:
		selected_presets[controller_id] = {
			"source": SOURCE_BUILTIN,
			"id": DEFAULT_PRESET_ID,
		}


func _load_controller_settings(config: ConfigFile) -> void:
	for controller_id in CONTROLLER_SECTIONS:
		var section := str(CONTROLLER_SECTIONS[controller_id])
		var settings := controller_settings[controller_id] as Dictionary
		for def in get_controller_setting_defs(controller_id):
			var key := str(def["key"])
			if config.has_section_key(section, key):
				settings[key] = clampf(float(config.get_value(section, key, def["default"])), float(def["min"]), float(def["max"]))


func _load_selected_presets(config: ConfigFile) -> void:
	for controller_id in CONTROLLER_SECTIONS:
		var section := str(CONTROLLER_SECTIONS[controller_id])
		var source := str(config.get_value(section, "preset_source", SOURCE_BUILTIN))
		if source != SOURCE_USER:
			source = SOURCE_BUILTIN
		var id := str(config.get_value(section, "preset_id", DEFAULT_PRESET_ID))
		if id.is_empty():
			id = DEFAULT_PRESET_ID
		selected_presets[controller_id] = {
			"source": source,
			"id": id,
		}


func _apply_selected_presets() -> void:
	for controller_id in CONTROLLER_SECTIONS:
		var selected := selected_presets.get(controller_id, {}) as Dictionary
		var source := str(selected.get("source", SOURCE_BUILTIN))
		var id := str(selected.get("id", DEFAULT_PRESET_ID))
		var payload := load_preset(source, id, controller_id)
		if payload.is_empty() and source == SOURCE_USER:
			selected_presets[controller_id] = {
				"source": SOURCE_BUILTIN,
				"id": DEFAULT_PRESET_ID,
			}
			payload = load_preset(SOURCE_BUILTIN, DEFAULT_PRESET_ID, controller_id)
		if not payload.is_empty():
			_apply_preset_values(payload, controller_id)


func _apply_preset_values(payload: Dictionary, controller_id: String) -> bool:
	var normalized_controller := _normalize_character_controller(controller_id)
	if _normalize_character_controller(str(payload.get("controller", ""))) != normalized_controller:
		return false
	var raw_settings: Variant = payload.get("settings", {})
	if not raw_settings is Dictionary:
		return false
	var settings := controller_settings[normalized_controller] as Dictionary
	var values := raw_settings as Dictionary
	for def in get_controller_setting_defs(normalized_controller):
		var key := str(def["key"])
		if values.has(key) and _is_numeric(values[key]):
			settings[key] = clampf(float(values[key]), float(def["min"]), float(def["max"]))
	var keybindings: Variant = payload.get("keybindings", {})
	if keybindings is Dictionary:
		KeybindingsSettings.apply_bindings_payload(keybindings as Dictionary, normalized_controller)
	return true


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


func _append_preset_entries(entries: Array[Dictionary], source: String, dir_path: String, controller_id: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if not file_name.ends_with(".json"):
			continue
		var id := file_name.get_basename()
		var payload := _read_preset_json("%s/%s" % [dir_path, file_name])
		if payload.is_empty():
			continue
		entries.append({
			"source": source,
			"id": id,
			"name": str(payload.get("name", id)),
			"controller": str(payload.get("controller", controller_id)),
		})


func _read_preset_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open settings preset %s (error %s)." % [path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Settings preset is not a Dictionary JSON payload: %s." % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


func _ensure_user_preset_dir() -> void:
	for controller_id in CONTROLLER_SECTIONS:
		var dir := "%s/%s" % [USER_PRESETS_DIR, controller_id]
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float

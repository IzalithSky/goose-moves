extends Node

signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_MOUSE_SENSITIVITY := 0.003

var mouse_sensitivity := DEFAULT_MOUSE_SENSITIVITY
var fullscreen := false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
	fullscreen = false
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		mouse_sensitivity = clampf(float(config.get_value(SECTION, "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)), 0.001, 0.02)
		fullscreen = bool(config.get_value(SECTION, "fullscreen", false))
	apply_window_mode()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.001, 0.02)
	save_settings()
	settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_window_mode()
	save_settings()
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "fullscreen", fullscreen)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save settings: %s" % error_string(error))


func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)

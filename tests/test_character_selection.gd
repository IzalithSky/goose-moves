extends "res://tests/q3_test.gd"

const LEVEL_SCENE := preload("res://scenes/primitive_test_level.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/settings_menu.tscn")

var level


func _ready() -> void:
	_reset_touched_controller_settings()
	KeybindingsSettings.reset_to_defaults()
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	level = LEVEL_SCENE.instantiate() as Node3D
	add_child(level)


func step() -> void:
	_runtime_swap()
	_persistence()
	_controller_specific_settings()
	_numeric_text_validation()
	_controller_specific_keybindings()
	_reset_touched_controller_settings()
	KeybindingsSettings.reset_to_defaults()
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	finish()


func _runtime_swap() -> void:
	check("level starts with saved Q3 controller", level.active_character_id == Settings.CHARACTER_Q3)
	check("Q3 controller instance spawned", level.active_character is Q3CharacterController)

	Settings.set_character_controller(Settings.CHARACTER_SPECTATOR)
	check("settings change swaps to spectator", level.active_character_id == Settings.CHARACTER_SPECTATOR)
	check("spectator camera instance spawned", level.active_character is Camera3D)

	Settings.set_character_controller(Settings.CHARACTER_Q3)
	check("settings change swaps back to Q3", level.active_character_id == Settings.CHARACTER_Q3)
	check("Q3 respawned after spectator", level.active_character is Q3CharacterController)


func _persistence() -> void:
	Settings.set_character_controller(Settings.CHARACTER_SPECTATOR)
	var config := ConfigFile.new()
	check("settings config loads after character save", config.load(Settings.SAVE_PATH) == OK)
	check("character selection persisted",
		str(config.get_value(Settings.SECTION, "character_controller", "")) == Settings.CHARACTER_SPECTATOR)

	Settings.character_controller = Settings.CHARACTER_Q3
	Settings.load_settings()
	check("character selection reloads from config", Settings.character_controller == Settings.CHARACTER_SPECTATOR)


func _controller_specific_settings() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	Settings.set_controller_setting("move_speed", 13.0)
	Settings.set_controller_setting("fov", 111.0)
	Settings.set_character_controller(Settings.CHARACTER_SPECTATOR)
	Settings.set_controller_setting("fov", 99.0)
	Settings.set_controller_setting("move_speed", 21.0)
	Settings.set_controller_setting("mouse_sensitivity", 0.011)

	check_approx("Q3 move speed is controller-specific",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 13.0)
	check_approx("Q3 FOV is controller-specific",
		Settings.get_controller_setting("fov", Settings.CHARACTER_Q3), 111.0)
	check_approx("spectator speed is controller-specific",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_SPECTATOR), 21.0)
	check_approx("spectator FOV is controller-specific",
		Settings.get_controller_setting("fov", Settings.CHARACTER_SPECTATOR), 99.0)
	check_approx("spectator sensitivity is controller-specific",
		Settings.get_controller_setting("mouse_sensitivity", Settings.CHARACTER_SPECTATOR), 0.011)

	var config := ConfigFile.new()
	check("settings config loads after controller-specific saves", config.load(Settings.SAVE_PATH) == OK)
	check_approx("Q3 speed persisted in Q3 section",
		float(config.get_value("controller_q3", "move_speed", 0.0)), 13.0)
	check_approx("spectator speed persisted in spectator section",
		float(config.get_value("controller_spectator", "move_speed", 0.0)), 21.0)
	check_approx("spectator FOV persisted in spectator section",
		float(config.get_value("controller_spectator", "fov", 0.0)), 99.0)


func _controller_specific_keybindings() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_J)
	Settings.set_character_controller(Settings.CHARACTER_SPECTATOR)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_U)

	check("spectator keybindings omit slow walk",
		not "player_walk" in KeybindingsSettings.get_actions(Settings.CHARACTER_SPECTATOR))
	check("spectator jump binding applied to InputMap",
		_input_map_has_key("player_jump", KEY_U))

	Settings.set_character_controller(Settings.CHARACTER_Q3)
	check("Q3 keybindings include slow walk",
		"player_walk" in KeybindingsSettings.get_actions(Settings.CHARACTER_Q3))
	check("Q3 jump binding restored on controller switch",
		_input_map_has_key("player_jump", KEY_J))

	var config := ConfigFile.new()
	check("keybindings config loads after controller-specific saves", config.load(KeybindingsSettings.SAVE_PATH) == OK)
	check("Q3 binding persisted in Q3 section",
		(config.get_value("bindings_q3", "player_jump", []) as Array)[0] == KEY_J)
	check("spectator binding persisted in spectator section",
		(config.get_value("bindings_spectator", "player_jump", []) as Array)[0] == KEY_U)


func _numeric_text_validation() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	Settings.set_controller_setting("move_speed", 13.0)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["move_speed"] as Dictionary
	var field := control_data["field"] as LineEdit

	menu._commit_controller_text("move_speed", field, "not-a-number")
	check_approx("invalid numeric setting text is ignored",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 13.0)
	check("invalid numeric setting text is reverted", field.text == "13.00")

	menu._commit_controller_text("move_speed", field, "14.5")
	check_approx("valid numeric setting text is applied",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 14.5)
	menu.queue_free()


func _input_map_has_key(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _reset_touched_controller_settings() -> void:
	Settings.set_controller_setting("move_speed", 320.0 * 0.3048 / 8.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("fov", Settings.DEFAULT_FOV, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("fov", Settings.DEFAULT_FOV, Settings.CHARACTER_SPECTATOR)
	Settings.set_controller_setting("move_speed", 12.0, Settings.CHARACTER_SPECTATOR)
	Settings.set_controller_setting("mouse_sensitivity", Settings.DEFAULT_MOUSE_SENSITIVITY, Settings.CHARACTER_SPECTATOR)

extends "res://tests/q3_test.gd"

const LEVEL_SCENE := preload("res://scenes/primitive_test_level.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
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
	_settings_menu_categories()
	_menu_entry_buttons()
	_ramp_launch_fixture()
	_character_size_settings()
	_third_person_option()
	_movement_mode_option()
	_autojump_option()
	_crouch_slide_option()
	_ramp_launch_option()
	_wall_jump_option()
	_settings_presets()
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
	check("spectator keybindings omit Q3 special movement",
		not "player_special" in KeybindingsSettings.get_actions(Settings.CHARACTER_SPECTATOR))
	check("spectator jump binding applied to InputMap",
		_input_map_has_key("player_jump", KEY_U))

	Settings.set_character_controller(Settings.CHARACTER_Q3)
	check("Q3 keybindings include slow walk",
		"player_walk" in KeybindingsSettings.get_actions(Settings.CHARACTER_Q3))
	check("Q3 keybindings include Special / Wall Jump",
		"player_special" in KeybindingsSettings.get_actions(Settings.CHARACTER_Q3))
	check("Q3 Special / Wall Jump defaults to E",
		_input_map_has_key("player_special", KEY_E))
	check("Q3 jump binding restored on controller switch",
		_input_map_has_key("player_jump", KEY_J))

	var config := ConfigFile.new()
	check("keybindings config loads after controller-specific saves", config.load(KeybindingsSettings.SAVE_PATH) == OK)
	check("Q3 binding persisted in Q3 section",
		(config.get_value("bindings_q3", "player_jump", []) as Array)[0] == KEY_J)
	check("spectator binding persisted in spectator section",
		(config.get_value("bindings_spectator", "player_jump", []) as Array)[0] == KEY_U)


func _settings_menu_categories() -> void:
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	check("settings menu has global category",
		menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Global") != null)
	check("settings menu has character category",
		menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character") != null)
	check("settings menu category tabs are hidden",
		not menu.settings_tabs.tabs_visible)
	check("fullscreen is in global settings",
		menu.fullscreen_toggle.get_parent().name == "Global")
	check("character selector is in character settings",
		menu.character_option.get_parent().get_parent().name == "Character")
	check("key bindings are in character settings",
		menu.keybindings_button.get_parent().name == "Character")
	menu.queue_free()


func _menu_entry_buttons() -> void:
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	check("main menu has character settings button",
		main_menu.get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CharacterSettingsButton") != null)
	main_menu.on_settings_pressed()
	check("main settings button opens global settings",
		main_menu.settings_menu.settings_tabs.current_tab == 0)
	main_menu.on_settings_back_requested()
	main_menu.on_character_settings_pressed()
	check("main character settings button opens character settings",
		main_menu.settings_menu.settings_tabs.current_tab == 1)
	main_menu.queue_free()

	var pause_menu := PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)
	check("pause menu has character settings button",
		pause_menu.get_node_or_null("MenuRoot/CenterContainer/PausePanel/Margin/VBox/CharacterSettingsButton") != null)
	pause_menu.on_settings_pressed()
	check("pause settings button opens global settings",
		pause_menu.settings_menu.settings_tabs.current_tab == 0)
	pause_menu.on_settings_back_requested()
	pause_menu.on_character_settings_pressed()
	check("pause character settings button opens character settings",
		pause_menu.settings_menu.settings_tabs.current_tab == 1)
	pause_menu.queue_free()


func _movement_mode_option() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["movement_mode"] as Dictionary
	var option_button := control_data["option"] as OptionButton
	check("movement mode uses a profile dropdown", option_button.item_count == 2)
	check("movement mode defaults to VQ3", option_button.selected == Q3CharacterController.MovementMode.VQ3)
	option_button.select(Q3CharacterController.MovementMode.WARSOW_CLASSIC)
	menu.on_controller_option_selected(
		option_button.selected,
		"movement_mode",
		option_button,
	)
	check_approx("movement mode dropdown selects Warsow Classic",
		Settings.get_controller_setting("movement_mode", Settings.CHARACTER_Q3),
		Q3CharacterController.MovementMode.WARSOW_CLASSIC)
	menu.queue_free()
	Settings.set_controller_setting(
		"movement_mode",
		Q3CharacterController.MovementMode.VQ3,
		Settings.CHARACTER_Q3,
	)


func _ramp_launch_fixture() -> void:
	var ramp := level.get_node_or_null("LimitSlopes/RampLaunch55") as CSGBox3D
	check("playable test level includes the steep-ramp launch fixture", ramp != null)
	if ramp != null:
		check_approx("steep-ramp launch fixture is 55 degrees", ramp.rotation_degrees.x, 55.0)


func _character_size_settings() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	check("character size X is exposed in the Q3 profile", menu.controller_controls.has("character_size_x"))
	check("character size Y is exposed in the Q3 profile", menu.controller_controls.has("character_size_y"))
	check("character size Z is exposed in the Q3 profile", menu.controller_controls.has("character_size_z"))
	menu.queue_free()

	Settings.set_controller_setting("character_size_x", 1.5, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_y", 2.5, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_z", 1.25, Settings.CHARACTER_Q3)
	var controller := level.active_character as Q3CharacterController
	check_vec3("live Q3 collider receives all three profile dimensions",
		controller.body_shape.size, Vector3(1.5, 2.5, 1.25))
	check_vec3("third-person box mesh exactly matches the standing collider",
		controller.body_mesh.size, controller.body_shape.size)
	check_vec3("third-person box offset exactly matches the collider",
		controller.character_collider_visual.position, controller.collision_shape.position)
	controller._set_crouching(true)
	check_vec3("third-person box mesh follows the crouched collider",
		controller.body_mesh.size, controller.body_shape.size)
	check_vec3("third-person box offset follows the crouched collider",
		controller.character_collider_visual.position, controller.collision_shape.position)
	controller._set_crouching(false)

	Settings.set_controller_setting("character_size_x", 30.0 * Q3CharacterController.Q3_METERS_PER_UNIT, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_y", Q3CharacterController.Q3_STANDING_HULL_HEIGHT * Q3CharacterController.Q3_METERS_PER_UNIT, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_z", 30.0 * Q3CharacterController.Q3_METERS_PER_UNIT, Settings.CHARACTER_Q3)


func _third_person_option() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["third_person"] as Dictionary
	var toggle := control_data["toggle"] as CheckButton
	check("third-person camera uses a profile toggle", not toggle.button_pressed)
	check("third-person distance is exposed in the Q3 profile",
		menu.controller_controls.has("third_person_distance"))
	menu.on_controller_toggle_changed(true, "third_person")
	var controller := level.active_character as Q3CharacterController
	check("live Q3 controller receives third-person setting", controller.third_person_enabled)
	check("third-person camera becomes current", controller.third_person_camera.current)
	check("first-person camera is no longer current", not controller.camera.current)
	check("collider box is visible in third person", controller.character_collider_visual.visible)
	check("third-person camera uses a collision-aware spring arm",
		controller.third_person_spring_arm != null)
	check_approx("third-person spring arm defaults to four metres",
		controller.third_person_spring_arm.spring_length, 4.0)
	Settings.set_controller_setting("third_person_distance", 6.5, Settings.CHARACTER_Q3)
	check_approx("third-person distance updates the live spring arm",
		controller.third_person_spring_arm.spring_length, 6.5)
	menu.queue_free()
	Settings.set_controller_setting("third_person", 0.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("third_person_distance", 4.0, Settings.CHARACTER_Q3)


func _autojump_option() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["auto_jump"] as Dictionary
	var toggle := control_data["toggle"] as CheckButton
	check("autojump uses a profile toggle", not toggle.button_pressed)
	menu.on_controller_toggle_changed(true, "auto_jump")
	check_approx("autojump profile toggle enables held jumping",
		Settings.get_controller_setting("auto_jump", Settings.CHARACTER_Q3), 1.0)
	check("live Q3 controller receives autojump setting",
		(level.active_character as Q3CharacterController).auto_jump)
	menu.queue_free()
	Settings.set_controller_setting("auto_jump", 0.0, Settings.CHARACTER_Q3)


func _crouch_slide_option() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["crouch_slide"] as Dictionary
	var toggle := control_data["toggle"] as CheckButton
	check("crouch slide uses a profile toggle", not toggle.button_pressed)
	menu.on_controller_toggle_changed(true, "crouch_slide")
	check_approx("crouch slide profile toggle enables sliding",
		Settings.get_controller_setting("crouch_slide", Settings.CHARACTER_Q3), 1.0)
	check("live Q3 controller receives crouch slide setting",
		(level.active_character as Q3CharacterController).crouch_slide_enabled)
	menu.queue_free()
	Settings.set_controller_setting("crouch_slide", 0.0, Settings.CHARACTER_Q3)


func _ramp_launch_option() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["ramp_launch"] as Dictionary
	var toggle := control_data["toggle"] as CheckButton
	check("steep-ramp launch uses a profile toggle", not toggle.button_pressed)
	menu.on_controller_toggle_changed(true, "ramp_launch")
	check_approx("steep-ramp launch profile toggle enables launch clipping",
		Settings.get_controller_setting("ramp_launch", Settings.CHARACTER_Q3), 1.0)
	check("live Q3 controller receives steep-ramp launch setting",
		(level.active_character as Q3CharacterController).ramp_launch_enabled)
	menu.queue_free()
	Settings.set_controller_setting("ramp_launch", 0.0, Settings.CHARACTER_Q3)


func _wall_jump_option() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var control_data := menu.controller_controls["wall_jump"] as Dictionary
	var toggle := control_data["toggle"] as CheckButton
	check("wall jump uses a profile toggle", not toggle.button_pressed)
	menu.on_controller_toggle_changed(true, "wall_jump")
	check_approx("wall jump profile toggle enables wall response",
		Settings.get_controller_setting("wall_jump", Settings.CHARACTER_Q3), 1.0)
	check("live Q3 controller receives wall jump setting",
		(level.active_character as Q3CharacterController).wall_jump_enabled)
	menu.queue_free()
	Settings.set_controller_setting("wall_jump", 0.0, Settings.CHARACTER_Q3)


func _settings_presets() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var default_entry := _find_preset(Settings.SOURCE_BUILTIN, Settings.DEFAULT_PRESET_ID)
	check("built-in default settings preset is listed", not default_entry.is_empty())

	var default_payload := Settings.load_preset(Settings.SOURCE_BUILTIN, Settings.DEFAULT_PRESET_ID)
	check("built-in default settings preset loads", not default_payload.is_empty())
	check("built-in default preset matches setting schema defaults", _preset_matches_defaults(default_payload))
	check("built-in default preset includes keybindings",
		(default_payload.get("keybindings", {}) as Dictionary).has("player_jump"))
	check("built-in default preset includes Special / Wall Jump binding",
		(default_payload.get("keybindings", {}) as Dictionary).has("player_special"))

	Settings.set_character_controller(Settings.CHARACTER_Q3_N_FLIGHT)
	var hybrid_default_entry := _find_preset(Settings.SOURCE_BUILTIN, Settings.DEFAULT_PRESET_ID)
	check("built-in Q3 + Flight default settings preset is listed", not hybrid_default_entry.is_empty())
	var hybrid_default_payload := Settings.load_preset(Settings.SOURCE_BUILTIN, Settings.DEFAULT_PRESET_ID)
	check("built-in Q3 + Flight default settings preset loads", not hybrid_default_payload.is_empty())
	check("built-in Q3 + Flight default preset matches setting schema defaults",
		_preset_matches_defaults(hybrid_default_payload))
	var hybrid_menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(hybrid_menu)
	hybrid_menu.sync_from_settings()
	check("built-in Q3 + Flight default preset appears in settings dropdown",
		_find_preset_option(hybrid_menu, Settings.SOURCE_BUILTIN, Settings.DEFAULT_PRESET_ID) >= 0)
	hybrid_menu.queue_free()
	Settings.set_character_controller(Settings.CHARACTER_Q3)

	Settings.set_controller_setting("move_speed", 13.0, Settings.CHARACTER_Q3)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_J)
	check("default preset applies", Settings.apply_preset_entry(Settings.SOURCE_BUILTIN, Settings.DEFAULT_PRESET_ID))
	check_approx("default preset restores Q3 move speed",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 320.0 * 0.3048 / 8.0)
	check("default preset restores Q3 keybindings",
		_input_map_has_key("player_jump", KEY_SPACE))

	Settings.set_controller_setting("move_speed", 17.0, Settings.CHARACTER_Q3)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_J)
	var saved_entry := Settings.save_user_preset("Automated Test Preset")
	check("user settings preset saves", saved_entry.get("source", "") == Settings.SOURCE_USER)

	Settings.set_controller_setting("move_speed", 19.0, Settings.CHARACTER_Q3)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_U)
	var user_payload := Settings.load_preset(saved_entry["source"], saved_entry["id"])
	check("user settings preset loads", not user_payload.is_empty())
	check("user settings preset applies", Settings.apply_preset_entry(saved_entry["source"], saved_entry["id"]))
	check_approx("user preset restores saved Q3 move speed",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 17.0)
	check("user preset restores saved Q3 keybindings",
		_input_map_has_key("player_jump", KEY_J))

	Settings.set_character_controller(Settings.CHARACTER_SPECTATOR)
	check("Q3 user preset is not listed for spectator",
		_find_preset(Settings.SOURCE_USER, saved_entry["id"]).is_empty())
	Settings.set_character_controller(Settings.CHARACTER_Q3)

	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	Settings.set_controller_setting("move_speed", 19.0, Settings.CHARACTER_Q3)
	menu.sync_from_settings()
	check_approx("preset dropdown sync does not reapply preset over edits",
		Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 19.0)

	var user_index := _find_preset_option(menu, saved_entry["source"], saved_entry["id"])
	check("saved user preset appears in settings dropdown", user_index >= 0)
	if user_index >= 0:
		menu.preset_option.select(user_index)
		menu.on_preset_selected(user_index)
		check_approx("preset dropdown selection loads preset",
			Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 17.0)
		check("preset dropdown selection persists selected preset",
			Settings.get_selected_preset().get("id", "") == saved_entry["id"])

		Settings.set_controller_setting("move_speed", 18.0, Settings.CHARACTER_Q3)
		menu.save_preset_name_edit.text = "Automated Test Preset"
		menu.on_save_preset_confirmed()
		check("conflicting save asks for overwrite confirmation",
			menu.overwrite_preset_dialog.dialog_text.contains("Overwrite preset"))
		menu.on_overwrite_preset_confirmed()
		var overwritten_payload := Settings.load_preset(saved_entry["source"], saved_entry["id"])
		check("overwrite updates existing user preset",
			is_equal_approx(float((overwritten_payload["settings"] as Dictionary)["move_speed"]), 18.0))
		Settings.set_controller_setting("move_speed", 19.0, Settings.CHARACTER_Q3)
		Settings.load_settings()
		check_approx("controller settings persist across settings reload",
			Settings.get_controller_setting("move_speed", Settings.CHARACTER_Q3), 19.0)
		check("selected preset persists across settings reload",
			Settings.get_selected_preset().get("id", "") == saved_entry["id"])
		check("user preset delete is enabled for user entries", not menu.delete_preset_button.disabled)
		menu.on_delete_preset_pressed()
		check("delete asks for confirmation",
			menu.delete_preset_dialog.dialog_text.contains("Delete preset"))
		menu.on_delete_preset_confirmed()
		check("deleted user preset is removed from list",
			_find_preset(Settings.SOURCE_USER, saved_entry["id"]).is_empty())
	menu.queue_free()


func _numeric_text_validation() -> void:
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	Settings.set_controller_setting("move_speed", 13.0)
	menu.build_controller_settings()
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
	Settings.set_controller_setting("movement_mode", Q3CharacterController.MovementMode.VQ3, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("auto_jump", 0.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("crouch_slide", 0.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("ramp_launch", 0.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("wall_jump", 0.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("third_person", 0.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("third_person_distance", 4.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_x", 30.0 * Q3CharacterController.Q3_METERS_PER_UNIT, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_y", Q3CharacterController.Q3_STANDING_HULL_HEIGHT * Q3CharacterController.Q3_METERS_PER_UNIT, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("character_size_z", 30.0 * Q3CharacterController.Q3_METERS_PER_UNIT, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("move_speed", 320.0 * 0.3048 / 8.0, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("fov", Settings.DEFAULT_FOV, Settings.CHARACTER_Q3)
	Settings.set_controller_setting("fov", Settings.DEFAULT_FOV, Settings.CHARACTER_SPECTATOR)
	Settings.set_controller_setting("move_speed", 12.0, Settings.CHARACTER_SPECTATOR)
	Settings.set_controller_setting("mouse_sensitivity", Settings.DEFAULT_MOUSE_SENSITIVITY, Settings.CHARACTER_SPECTATOR)


func _find_preset(source: String, id: String) -> Dictionary:
	for entry in Settings.list_presets():
		if entry["source"] == source and entry["id"] == id:
			return entry
	return {}


func _find_preset_option(menu, source: String, id: String) -> int:
	for index in menu.preset_option.item_count:
		var entry: Dictionary = menu.preset_option.get_item_metadata(index)
		if entry["source"] == source and entry["id"] == id:
			return index
	return -1


func _preset_matches_defaults(payload: Dictionary) -> bool:
	var controller_id := str(payload.get("controller", ""))
	var values: Dictionary = payload.get("settings", {})
	for def in Settings.get_controller_setting_defs(controller_id):
		var key := str(def["key"])
		if not values.has(key) or not is_equal_approx(float(values[key]), float(def["default"])):
			return false
	return true

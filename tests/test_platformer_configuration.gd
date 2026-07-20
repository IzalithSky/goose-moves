extends "res://tests/q3_test.gd"

const LEVEL_SCENE := preload("res://scenes/primitive_test_level.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/settings_menu.tscn")
const PLATFORMER_SCRIPT := preload("res://scripts/platformer_controller.gd")

var level


func _ready() -> void:
	_reset_platformer_settings()
	KeybindingsSettings.reset_to_defaults()
	Settings.set_character_controller(Settings.CHARACTER_PLATFORMER)
	level = LEVEL_SCENE.instantiate()
	add_child(level)


func step() -> void:
	_runtime_selection()
	_settings_persistence()
	_keybinding_persistence()
	_profile_support()
	_menu_support()
	_surface_fixtures()
	_reset_platformer_settings()
	KeybindingsSettings.reset_to_defaults()
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	finish()


func _runtime_selection() -> void:
	check("platformer selection spawns the platformer controller",
		level.active_character.get_script() == PLATFORMER_SCRIPT)
	check("level tracks platformer as the active controller",
		level.active_character_id == Settings.CHARACTER_PLATFORMER)
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	check("runtime swap still reaches Q3", level.active_character is Q3CharacterController)
	Settings.set_character_controller(Settings.CHARACTER_PLATFORMER)
	check("runtime swap returns to platformer",
		level.active_character.get_script() == PLATFORMER_SCRIPT)


func _settings_persistence() -> void:
	Settings.set_controller_setting("max_run_speed", 36.0, Settings.CHARACTER_PLATFORMER)
	Settings.set_controller_setting("camera_distance", 7.5, Settings.CHARACTER_PLATFORMER)
	Settings.set_controller_setting("first_person", 1.0, Settings.CHARACTER_PLATFORMER)
	var config := ConfigFile.new()
	check("settings config loads after platformer save", config.load(Settings.SAVE_PATH) == OK)
	check_approx("platformer speed persists in its own section",
		float(config.get_value("controller_platformer", "max_run_speed", 0.0)), 36.0)
	check_approx("platformer camera persists in its own section",
		float(config.get_value("controller_platformer", "camera_distance", 0.0)), 7.5)
	check_approx("first-person mode persists in the platformer section",
		float(config.get_value("controller_platformer", "first_person", 0.0)), 1.0)
	var controller: Variant = level.active_character
	check("live platformer enables first-person mode", controller.first_person_enabled)
	check("first-person camera becomes current", controller.first_person_camera.current)
	check("third-person camera stops being current", not controller.third_person_camera.current)
	check("first-person mode hides the body mesh", not controller.body_mesh.visible)
	check("platformer settings do not replace Q3 schema",
		Settings._get_setting_def(Settings.CHARACTER_Q3, "camera_distance").is_empty())


func _keybinding_persistence() -> void:
	Settings.set_character_controller(Settings.CHARACTER_PLATFORMER)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_J)
	check("platformer actions include dive", "player_special" in KeybindingsSettings.get_actions())
	check("platformer actions omit Q3 slow walk", not "player_walk" in KeybindingsSettings.get_actions())
	check("platformer special has its own label",
		KeybindingsSettings.get_action_label("player_special") == "Dive / Attack")
	Settings.set_character_controller(Settings.CHARACTER_Q3)
	KeybindingsSettings.set_binding("player_jump", 0, KEY_U)
	Settings.set_character_controller(Settings.CHARACTER_PLATFORMER)
	check("platformer jump mapping restores independently", _input_map_has_key("player_jump", KEY_J))
	var config := ConfigFile.new()
	check("keybinding config loads after platformer save", config.load(KeybindingsSettings.SAVE_PATH) == OK)
	check("platformer binding persists in its own section",
		(config.get_value("bindings_platformer", "player_jump", []) as Array)[0] == KEY_J)
	check("Q3 binding remains in the Q3 section",
		(config.get_value("bindings_q3", "player_jump", []) as Array)[0] == KEY_U)


func _profile_support() -> void:
	var entries := Settings.list_presets(Settings.CHARACTER_PLATFORMER)
	check("platformer built-in profile is listed", entries.size() == 1)
	var payload := Settings.load_preset(
		Settings.SOURCE_BUILTIN,
		Settings.DEFAULT_PRESET_ID,
		Settings.CHARACTER_PLATFORMER,
	)
	check("platformer built-in profile loads", not payload.is_empty())
	check("platformer profile owns its controller id", payload.get("controller", "") == Settings.CHARACTER_PLATFORMER)
	check("platformer profile includes dive mapping",
		(payload.get("keybindings", {}) as Dictionary).has("player_special"))
	check("platformer profile matches its setting schema", _preset_matches_defaults(payload))


func _menu_support() -> void:
	Settings.set_character_controller(Settings.CHARACTER_PLATFORMER)
	var menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(menu)
	menu.sync_from_settings()
	var found_platformer := false
	for index in menu.character_option.item_count:
		if menu.character_option.get_item_metadata(index) == Settings.CHARACTER_PLATFORMER:
			found_platformer = true
	check("character menu lists Platformer", found_platformer)
	check("platformer menu exposes polar run speed", menu.controller_controls.has("max_run_speed"))
	check("platformer menu exposes water buoyancy", menu.controller_controls.has("buoyancy"))
	check("platformer menu exposes first-person view", menu.controller_controls.has("first_person"))
	var active_controller := level.active_character as PlatformerController
	var capsule := active_controller.collision_shape.shape as CapsuleShape3D
	check_approx("runtime capsule uses converted 50-unit radius", capsule.radius, 0.625)
	check_approx("runtime capsule uses converted 160-unit height", capsule.height, 2.0)
	check_approx("runtime floor snap uses converted 100-unit distance",
		active_controller.floor_snap_length, 1.25)
	menu.queue_free()


func _surface_fixtures() -> void:
	var base := level.get_node("GridFloor/Base") as CSGBox3D
	check("playable test floor expands to 1000 metres", base.size == Vector3(1000.0, 0.2, 1000.0))
	for fixture_name in [
		"Slippery",
		"NotSlippery",
		"Slow",
		"Hard",
		"Quicksand",
		"MovingQuicksand",
		"Burning",
		"HorizontalWind",
		"VerticalWind",
	]:
		check("playable level includes platformer %s surface" % fixture_name,
			level.get_node_or_null("PlatformerSurfaces/" + fixture_name) != null)
	check("playable level includes all four slipperiness slope classes",
		level.get_node("SurfaceClassSlopes").get_child_count() == 4)
	check("existing water pool is a platformer water medium",
		level.get_node("Volumes/Water").get_meta("platformer_medium", &"") == &"water")
	check("existing lava pool floor is a platformer burning surface",
		level.get_node("Pools/LavaBottom").get_meta("platformer_surface", &"") == &"burning")
	check("water pool floor provides flowing-water current",
		level.get_node("Pools/WaterBottom").get_meta("platformer_surface", &"") == &"flowing_water")
	var labels: Node = level.get_node("FixtureLabels")
	var expected_label_count := 0
	for root_path in level.LABELED_FIXTURE_ROOTS:
		expected_label_count += level.get_node(root_path).get_child_count()
	check("every obstacle and surface fixture gets a world-space label",
		labels.get_child_count() == expected_label_count)
	check("obstacle labels are Label3D nodes", labels.get_node("CubeLowLabel") is Label3D)
	var surface_label := labels.get_node("MovingQuicksandLabel") as Label3D
	check("surface labels use one human-readable title", surface_label.text == "Moving Quicksand")
	check("surface labels scale with perspective", not surface_label.fixed_size)
	check("surface labels obey world depth", not surface_label.no_depth_test)
	check("medium labels use one human-readable title",
		(labels.get_node("WaterLabel") as Label3D).text == "Water")


func _reset_platformer_settings() -> void:
	for def in Settings.PLATFORMER_SETTING_DEFS:
		Settings.set_controller_setting(
			str(def["key"]),
			float(def["default"]),
			Settings.CHARACTER_PLATFORMER,
		)


func _input_map_has_key(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _preset_matches_defaults(payload: Dictionary) -> bool:
	var values: Dictionary = payload.get("settings", {})
	for def in Settings.PLATFORMER_SETTING_DEFS:
		var key := str(def["key"])
		if not values.has(key) or not is_equal_approx(float(values[key]), float(def["default"])):
			return false
	return true

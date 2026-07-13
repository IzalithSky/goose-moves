extends CenterContainer

signal back_requested
signal keybindings_requested

@onready var character_option: OptionButton = $Panel/Margin/VBox/CharacterRow/CharacterOption
@onready var controller_title: Label = $Panel/Margin/VBox/ControllerTitle
@onready var controller_settings_box: VBoxContainer = $Panel/Margin/VBox/ScrollContainer/ControllerSettingsBox
@onready var fullscreen_toggle: CheckButton = $Panel/Margin/VBox/FullscreenToggle
@onready var keybindings_button: Button = $Panel/Margin/VBox/KeybindingsButton
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

var controller_controls: Dictionary = {}


func _ready() -> void:
	character_option.add_item("Q3", 0)
	character_option.set_item_metadata(0, Settings.CHARACTER_Q3)
	character_option.add_item("Spectator", 1)
	character_option.set_item_metadata(1, Settings.CHARACTER_SPECTATOR)
	character_option.item_selected.connect(on_character_selected)
	fullscreen_toggle.toggled.connect(on_fullscreen_toggled)
	keybindings_button.pressed.connect(on_keybindings_pressed)
	back_button.pressed.connect(on_back_pressed)
	sync_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()


func sync_from_settings() -> void:
	for index in character_option.item_count:
		if str(character_option.get_item_metadata(index)) == Settings.character_controller:
			character_option.select(index)
			break
	build_controller_settings()
	fullscreen_toggle.set_pressed_no_signal(Settings.fullscreen)


func focus_first() -> void:
	character_option.grab_focus()


func build_controller_settings() -> void:
	controller_controls.clear()
	for child in controller_settings_box.get_children():
		child.queue_free()

	controller_title.text = "%s Controls" % Settings.get_character_label()
	for def in Settings.get_controller_setting_defs():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = str(def["label"])
		label.custom_minimum_size = Vector2(150.0, 0.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var key := str(def["key"])
		var value := Settings.get_controller_setting(key)
		if str(def.get("control", "text")) == "slider":
			var slider := HSlider.new()
			slider.custom_minimum_size = Vector2(180.0, 0.0)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.min_value = float(def["min"])
			slider.max_value = float(def["max"])
			slider.step = float(def["step"])
			slider.value = value
			slider.value_changed.connect(on_controller_slider_changed.bind(key))
			row.add_child(slider)

			var value_label := Label.new()
			value_label.custom_minimum_size = Vector2(54.0, 0.0)
			value_label.text = _format_controller_value(value, def)
			row.add_child(value_label)
			controller_controls[key] = {
				"label": value_label,
				"def": def,
			}
		else:
			var line_edit := LineEdit.new()
			line_edit.custom_minimum_size = Vector2(180.0, 0.0)
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text = _format_plain_number(value, def)
			line_edit.text_submitted.connect(on_controller_text_submitted.bind(key, line_edit))
			line_edit.focus_exited.connect(on_controller_text_focus_exited.bind(key, line_edit))
			row.add_child(line_edit)
			controller_controls[key] = {
				"field": line_edit,
				"def": def,
			}

		controller_settings_box.add_child(row)


func on_controller_slider_changed(value: float, key: String) -> void:
	var label_data := controller_controls.get(key, {}) as Dictionary
	if not label_data.is_empty():
		(label_data["label"] as Label).text = _format_controller_value(value, label_data["def"] as Dictionary)
	Settings.set_controller_setting(key, value)


func on_controller_text_submitted(text: String, key: String, line_edit: LineEdit) -> void:
	_commit_controller_text(key, line_edit, text)


func on_controller_text_focus_exited(key: String, line_edit: LineEdit) -> void:
	_commit_controller_text(key, line_edit, line_edit.text)


func on_character_selected(index: int) -> void:
	Settings.set_character_controller(str(character_option.get_item_metadata(index)))
	build_controller_settings()


func on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func on_keybindings_pressed() -> void:
	keybindings_requested.emit()


func on_back_pressed() -> void:
	back_requested.emit()


func _format_controller_value(value: float, def: Dictionary) -> String:
	return str(def["format"]) % value


func _format_plain_number(value: float, def: Dictionary) -> String:
	var format := str(def["format"]).replace("°", "")
	return format % value


func _commit_controller_text(key: String, line_edit: LineEdit, text: String) -> void:
	var trimmed := text.strip_edges()
	var control_data := controller_controls.get(key, {}) as Dictionary
	if control_data.is_empty():
		return
	var def := control_data["def"] as Dictionary
	if not trimmed.is_valid_float():
		line_edit.text = _format_plain_number(Settings.get_controller_setting(key), def)
		return
	Settings.set_controller_setting(key, float(trimmed))
	line_edit.text = _format_plain_number(Settings.get_controller_setting(key), def)

extends CenterContainer

signal back_requested
signal keybindings_requested

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var settings_tabs: TabContainer = $Panel/Margin/VBox/SettingsTabs
@onready var character_option: OptionButton = $Panel/Margin/VBox/SettingsTabs/Character/CharacterRow/CharacterOption
@onready var preset_option: OptionButton = $Panel/Margin/VBox/SettingsTabs/Character/PresetRow/PresetOption
@onready var save_preset_button: Button = $Panel/Margin/VBox/SettingsTabs/Character/PresetRow/SavePresetButton
@onready var delete_preset_button: Button = $Panel/Margin/VBox/SettingsTabs/Character/PresetRow/DeletePresetButton
@onready var controller_title: Label = $Panel/Margin/VBox/SettingsTabs/Character/ControllerTitle
@onready var controller_settings_box: VBoxContainer = $Panel/Margin/VBox/SettingsTabs/Character/ScrollContainer/ControllerSettingsBox
@onready var fullscreen_toggle: CheckButton = $Panel/Margin/VBox/SettingsTabs/Global/FullscreenToggle
@onready var keybindings_button: Button = $Panel/Margin/VBox/SettingsTabs/Character/KeybindingsButton
@onready var back_button: Button = $Panel/Margin/VBox/BackButton
@onready var status_label: Label = $Panel/Margin/VBox/SettingsTabs/Character/StatusLabel
@onready var save_preset_dialog: ConfirmationDialog = $SavePresetDialog
@onready var save_preset_name_edit: LineEdit = $SavePresetDialog/Margin/VBox/PresetNameEdit
@onready var overwrite_preset_dialog: ConfirmationDialog = $OverwritePresetDialog
@onready var delete_preset_dialog: ConfirmationDialog = $DeletePresetDialog

var controller_controls: Dictionary = {}
var pending_preset_name := ""
var pending_delete_entry := {}


func _ready() -> void:
	for controller_id in Settings.CONTROLLER_LABELS:
		var index := character_option.item_count
		character_option.add_item(Settings.get_character_label(controller_id))
		character_option.set_item_metadata(index, controller_id)
	character_option.item_selected.connect(on_character_selected)
	preset_option.item_selected.connect(on_preset_selected)
	save_preset_button.pressed.connect(on_save_preset_pressed)
	delete_preset_button.pressed.connect(on_delete_preset_pressed)
	save_preset_dialog.confirmed.connect(on_save_preset_confirmed)
	save_preset_name_edit.text_submitted.connect(on_save_preset_text_submitted)
	overwrite_preset_dialog.confirmed.connect(on_overwrite_preset_confirmed)
	delete_preset_dialog.confirmed.connect(on_delete_preset_confirmed)
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
	populate_preset_options(Settings.get_selected_preset())
	build_controller_settings()
	fullscreen_toggle.set_pressed_no_signal(Settings.fullscreen)


func show_global_settings() -> void:
	settings_tabs.current_tab = 0
	title_label.text = "Settings"
	sync_from_settings()


func show_character_settings() -> void:
	settings_tabs.current_tab = 1
	title_label.text = "Character Settings"
	sync_from_settings()


func focus_first() -> void:
	if settings_tabs.current_tab == 0:
		fullscreen_toggle.grab_focus()
	else:
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
		var control_type := str(def.get("control", "text"))
		if control_type == "option":
			var option_button := OptionButton.new()
			option_button.custom_minimum_size = Vector2(180.0, 0.0)
			option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var selected_index := 0
			for option_def in def.get("options", []):
				var option_index := option_button.item_count
				option_button.add_item(str(option_def["label"]))
				var option_value := float(option_def["value"])
				option_button.set_item_metadata(option_index, option_value)
				if is_equal_approx(option_value, value):
					selected_index = option_index
			option_button.select(selected_index)
			option_button.item_selected.connect(on_controller_option_selected.bind(key, option_button))
			row.add_child(option_button)
			controller_controls[key] = {
				"option": option_button,
				"def": def,
			}
		elif control_type == "slider":
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


func populate_preset_options(select_entry := {}) -> void:
	preset_option.clear()
	var select_index := 0
	var index := 0
	for entry in Settings.list_presets():
		var label := str(entry["name"])
		if entry["source"] == Settings.SOURCE_BUILTIN:
			label += "  (built-in)"
		preset_option.add_item(label)
		preset_option.set_item_metadata(index, entry)
		if not select_entry.is_empty() and entry["source"] == select_entry.get("source", "") and entry["id"] == select_entry.get("id", ""):
			select_index = index
		index += 1
	if preset_option.item_count > 0:
		preset_option.select(select_index)
		var entry := selected_preset_entry()
		delete_preset_button.disabled = entry.get("source", "") != Settings.SOURCE_USER
	else:
		delete_preset_button.disabled = true


func selected_preset_entry() -> Dictionary:
	var index := preset_option.selected
	if index < 0:
		return {}
	var metadata: Variant = preset_option.get_item_metadata(index)
	return metadata if metadata is Dictionary else {}


func on_controller_slider_changed(value: float, key: String) -> void:
	var label_data := controller_controls.get(key, {}) as Dictionary
	if not label_data.is_empty():
		(label_data["label"] as Label).text = _format_controller_value(value, label_data["def"] as Dictionary)
	Settings.set_controller_setting(key, value)


func on_controller_option_selected(index: int, key: String, option_button: OptionButton) -> void:
	Settings.set_controller_setting(key, float(option_button.get_item_metadata(index)))


func on_controller_text_submitted(text: String, key: String, line_edit: LineEdit) -> void:
	_commit_controller_text(key, line_edit, text)


func on_controller_text_focus_exited(key: String, line_edit: LineEdit) -> void:
	_commit_controller_text(key, line_edit, line_edit.text)


func on_character_selected(index: int) -> void:
	Settings.set_character_controller(str(character_option.get_item_metadata(index)))
	populate_preset_options(Settings.get_selected_preset())
	build_controller_settings()


func on_preset_selected(_index: int) -> void:
	var entry := selected_preset_entry()
	delete_preset_button.disabled = entry.get("source", "") != Settings.SOURCE_USER
	if entry.is_empty():
		return
	if not Settings.apply_preset_entry(entry["source"], entry["id"]):
		status_label.text = "Load failed: %s" % entry.get("name", "")
		return
	build_controller_settings()
	status_label.text = "Loaded preset: %s" % entry["name"]


func on_save_preset_pressed() -> void:
	var entry := selected_preset_entry()
	save_preset_name_edit.text = "%s Copy" % entry.get("name", "Custom") if entry.get("source", "") == Settings.SOURCE_BUILTIN else str(entry.get("name", "Custom"))
	save_preset_dialog.popup_centered()
	save_preset_name_edit.grab_focus()
	save_preset_name_edit.select_all()


func on_delete_preset_pressed() -> void:
	var entry := selected_preset_entry()
	if entry.get("source", "") != Settings.SOURCE_USER:
		return
	pending_delete_entry = entry.duplicate(true)
	delete_preset_dialog.dialog_text = "Delete preset \"%s\"?" % entry["name"]
	delete_preset_dialog.popup_centered()


func on_save_preset_text_submitted(_text: String) -> void:
	on_save_preset_confirmed()
	save_preset_dialog.hide()


func on_save_preset_confirmed() -> void:
	pending_preset_name = save_preset_name_edit.text.strip_edges()
	var id := Settings.sanitize_preset_id(pending_preset_name)
	if id.is_empty():
		status_label.text = "Preset name required"
		return
	if FileAccess.file_exists(Settings.preset_path(Settings.SOURCE_USER, id)):
		overwrite_preset_dialog.dialog_text = "Overwrite preset \"%s\"?" % pending_preset_name
		overwrite_preset_dialog.popup_centered()
		return
	_save_user_preset(pending_preset_name)


func on_overwrite_preset_confirmed() -> void:
	overwrite_preset_dialog.hide()
	_save_user_preset(pending_preset_name)


func on_delete_preset_confirmed() -> void:
	delete_preset_dialog.hide()
	if pending_delete_entry.is_empty():
		return
	var delete_error := Settings.delete_user_preset(
		str(pending_delete_entry["id"]),
		str(pending_delete_entry.get("controller", Settings.character_controller)),
	)
	if delete_error != OK:
		status_label.text = "Delete failed: %s" % error_string(delete_error)
		return
	status_label.text = "Deleted preset: %s" % pending_delete_entry["name"]
	pending_delete_entry = {}
	populate_preset_options(Settings.get_selected_preset())


func _save_user_preset(preset_name: String) -> void:
	var result := Settings.save_user_preset(preset_name)
	if result.is_empty():
		status_label.text = "Save failed"
		return
	populate_preset_options(result)
	status_label.text = "Saved preset: %s" % result["name"]


func on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func on_keybindings_pressed() -> void:
	keybindings_requested.emit()


func on_back_pressed() -> void:
	back_requested.emit()


func _format_controller_value(value: float, def: Dictionary) -> String:
	return str(def["format"]) % value + str(def.get("suffix", ""))


func _format_plain_number(value: float, def: Dictionary) -> String:
	return str(def["format"]) % value


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

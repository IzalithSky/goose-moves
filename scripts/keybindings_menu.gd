extends CenterContainer

signal back_requested

const LISTENING_TEXT := "Press input..."

@onready var action_grid: GridContainer = $Panel/Margin/VBox/ScrollContainer/ActionGrid
@onready var reset_button: Button = $Panel/Margin/VBox/ButtonRow/ResetButton
@onready var back_button: Button = $Panel/Margin/VBox/ButtonRow/BackButton

var listening_action := ""
var listening_slot := -1
var binding_buttons: Dictionary = {}


func _ready() -> void:
	build_rows()
	reset_button.pressed.connect(on_reset_pressed)
	back_button.pressed.connect(on_back_pressed)
	KeybindingsSettings.bindings_changed.connect(refresh_labels)
	KeybindingsSettings.actions_changed.connect(build_rows)


func _input(event: InputEvent) -> void:
	if listening_action.is_empty():
		return

	var binding: Variant
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			stop_listening()
			get_viewport().set_input_as_handled()
			return
		var keycode := int(key_event.physical_keycode)
		if keycode == 0:
			keycode = int(key_event.keycode)
		binding = keycode
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		binding = {
			"type": "mouse",
			"button_index": int(mouse_event.button_index),
		}
	else:
		return

	KeybindingsSettings.set_binding(listening_action, listening_slot, binding)
	stop_listening()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not listening_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()


func focus_first() -> void:
	for action in KeybindingsSettings.get_actions():
		if binding_buttons.has(action):
			((binding_buttons[action] as Array)[0] as Button).grab_focus()
			return


func build_rows() -> void:
	stop_listening()
	binding_buttons.clear()
	for child in action_grid.get_children():
		child.queue_free()
	for action in KeybindingsSettings.get_actions():
		var label := Label.new()
		label.text = KeybindingsSettings.get_action_label(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_grid.add_child(label)

		var buttons: Array[Button] = []
		for slot in KeybindingsSettings.MAX_BINDINGS:
			var button := Button.new()
			button.custom_minimum_size = Vector2(130.0, 36.0)
			button.pressed.connect(on_bind_pressed.bind(action, slot))
			action_grid.add_child(button)
			buttons.append(button)
		binding_buttons[action] = buttons

		var clear_button := Button.new()
		clear_button.text = "Clear"
		clear_button.custom_minimum_size = Vector2(70.0, 36.0)
		clear_button.pressed.connect(on_clear_pressed.bind(action))
		action_grid.add_child(clear_button)
	refresh_labels()


func refresh_labels() -> void:
	for action in KeybindingsSettings.get_actions():
		if not binding_buttons.has(action):
			continue
		var buttons := binding_buttons[action] as Array
		var bindings := KeybindingsSettings.get_bindings(action)
		for slot in KeybindingsSettings.MAX_BINDINGS:
			if action == listening_action and slot == listening_slot:
				continue
			(buttons[slot] as Button).text = get_binding_label(bindings[slot])


func get_binding_label(binding: Variant) -> String:
	if binding is int:
		var keycode := int(binding)
		return OS.get_keycode_string(keycode as Key) if keycode > 0 else "---"
	if binding is Dictionary and str((binding as Dictionary).get("type", "")) == "mouse":
		var button_index := int((binding as Dictionary).get("button_index", -1))
		match button_index:
			MOUSE_BUTTON_LEFT:
				return "M1"
			MOUSE_BUTTON_RIGHT:
				return "M2"
			MOUSE_BUTTON_MIDDLE:
				return "M3"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel Down"
			_:
				return "M%d" % button_index
	return "---"


func on_bind_pressed(action: String, slot: int) -> void:
	stop_listening()
	listening_action = action
	listening_slot = slot
	((binding_buttons[action] as Array)[slot] as Button).text = LISTENING_TEXT


func stop_listening() -> void:
	listening_action = ""
	listening_slot = -1
	refresh_labels()


func on_clear_pressed(action: String) -> void:
	if listening_action == action:
		stop_listening()
	KeybindingsSettings.clear_action(action)


func on_reset_pressed() -> void:
	stop_listening()
	KeybindingsSettings.reset_to_defaults()


func on_back_pressed() -> void:
	stop_listening()
	back_requested.emit()

extends CenterContainer

signal back_requested

const LISTENING_TEXT := "Press a key..."

@onready var action_grid: GridContainer = $Panel/Margin/VBox/ScrollContainer/ActionGrid
@onready var reset_button: Button = $Panel/Margin/VBox/ButtonRow/ResetButton
@onready var back_button: Button = $Panel/Margin/VBox/ButtonRow/BackButton

var listening_action := ""
var binding_buttons: Dictionary = {}


func _ready() -> void:
	build_rows()
	reset_button.pressed.connect(on_reset_pressed)
	back_button.pressed.connect(on_back_pressed)
	KeybindingsSettings.bindings_changed.connect(refresh_labels)


func _input(event: InputEvent) -> void:
	if listening_action.is_empty() or not event is InputEventKey:
		return
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
	KeybindingsSettings.set_binding(listening_action, keycode)
	stop_listening()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not listening_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()


func focus_first() -> void:
	for action in KeybindingsSettings.ACTIONS:
		if binding_buttons.has(action):
			(binding_buttons[action] as Button).grab_focus()
			return


func build_rows() -> void:
	for action in KeybindingsSettings.ACTIONS:
		var label := Label.new()
		label.text = str(KeybindingsSettings.ACTION_LABELS[action])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_grid.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(180.0, 36.0)
		button.pressed.connect(on_bind_pressed.bind(action))
		action_grid.add_child(button)
		binding_buttons[action] = button
	refresh_labels()


func refresh_labels() -> void:
	for action in KeybindingsSettings.ACTIONS:
		if not binding_buttons.has(action) or action == listening_action:
			continue
		(binding_buttons[action] as Button).text = OS.get_keycode_string(KeybindingsSettings.get_binding(action) as Key)


func on_bind_pressed(action: String) -> void:
	stop_listening()
	listening_action = action
	(binding_buttons[action] as Button).text = LISTENING_TEXT


func stop_listening() -> void:
	listening_action = ""
	refresh_labels()


func on_reset_pressed() -> void:
	stop_listening()
	KeybindingsSettings.reset_to_defaults()


func on_back_pressed() -> void:
	stop_listening()
	back_requested.emit()

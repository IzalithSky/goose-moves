extends CenterContainer

signal back_requested
signal keybindings_requested

@onready var sensitivity_slider: HSlider = $Panel/Margin/VBox/SensitivityRow/SensitivitySlider
@onready var sensitivity_value: Label = $Panel/Margin/VBox/SensitivityRow/SensitivityValue
@onready var fov_slider: HSlider = $Panel/Margin/VBox/FovRow/FovSlider
@onready var fov_value: Label = $Panel/Margin/VBox/FovRow/FovValue
@onready var fullscreen_toggle: CheckButton = $Panel/Margin/VBox/FullscreenToggle
@onready var keybindings_button: Button = $Panel/Margin/VBox/KeybindingsButton
@onready var back_button: Button = $Panel/Margin/VBox/BackButton


func _ready() -> void:
	sensitivity_slider.value_changed.connect(on_sensitivity_changed)
	fov_slider.value_changed.connect(on_fov_changed)
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
	sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	sensitivity_value.text = "%.3f" % Settings.mouse_sensitivity
	fov_slider.set_value_no_signal(Settings.fov)
	fov_value.text = "%d°" % roundi(Settings.fov)
	fullscreen_toggle.set_pressed_no_signal(Settings.fullscreen)


func focus_first() -> void:
	keybindings_button.grab_focus()


func on_sensitivity_changed(value: float) -> void:
	sensitivity_value.text = "%.3f" % value
	Settings.set_mouse_sensitivity(value)


func on_fov_changed(value: float) -> void:
	fov_value.text = "%d°" % roundi(value)
	Settings.set_fov(value)


func on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func on_keybindings_pressed() -> void:
	keybindings_requested.emit()


func on_back_pressed() -> void:
	back_requested.emit()

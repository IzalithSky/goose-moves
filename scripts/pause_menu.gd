extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var menu_root: Control = $MenuRoot
@onready var menu_panel: Control = $MenuRoot/CenterContainer/PausePanel
@onready var resume_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/ResumeButton
@onready var restart_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/RestartButton
@onready var settings_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/SettingsButton
@onready var keybindings_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/KeybindingsButton
@onready var main_menu_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/MainMenuButton
@onready var settings_menu: Control = $MenuRoot/SettingsMenu
@onready var keybindings_menu: Control = $MenuRoot/KeybindingsMenu

var open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(on_resume_pressed)
	restart_button.pressed.connect(on_restart_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	keybindings_button.pressed.connect(on_keybindings_pressed)
	main_menu_button.pressed.connect(on_main_menu_pressed)
	settings_menu.back_requested.connect(on_settings_back_requested)
	settings_menu.keybindings_requested.connect(on_keybindings_requested)
	keybindings_menu.back_requested.connect(on_keybindings_back_requested)
	set_open(false, false)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if keybindings_menu.visible:
		on_keybindings_back_requested()
	elif settings_menu.visible:
		on_settings_back_requested()
	else:
		set_open(not open)
	get_viewport().set_input_as_handled()


func set_open(value: bool, update_mouse_mode := true) -> void:
	open = value
	menu_root.visible = value
	get_tree().paused = value
	if value:
		show_pause_menu()
		if update_mouse_mode:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif update_mouse_mode:
		call_deferred("capture_mouse")


func capture_mouse() -> void:
	if not open and DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_pause_menu() -> void:
	menu_panel.visible = true
	settings_menu.visible = false
	keybindings_menu.visible = false
	resume_button.grab_focus()


func on_resume_pressed() -> void:
	set_open(false)


func on_restart_pressed() -> void:
	set_open(false)
	get_tree().reload_current_scene()


func on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_menu.visible = true
	settings_menu.sync_from_settings()
	settings_menu.focus_first()


func on_keybindings_pressed() -> void:
	menu_panel.visible = false
	settings_menu.visible = false
	keybindings_menu.visible = true
	keybindings_menu.focus_first()


func on_settings_back_requested() -> void:
	show_pause_menu()


func on_keybindings_requested() -> void:
	settings_menu.visible = false
	keybindings_menu.visible = true
	keybindings_menu.focus_first()


func on_keybindings_back_requested() -> void:
	keybindings_menu.visible = false
	settings_menu.visible = true
	settings_menu.sync_from_settings()
	settings_menu.focus_first()


func on_main_menu_pressed() -> void:
	set_open(false, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

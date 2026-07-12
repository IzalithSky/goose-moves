extends Control

const LEVEL_SCENE := "res://scenes/primitive_test_level.tscn"

@onready var menu_panel: Control = $CenterContainer/MainPanel
@onready var start_button: Button = $CenterContainer/MainPanel/Margin/VBox/StartButton
@onready var settings_button: Button = $CenterContainer/MainPanel/Margin/VBox/SettingsButton
@onready var keybindings_button: Button = $CenterContainer/MainPanel/Margin/VBox/KeybindingsButton
@onready var quit_button: Button = $CenterContainer/MainPanel/Margin/VBox/QuitButton
@onready var settings_menu: Control = $SettingsMenu
@onready var keybindings_menu: Control = $KeybindingsMenu


func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	keybindings_button.pressed.connect(on_keybindings_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	settings_menu.back_requested.connect(on_settings_back_requested)
	settings_menu.keybindings_requested.connect(on_keybindings_requested)
	keybindings_menu.back_requested.connect(on_keybindings_back_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_main_menu()


func show_main_menu() -> void:
	menu_panel.visible = true
	settings_menu.visible = false
	keybindings_menu.visible = false
	start_button.grab_focus()


func on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


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
	show_main_menu()


func on_keybindings_requested() -> void:
	settings_menu.visible = false
	keybindings_menu.visible = true
	keybindings_menu.focus_first()


func on_keybindings_back_requested() -> void:
	keybindings_menu.visible = false
	settings_menu.visible = true
	settings_menu.sync_from_settings()
	settings_menu.focus_first()


func on_quit_pressed() -> void:
	get_tree().quit()

extends Camera3D

# Runtime values; overwritten from Settings in _ready and on settings_changed.
var move_speed := 12.0
var mouse_sensitivity := 0.003

var pitch := 0.0
var yaw := 0.0


func _ready() -> void:
	pitch = rotation.x
	yaw = rotation.y
	_apply_controller_settings()
	Settings.settings_changed.connect(on_settings_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var input_vector := Vector3(
		Input.get_action_strength("player_right") - Input.get_action_strength("player_left"),
		Input.get_action_strength("player_jump") - Input.get_action_strength("player_crouch"),
		Input.get_action_strength("player_forward") - Input.get_action_strength("player_back"),
	)
	if input_vector.is_zero_approx():
		return

	input_vector = input_vector.normalized()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var movement_direction := (right * input_vector.x) + (Vector3.UP * input_vector.y) + (forward * input_vector.z)
	global_position += movement_direction.normalized() * move_speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - (event.relative.y * mouse_sensitivity), deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation = Vector3(pitch, yaw, 0.0)


func on_settings_changed() -> void:
	_apply_controller_settings()


func _apply_controller_settings() -> void:
	move_speed = Settings.get_controller_setting("move_speed", Settings.CHARACTER_SPECTATOR)
	mouse_sensitivity = Settings.get_controller_setting("mouse_sensitivity", Settings.CHARACTER_SPECTATOR)
	fov = Settings.get_controller_setting("fov", Settings.CHARACTER_SPECTATOR)

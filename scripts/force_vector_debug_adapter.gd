class_name ForceVectorDebugAdapter
extends RefCounted

const VISUALIZER_SCRIPT := preload("res://scripts/force_vector_visualizer_3d.gd")
const SETTING_KEY := "debug_force_vectors"
const COLOR_NET_ACCELERATION := Color(1.0, 0.55, 0.1)

var target: Node3D
var settings_controller_id := ""
var renderer: MeshInstance3D
var active := true
var _enabled := false


func _init(target_node: Node3D, controller_id: String) -> void:
	target = target_node
	settings_controller_id = controller_id
	sync_from_settings()


func sync_from_settings() -> void:
	if target == null:
		return

	_enabled = active and Settings.get_controller_setting(SETTING_KEY, settings_controller_id) >= 0.5
	if not _enabled:
		if renderer != null:
			renderer.queue_free()
			renderer = null
		return

	ensure_renderer()


func is_enabled() -> bool:
	return _enabled


func set_active(value: bool) -> void:
	if active == value:
		return

	active = value
	sync_from_settings()


func is_rendering() -> bool:
	return renderer != null and renderer.visible


func ensure_renderer() -> void:
	if not is_enabled() or target == null:
		return
	if renderer != null:
		return

	renderer = VISUALIZER_SCRIPT.new()
	renderer.name = "ForceVectorVisualizer3D"
	target.add_child(renderer)
	renderer.visible = true


func begin_frame() -> void:
	# Enabled state is synced via the settings_changed signal, not re-read per frame (perf).
	if not is_rendering():
		return

	renderer.begin_frame()


func push_vector(origin_world: Vector3, vector_world: Vector3, color: Color, vector_scale_override := -1.0) -> void:
	if not is_rendering():
		return

	renderer.push_vector(origin_world, vector_world, color, vector_scale_override)


func push_velocity_change(
	origin_world: Vector3,
	previous_velocity: Vector3,
	current_velocity: Vector3,
	delta: float,
	color := COLOR_NET_ACCELERATION
) -> void:
	if delta <= 0.0:
		return

	push_vector(origin_world, (current_velocity - previous_velocity) / delta, color)


func end_frame() -> void:
	if not is_rendering():
		return

	renderer.end_frame()


func clear_frame() -> void:
	if renderer == null:
		return

	renderer.clear_frame()

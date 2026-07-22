extends Node3D

const Q3_CHARACTER_CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const PLATFORMER_CONTROLLER_SCENE := preload("res://scenes/platformer_controller.tscn")
const FLIGHT_CONTROLLER_SCENE := preload("res://scenes/flight_controller.tscn")
const Q3_N_FLIGHT_CONTROLLER_SCENE := preload("res://scenes/q3_n_flight_controller.tscn")
const SPECTATOR_CAMERA_SCENE := preload("res://scenes/spectator_camera.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const DEFAULT_Q3_POSITION := Vector3(0.0, 1.0, 20.0)
const ROOM_WALL_THICKNESS := 0.35
const PARKING_FLOOR_THICKNESS := 0.32
const LABELED_FIXTURE_ROOTS := [
	"Cubes",
	"Stairs",
	"Ramps",
	"Kerbs",
	"LimitSlopes",
	"SurfaceFlags",
	"PlatformerSurfaces",
	"SurfaceClassSlopes",
	"Volumes",
	"Rooms",
	"ParkingStructure",
]
const Q3_STANDING_EYE_RATIO := (
	Q3CharacterController.Q3_STANDING_EYE_HEIGHT
	/ Q3CharacterController.Q3_STANDING_HULL_HEIGHT
)

var active_character: Node3D
var active_character_id := ""


func _ready() -> void:
	_build_extended_test_structures()
	_add_fixture_labels()
	Settings.settings_changed.connect(on_settings_changed)
	_spawn_character(Settings.character_controller, _default_view_transform())
	add_child(PAUSE_MENU_SCENE.instantiate())


func _build_extended_test_structures() -> void:
	var wall_material := _make_material(Color(0.44, 0.48, 0.54, 1.0))
	var floor_material := _make_material(Color(0.25, 0.29, 0.34, 1.0))
	var ramp_material := _make_material(Color(0.72, 0.52, 0.32, 1.0))
	var stair_material := _make_material(Color(0.36, 0.56, 0.75, 1.0))
	var rail_material := _make_material(Color(0.76, 0.47, 0.40, 1.0))
	var rooms_root := Node3D.new()
	rooms_root.name = "Rooms"
	add_child(rooms_root)
	_add_room(
		rooms_root,
		"SmallRoom",
		Vector3(-62.0, 0.0, -62.0),
		Vector2(10.0, 8.0),
		3.2,
		[
			{"side": "south", "offset": 0.0, "width": 1.2, "height": 2.1},
		],
		wall_material
	)
	_add_room(
		rooms_root,
		"MediumRoom",
		Vector3(-44.0, 0.0, -64.0),
		Vector2(15.0, 12.0),
		4.0,
		[
			{"side": "south", "offset": -4.0, "width": 2.0, "height": 2.5},
			{"side": "east", "offset": 1.5, "width": 3.0, "height": 3.2},
		],
		wall_material
	)
	_add_room(
		rooms_root,
		"LargeHall",
		Vector3(-20.0, 0.0, -66.0),
		Vector2(24.0, 16.0),
		5.0,
		[
			{"side": "west", "offset": -4.0, "width": 1.6, "height": 2.1},
			{"side": "south", "offset": 5.0, "width": 4.5, "height": 3.6},
			{"side": "north", "offset": -6.0, "width": 6.0, "height": 4.2},
		],
		wall_material
	)
	_build_parking_structure(floor_material, wall_material, ramp_material, stair_material, rail_material)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _add_room(
	parent: Node3D,
	room_name: String,
	center: Vector3,
	footprint: Vector2,
	wall_height: float,
	doorways: Array,
	wall_material: Material
) -> void:
	var room := Node3D.new()
	room.name = room_name
	parent.add_child(room)
	for side in ["north", "south", "east", "west"]:
		_add_room_wall(room, room_name, center, footprint, wall_height, side, doorways, wall_material)


func _add_room_wall(
	parent: Node3D,
	room_name: String,
	center: Vector3,
	footprint: Vector2,
	wall_height: float,
	side: String,
	doorways: Array,
	material: Material
) -> void:
	var doorway := _find_doorway(doorways, side)
	if doorway.is_empty():
		_add_solid_room_wall(parent, room_name, center, footprint, wall_height, side, material)
		return
	var length := footprint.x if side in ["north", "south"] else footprint.y
	var offset := float(doorway["offset"])
	var width := minf(float(doorway["width"]), length - 1.0)
	var height := minf(float(doorway["height"]), wall_height)
	var min_edge := -length * 0.5
	var max_edge := length * 0.5
	var door_min := clampf(offset - (width * 0.5), min_edge, max_edge)
	var door_max := clampf(offset + (width * 0.5), min_edge, max_edge)
	_add_room_wall_segment(
		parent, "%s%sLeftJamb" % [room_name, side.capitalize()], center, footprint, wall_height,
		side, min_edge, door_min, material
	)
	_add_room_wall_segment(
		parent, "%s%sRightJamb" % [room_name, side.capitalize()], center, footprint, wall_height,
		side, door_max, max_edge, material
	)
	if height < wall_height:
		_add_room_header(parent, room_name, center, footprint, wall_height, side, door_min, door_max, height, material)


func _find_doorway(doorways: Array, side: String) -> Dictionary:
	for doorway in doorways:
		if str(doorway["side"]) == side:
			return doorway
	return {}


func _add_solid_room_wall(
	parent: Node3D,
	room_name: String,
	center: Vector3,
	footprint: Vector2,
	wall_height: float,
	side: String,
	material: Material
) -> void:
	var wall_position := Vector3(center.x, center.y + (wall_height * 0.5), center.z)
	var size := Vector3(ROOM_WALL_THICKNESS, wall_height, ROOM_WALL_THICKNESS)
	if side == "north" or side == "south":
		wall_position.z += (-footprint.y * 0.5) if side == "north" else (footprint.y * 0.5)
		size.x = footprint.x + ROOM_WALL_THICKNESS
	else:
		wall_position.x += (footprint.x * 0.5) if side == "east" else (-footprint.x * 0.5)
		size.z = footprint.y + ROOM_WALL_THICKNESS
	_add_unlabeled_box(parent, "%s%sWall" % [room_name, side.capitalize()], wall_position, size, material)


func _add_room_wall_segment(
	parent: Node3D,
	segment_name: String,
	center: Vector3,
	footprint: Vector2,
	wall_height: float,
	side: String,
	start: float,
	end: float,
	material: Material
) -> void:
	var segment_length := end - start
	if segment_length <= 0.05:
		return
	var segment_center := (start + end) * 0.5
	var wall_position := Vector3(center.x, center.y + (wall_height * 0.5), center.z)
	var size := Vector3(ROOM_WALL_THICKNESS, wall_height, ROOM_WALL_THICKNESS)
	if side == "north" or side == "south":
		wall_position.x += segment_center
		wall_position.z += (-footprint.y * 0.5) if side == "north" else (footprint.y * 0.5)
		size.x = segment_length
	else:
		wall_position.x += (footprint.x * 0.5) if side == "east" else (-footprint.x * 0.5)
		wall_position.z += segment_center
		size.z = segment_length
	_add_unlabeled_box(parent, segment_name, wall_position, size, material)


func _add_room_header(
	parent: Node3D,
	room_name: String,
	center: Vector3,
	footprint: Vector2,
	wall_height: float,
	side: String,
	door_min: float,
	door_max: float,
	door_height: float,
	material: Material
) -> void:
	var header_height := wall_height - door_height
	var wall_position := Vector3(center.x, center.y + door_height + (header_height * 0.5), center.z)
	var size := Vector3(ROOM_WALL_THICKNESS, header_height, ROOM_WALL_THICKNESS)
	if side == "north" or side == "south":
		wall_position.x += (door_min + door_max) * 0.5
		wall_position.z += (-footprint.y * 0.5) if side == "north" else (footprint.y * 0.5)
		size.x = door_max - door_min
	else:
		wall_position.x += (footprint.x * 0.5) if side == "east" else (-footprint.x * 0.5)
		wall_position.z += (door_min + door_max) * 0.5
		size.z = door_max - door_min
	_add_unlabeled_box(parent, "%s%sDoorHeader" % [room_name, side.capitalize()], wall_position, size, material)


func _build_parking_structure(
	floor_material: Material,
	wall_material: Material,
	ramp_material: Material,
	stair_material: Material,
	rail_material: Material
) -> void:
	var root := Node3D.new()
	root.name = "ParkingStructure"
	add_child(root)
	var center := Vector3(58.0, 0.0, -60.0)
	var deck_size := Vector2(38.0, 26.0)
	var level_height := 4.2
	for level in 3:
		var floor_y := level * level_height
		if level > 0:
			_add_parking_floor(
				root,
				level,
				center,
				deck_size,
				floor_y,
				_parking_floor_openings(level),
				floor_material
			)
		_add_parking_columns(root, center, deck_size, floor_y, level_height, level, wall_material)
		_add_parking_rails(root, center, deck_size, floor_y, level, rail_material)
	_add_ramp(
		root,
		"ParkingRampLevel1To2",
		Vector3(center.x - 10.0, 1.88, center.z + 0.0),
		Vector3(8.0, 0.45, 16.5),
		deg_to_rad(14.75),
		ramp_material
	)
	_add_ramp(
		root,
		"ParkingRampLevel2To3",
		Vector3(center.x + 10.0, level_height + 1.88, center.z + 0.0),
		Vector3(8.0, 0.45, 16.5),
		deg_to_rad(-14.75),
		ramp_material
	)
	_add_stair_run(
		root,
		"ParkingStairsLevel1To2",
		Vector3(center.x + 15.5, 0.0, center.z - 11.0),
		level_height,
		12,
		4.0,
		12.0,
		stair_material
	)
	_add_stair_run(
		root,
		"ParkingStairsLevel2To3",
		Vector3(center.x - 15.5, level_height, center.z - 11.0),
		level_height,
		14,
		4.0,
		12.0,
		stair_material
	)


func _parking_floor_openings(level: int) -> Array:
	if level == 1:
		return [
			Rect2(Vector2(-16.0, -10.0), Vector2(12.0, 20.0)),
			Rect2(Vector2(13.0, -12.5), Vector2(5.0, 14.0)),
		]
	if level == 2:
		return [
			Rect2(Vector2(4.0, -10.0), Vector2(12.0, 20.0)),
			Rect2(Vector2(-18.0, -12.5), Vector2(5.0, 14.0)),
		]
	return []


func _add_parking_floor(
	parent: Node3D,
	level: int,
	center: Vector3,
	deck_size: Vector2,
	floor_y: float,
	openings: Array,
	material: Material
) -> void:
	var x_edges := [-deck_size.x * 0.5, deck_size.x * 0.5]
	var z_edges := [-deck_size.y * 0.5, deck_size.y * 0.5]
	for opening in openings:
		_add_unique_edge(x_edges, clampf(opening.position.x, x_edges[0], x_edges[1]))
		_add_unique_edge(x_edges, clampf(opening.position.x + opening.size.x, x_edges[0], x_edges[1]))
		_add_unique_edge(z_edges, clampf(opening.position.y, z_edges[0], z_edges[1]))
		_add_unique_edge(z_edges, clampf(opening.position.y + opening.size.y, z_edges[0], z_edges[1]))
	x_edges.sort()
	z_edges.sort()
	var piece_index := 1
	for x_index in x_edges.size() - 1:
		for z_index in z_edges.size() - 1:
			var min_x := float(x_edges[x_index])
			var max_x := float(x_edges[x_index + 1])
			var min_z := float(z_edges[z_index])
			var max_z := float(z_edges[z_index + 1])
			if max_x - min_x <= 0.05 or max_z - min_z <= 0.05:
				continue
			var piece_center := Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
			if _point_in_any_rect(piece_center, openings):
				continue
			_add_unlabeled_box(
				parent,
				"ParkingLevel%sFloorPiece%s" % [level + 1, piece_index],
				Vector3(center.x + piece_center.x, floor_y - (PARKING_FLOOR_THICKNESS * 0.5), center.z + piece_center.y),
				Vector3(max_x - min_x, PARKING_FLOOR_THICKNESS, max_z - min_z),
				material
			)
			piece_index += 1


func _add_unique_edge(edges: Array, edge: float) -> void:
	for existing_edge in edges:
		if absf(float(existing_edge) - edge) <= 0.01:
			return
	edges.append(edge)


func _point_in_any_rect(point: Vector2, rects: Array) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false


func _add_parking_columns(
	parent: Node3D,
	center: Vector3,
	deck_size: Vector2,
	floor_y: float,
	level_height: float,
	level: int,
	material: Material
) -> void:
	if level >= 2:
		return
	var x_offsets := [-deck_size.x * 0.35, 0.0, deck_size.x * 0.35]
	var z_offsets := [-deck_size.y * 0.35, deck_size.y * 0.35]
	for x_offset in x_offsets:
		for z_offset in z_offsets:
			_add_unlabeled_box(
				parent,
				"ParkingColumn%s_%s_%s" % [level + 1, int(x_offset), int(z_offset)],
				Vector3(center.x + x_offset, floor_y + (level_height * 0.5), center.z + z_offset),
				Vector3(0.65, level_height, 0.65),
				material
			)


func _add_parking_rails(
	parent: Node3D,
	center: Vector3,
	deck_size: Vector2,
	floor_y: float,
	level: int,
	material: Material
) -> void:
	if level == 0:
		return
	var rail_y := floor_y + 0.55
	_add_unlabeled_box(
		parent,
		"ParkingLevel%sNorthRail" % [level + 1],
		Vector3(center.x, rail_y, center.z - (deck_size.y * 0.5)),
		Vector3(deck_size.x, 1.1, 0.35),
		material
	)
	_add_unlabeled_box(
		parent,
		"ParkingLevel%sSouthRail" % [level + 1],
		Vector3(center.x, rail_y, center.z + (deck_size.y * 0.5)),
		Vector3(deck_size.x, 1.1, 0.35),
		material
	)
	_add_unlabeled_box(
		parent,
		"ParkingLevel%sWestRail" % [level + 1],
		Vector3(center.x - (deck_size.x * 0.5), rail_y, center.z),
		Vector3(0.35, 1.1, deck_size.y),
		material
	)
	_add_unlabeled_box(
		parent,
		"ParkingLevel%sEastRail" % [level + 1],
		Vector3(center.x + (deck_size.x * 0.5), rail_y, center.z),
		Vector3(0.35, 1.1, deck_size.y),
		material
	)


func _add_stair_run(
	parent: Node3D,
	stair_name: String,
	start: Vector3,
	height: float,
	step_count: int,
	width: float,
	run: float,
	material: Material
) -> void:
	var step_depth := run / step_count
	var step_height := height / step_count
	for step_index in step_count:
		var top_height := step_height * float(step_index + 1)
		_add_unlabeled_box(
			parent,
			"%sStep%s" % [stair_name, step_index + 1],
			Vector3(
				start.x,
				start.y + (top_height * 0.5),
				start.z + (step_depth * (float(step_index) + 0.5))
			),
			Vector3(width, top_height, step_depth),
			material
		)


func _add_ramp(
	parent: Node3D,
	ramp_name: String,
	local_position: Vector3,
	size: Vector3,
	rotation_x: float,
	material: Material
) -> void:
	var ramp := _add_box(parent, ramp_name, local_position, size, material)
	ramp.rotation.x = rotation_x


func _add_unlabeled_box(
	parent: Node3D,
	box_name: String,
	local_position: Vector3,
	size: Vector3,
	material: Material
) -> CSGBox3D:
	var box := _add_box(parent, box_name, local_position, size, material)
	box.set_meta("fixture_label", false)
	return box


func _add_box(
	parent: Node3D,
	box_name: String,
	local_position: Vector3,
	size: Vector3,
	material: Material
) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.position = local_position
	box.use_collision = true
	box.size = size
	box.material = material
	parent.add_child(box)
	return box


func on_settings_changed() -> void:
	if active_character_id != Settings.character_controller:
		_swap_character(Settings.character_controller)


func _swap_character(character_id: String) -> void:
	var view_transform := _active_view_transform()
	if active_character:
		remove_child(active_character)
		active_character.queue_free()
		active_character = null
	_spawn_character(character_id, view_transform)


func _spawn_character(character_id: String, view_transform: Transform3D) -> void:
	active_character_id = character_id if character_id in Settings.CONTROLLER_SECTIONS else Settings.CHARACTER_Q3
	if active_character_id == Settings.CHARACTER_SPECTATOR:
		active_character = SPECTATOR_CAMERA_SCENE.instantiate() as Node3D
		active_character.transform = view_transform
	elif active_character_id == Settings.CHARACTER_PLATFORMER:
		active_character = PLATFORMER_CONTROLLER_SCENE.instantiate() as Node3D
		active_character.call("place_at_view", view_transform)
	elif active_character_id == Settings.CHARACTER_FLIGHT:
		active_character = FLIGHT_CONTROLLER_SCENE.instantiate() as Node3D
		active_character.call("place_at_view", view_transform)
	elif active_character_id == Settings.CHARACTER_Q3_N_FLIGHT:
		active_character = Q3_N_FLIGHT_CONTROLLER_SCENE.instantiate() as Node3D
		active_character.call("place_at_view", view_transform)
	else:
		active_character = Q3_CHARACTER_CONTROLLER_SCENE.instantiate() as Node3D
		_place_q3_at_view(active_character, view_transform)
	add_child(active_character)
	if get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _default_view_transform() -> Transform3D:
	var view_transform := Transform3D.IDENTITY
	view_transform.origin = DEFAULT_Q3_POSITION + (Vector3.UP * _get_q3_eye_height())
	return view_transform


func _active_view_transform() -> Transform3D:
	if not active_character:
		return _default_view_transform()
	if active_character_id == Settings.CHARACTER_Q3:
		var q3_character := active_character as Q3CharacterController
		var camera := (
			q3_character.third_person_camera
			if q3_character.third_person_enabled
			else q3_character.camera
		)
		if camera:
			return camera.global_transform
	if active_character_id == Settings.CHARACTER_PLATFORMER:
		var platformer_camera := active_character.call("get_view_camera") as Camera3D
		return platformer_camera.global_transform
	if active_character_id == Settings.CHARACTER_FLIGHT:
		var flight_camera := active_character.call("get_view_camera") as Camera3D
		return flight_camera.global_transform
	if active_character_id == Settings.CHARACTER_Q3_N_FLIGHT:
		var hybrid_camera := active_character.call("get_view_camera") as Camera3D
		return hybrid_camera.global_transform
	return active_character.global_transform


func _place_q3_at_view(character: Node3D, view_transform: Transform3D) -> void:
	var euler := view_transform.basis.get_euler()
	character.position = view_transform.origin - (Vector3.UP * _get_q3_eye_height())
	character.rotation = Vector3(0.0, euler.y, 0.0)
	var head := character.get_node_or_null("Head") as Node3D
	if head:
		head.rotation = Vector3(euler.x, 0.0, 0.0)


func _get_q3_eye_height() -> float:
	return (
		Settings.get_controller_setting("character_size_y", Settings.CHARACTER_Q3)
		* Q3_STANDING_EYE_RATIO
	)


func _add_fixture_labels() -> void:
	var labels_root := $FixtureLabels as Node3D
	for root_path in LABELED_FIXTURE_ROOTS:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		for fixture in root.get_children():
			_add_fixture_label_recursive(labels_root, fixture)


func _add_fixture_label_recursive(labels_root: Node3D, fixture: Node) -> void:
	if fixture is CSGBox3D or fixture is Area3D:
		if bool(fixture.get_meta("fixture_label", true)):
			_add_fixture_label(labels_root, fixture as Node3D)
		return
	for child in fixture.get_children():
		_add_fixture_label_recursive(labels_root, child)


func _add_fixture_label(labels_root: Node3D, fixture: Node3D) -> void:
	var label := Label3D.new()
	label.name = "%sLabel" % fixture.name
	label.text = _fixture_label_text(fixture)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.no_depth_test = false
	label.pixel_size = 0.012
	label.font_size = 42
	label.outline_size = 10
	label.modulate = Color(1.0, 0.96, 0.78, 1.0)
	label.set_meta("fixture_path", fixture.get_path())
	labels_root.add_child(label)
	label.global_position = fixture.global_position + (Vector3.UP * _fixture_label_height(fixture))


func _fixture_label_text(fixture: Node) -> String:
	return _humanize_name(str(fixture.name))


func _fixture_label_height(fixture: Node3D) -> float:
	if fixture is CSGBox3D:
		var box := fixture as CSGBox3D
		var half_size := box.size * 0.5
		var fixture_basis := box.global_transform.basis
		return (
			absf(fixture_basis.x.y) * half_size.x
			+ absf(fixture_basis.y.y) * half_size.y
			+ absf(fixture_basis.z.y) * half_size.z
			+ 0.65
		)
	if fixture is Area3D:
		var shape_node := fixture.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return (shape_node.shape as BoxShape3D).size.y * 0.5 + 0.65
	return 1.0


func _humanize_name(value: String) -> String:
	var result := ""
	for index in value.length():
		var character := value[index]
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			result += " "
		result += character
	return result.replace("_", " ")

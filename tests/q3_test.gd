extends Node3D
# Base for headless test scenes (see docs/testing.md).
# Subclasses override step(), which runs once per physics frame, and call
# finish() when done. The process exits 0 only when every check passed and
# every known-deviation xfail still fails (strict: a fixed deviation XPASSes
# and must be promoted to a hard check).

const DT := 1.0 / 60.0
const MAX_PHYSICS_FRAMES := 900

var frame := 0
var checks := 0
var failures := PackedStringArray()
var known_deviations := 0
var _done := false


func _physics_process(_delta: float) -> void:
	if _done:
		return
	frame += 1
	if frame > MAX_PHYSICS_FRAMES:
		fail("timeout: finish() not reached in %d physics frames" % MAX_PHYSICS_FRAMES)
		finish()
		return
	step()


func step() -> void:
	pass


func fail(label: String) -> void:
	failures.append(label)
	printerr("  FAIL  ", label)


func check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  ok    ", label)
	else:
		fail(label)


func check_known_deviation(label: String, ok_when_fixed: bool) -> void:
	# A Q3-correct assertion the port knowingly fails; documented in
	# docs/testing.md. Strict xfail: once the deviation is fixed this XPASSes
	# and fails the suite until promoted to check().
	checks += 1
	if ok_when_fixed:
		fail("XPASS (deviation fixed? promote to check): " + label)
	else:
		known_deviations += 1
		print("  xfail ", label)


func check_approx(label: String, got: float, want: float, tolerance := 1e-4) -> void:
	check("%s (got %f, want %f ±%f)" % [label, got, want, tolerance], absf(got - want) <= tolerance)


func check_vec3(label: String, got: Vector3, want: Vector3, tolerance := 1e-4) -> void:
	check("%s (got %s, want %s ±%f)" % [label, got, want, tolerance], (got - want).length() <= tolerance)


func finish() -> void:
	if _done:
		return
	_done = true
	var suite: String = (get_script() as Script).resource_path.get_file()
	if failures.is_empty():
		print("PASS %s — %d checks, %d known-deviation xfails" % [suite, checks, known_deviations])
	else:
		printerr("FAIL %s — %d of %d checks failed" % [suite, failures.size(), checks])
	get_tree().quit(0 if failures.is_empty() else 1)


# --- fixtures -----------------------------------------------------------------

func add_static_box(size: Vector3, xform: Transform3D, slick := false) -> StaticBody3D:
	var static_body := StaticBody3D.new()
	if slick:
		static_body.set_meta("q3_surface", &"slick")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	static_body.add_child(shape)
	add_child(static_body)
	static_body.global_transform = xform
	return static_body


func add_probe_body() -> CharacterBody3D:
	# Bare CharacterBody3D with the controller's hull and floor settings.
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.143, 2.1336, 1.143)
	shape.shape = box
	shape.position = Vector3(0, 1.0668, 0)
	body.add_child(shape)
	add_child(body)
	body.floor_max_angle = deg_to_rad(45.572996)
	body.floor_stop_on_slope = false
	body.floor_snap_length = 0.6858
	return body

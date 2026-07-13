extends "res://tests/q3_test.gd"

const CONTROLLER_SCENE := preload("res://scenes/platformer_controller.tscn")

var controller


func _ready() -> void:
	controller = CONTROLLER_SCENE.instantiate()
	add_child(controller)
	controller.set_physics_process(false)
	controller.set_process(false)
	_reset_runtime_values()


func step() -> void:
	_constants_and_scale()
	_ground_acceleration()
	_polar_turning()
	_turnaround_braking()
	_coordinate_directions()
	_slide_steering()
	_air_control()
	_action_momentum()
	_state_transitions()
	_surface_classes()
	_swimming()
	finish()


func _constants_and_scale() -> void:
	check_approx("source simulation rate is 30 fps", controller.SOURCE_FPS, 30.0)
	check_approx("maximum target speed is 32 u/f", controller.max_run_speed, 32.0)
	check_approx("slow surface target speed is 24 u/f", controller.slow_surface_speed, 24.0)
	check_approx("normal jump starts at 42 u/f", controller.jump_velocity, 42.0)
	check_approx("gravity is 4 u/f²", controller.gravity, 4.0)
	check_approx("one source unit converts to 0.0125 m",
		controller.source_units_to_meters(1.0), 0.0125)
	check_approx("metres convert back to source units",
		controller.meters_to_source_units(1.25), 100.0)
	check_approx("30-unit lower wall offset converts to 0.375 m",
		controller.source_units_to_meters(controller.GROUND_LOWER_WALL_PROBE_OFFSET_UNITS), 0.375)
	check_approx("24-unit lower wall radius converts to 0.3 m",
		controller.source_units_to_meters(controller.GROUND_LOWER_WALL_PROBE_RADIUS_UNITS), 0.3)
	check_approx("60-unit upper wall offset converts to 0.75 m",
		controller.source_units_to_meters(controller.GROUND_UPPER_WALL_PROBE_OFFSET_UNITS), 0.75)
	check_approx("150-unit air wall offset converts to 1.875 m",
		controller.source_units_to_meters(controller.AIR_UPPER_WALL_PROBE_OFFSET_UNITS), 1.875)
	check_approx("110-unit swim wall radius converts to 1.375 m",
		controller.source_units_to_meters(controller.SWIM_WALL_PROBE_RADIUS_UNITS), 1.375)
	check_approx("100-unit floor snap converts to 1.25 m",
		controller.source_units_to_meters(controller.DROP_SNAP_UNITS), 1.25)
	check_approx("160-unit clearance converts to 2 m", controller.DEFAULT_HEIGHT, 2.0)
	check_approx("50-unit body radius converts to 0.625 m", controller.DEFAULT_RADIUS, 0.625)
	check_approx("42 u/f converts to 15.75 m/s",
		controller.source_speed_to_mps(42.0), 15.75)
	check_approx("4 u/f² converts to 45 m/s²",
		controller.source_acceleration_to_mps2(4.0), 45.0)
	check_approx("metres per second convert back to source speed",
		controller.mps_to_source_speed(15.75), 42.0)
	controller.face_yaw = PI * 0.5
	controller.forward_speed = 32.0
	controller.vertical_speed = 0.0
	controller._sync_slide_from_forward()
	controller._apply_motion_velocity()
	check_approx("32 u/f converts to 12 m/s at the project scale", controller.velocity.x, 12.0)


func _ground_acceleration() -> void:
	controller.current_surface = &"default"
	controller.quicksand_depth = 0.0
	controller.forward_speed = 0.0
	controller.face_yaw = 0.0
	controller._update_walking_speed(1.0, 32.0, 0.0, Vector3.UP)
	check_approx("walking adds 1.1 u/f from rest", controller.forward_speed, 1.1)

	controller.forward_speed = 10.0
	controller._update_walking_speed(1.0, 32.0, 0.0, Vector3.UP)
	check_approx("walking acceleration fades by speed/43", controller.forward_speed, 11.1 - (10.0 / 43.0))

	controller.current_surface = &"slow"
	controller.forward_speed = 30.0
	controller._update_walking_speed(1.0, 32.0, 0.0, Vector3.UP)
	check_approx("slow floor caps target at 24 and decelerates overspeed", controller.forward_speed, 29.0)

	controller.current_surface = &"quicksand"
	controller.quicksand_depth = 50.0
	controller.forward_speed = 8.0
	controller._update_walking_speed(1.0, 32.0, 0.0, Vector3.UP)
	check_approx("deep quicksand scales target speed by 6.25/depth", controller.forward_speed, 7.0)


func _polar_turning() -> void:
	controller.current_surface = &"default"
	controller.quicksand_depth = 0.0
	controller.forward_speed = 4.0
	controller.face_yaw = 0.0
	controller._update_walking_speed(1.0, 32.0, PI, Vector3.UP)
	check_approx("ground facing turns at 0x800 = 11.25 degrees per frame",
		absf(controller.face_yaw), deg_to_rad(11.25))
	controller._sync_slide_from_forward()
	var polar_direction := Vector2(sin(controller.face_yaw), cos(controller.face_yaw)).normalized()
	check("velocity direction is derived from facing",
		controller.slide_velocity.normalized().dot(polar_direction) > 0.9999)


func _turnaround_braking() -> void:
	controller.current_surface = &"default"
	controller.action = controller.Action.TURNING_AROUND
	controller.face_yaw = 0.0
	controller.forward_speed = 20.0
	check("input beyond 100 degrees enters the turnaround cone",
		controller._input_is_held_back(deg_to_rad(101.0)))
	check("input at 100 degrees stays outside the turnaround cone",
		not controller._input_is_held_back(deg_to_rad(100.0)))
	controller._update_turning_around(1.0, 32.0, PI, Vector3.UP)
	check_approx("default turnaround braking removes 4 u/f",
		controller.forward_speed, 16.0)
	controller.forward_speed = 2.0
	controller._update_turning_around(1.0, 32.0, PI, Vector3.UP)
	check("finished turnaround returns to walking", controller.action == controller.Action.WALKING)
	check_approx("finished turnaround starts at 8 u/f", controller.forward_speed, 8.0)
	check_approx("finished turnaround faces the held direction", controller.face_yaw, PI)
	controller.action = controller.Action.TURNING_AROUND
	controller.forward_speed = 12.0
	controller._start_ground_jump(32.0, PI)
	check("jumping during turnaround selects side flip", controller.action == controller.Action.SIDE_FLIP)


func _coordinate_directions() -> void:
	check_vec3("yaw zero maps source forward to Godot +Z",
		controller._forward_vector(0.0), Vector3.BACK)
	check_vec3("positive quarter-turn maps source right to Godot +X",
		controller._forward_vector(PI * 0.5), Vector3.RIGHT)
	check_approx("Godot +X maps back to positive quarter-turn",
		controller._yaw_from_direction(Vector3.RIGHT), PI * 0.5)
	var camera_forward: Vector3 = controller._get_camera_relative_direction(Vector2.DOWN, false)
	var camera_right: Vector3 = controller._get_camera_relative_direction(Vector2.RIGHT, false)
	check_vec3("forward input follows the Godot camera -Z axis", camera_forward, Vector3.FORWARD)
	check_vec3("right input follows the Godot camera +X axis", camera_right, Vector3.RIGHT)


func _slide_steering() -> void:
	controller.slide_velocity = Vector2(0.0, 20.0)
	controller._apply_slide_steering(1.0, 1.0, 1.0)
	check("right input steers a +Z slide toward Godot +X", controller.slide_velocity.x > 0.0)
	check_approx("slide steering preserves speed", controller.slide_velocity.length(), 20.0)


func _air_control() -> void:
	controller.action = controller.Action.JUMP
	controller.face_yaw = 0.0
	controller.forward_speed = 20.0
	var horizontal: Vector2 = controller._update_air_without_turn(1.0, 32.0, 0.0)
	check_approx("air drag applies before forward acceleration", controller.forward_speed, 21.15)
	check_vec2("forward air input remains facing-aligned", horizontal, Vector2(0.0, 21.15))

	controller.forward_speed = 40.0
	horizontal = controller._update_air_without_turn(1.0, 32.0, 0.0)
	check_approx("uncapped forward air speed has net +0.15 above threshold", controller.forward_speed, 40.15)

	controller.forward_speed = 20.0
	horizontal = controller._update_air_without_turn(1.0, 32.0, PI * 0.5)
	check_approx("perpendicular air input does not build forward speed", controller.forward_speed, 19.65)
	check_approx("perpendicular air input adds transient 10 u/f sideways", horizontal.x, 10.0)
	check_approx("transient sideways input leaves polar forward component intact", horizontal.y, 19.65)


func _action_momentum() -> void:
	Input.action_release("player_crouch")
	controller.jump_chain = 0
	controller.forward_speed = 20.0
	controller.face_yaw = 0.0
	controller._start_ground_jump(32.0, 0.0)
	check("ordinary jump selects jump action", controller.action == controller.Action.JUMP)
	check_approx("ordinary jump preserves 80% forward speed", controller.forward_speed, 16.0)
	check_approx("ordinary jump adds forwardSpeed*0.25 to 42 u/f", controller.vertical_speed, 47.0)

	Input.action_press("player_crouch")
	controller.forward_speed = 20.0
	controller._start_ground_jump(32.0, 0.0)
	Input.action_release("player_crouch")
	check("crouch plus moving jump selects long jump", controller.action == controller.Action.LONG_JUMP)
	check_approx("long jump multiplies forward speed by 1.5", controller.forward_speed, 30.0)
	check_approx("long jump vertical speed is 30 u/f", controller.vertical_speed, 30.0)

	controller.forward_speed = 40.0
	controller._start_dive()
	check_approx("dive adds 15 and caps at 48 u/f", controller.forward_speed, 48.0)
	controller._start_lava_boost()
	check_approx("burning floor clears forward speed", controller.forward_speed, 0.0)
	check_approx("burning floor launches at 84 u/f", controller.vertical_speed, 84.0)


func _surface_classes() -> void:
	check("ice maps to very-slippery class",
		controller._surface_class(&"ice") == controller.SurfaceClass.VERY_SLIPPERY)
	check_approx("very-slippery slope acceleration is 5.3",
		controller._slope_acceleration(controller.SurfaceClass.VERY_SLIPPERY), 5.3)
	check_approx("slippery slope acceleration is 2.7",
		controller._slope_acceleration(controller.SurfaceClass.SLIPPERY), 2.7)
	check_approx("not-slippery slope acceleration is zero",
		controller._slope_acceleration(controller.SurfaceClass.NOT_SLIPPERY), 0.0)
	check_approx("very-slippery deceleration multiplier is 0.2",
		controller._slope_deceleration(controller.SurfaceClass.VERY_SLIPPERY, 1.0), 0.2)
	check_approx("slippery deceleration multiplier is 0.7",
		controller._slope_deceleration(controller.SurfaceClass.SLIPPERY, 1.0), 0.7)
	check_approx("default deceleration multiplier is 2.0",
		controller._slope_deceleration(controller.SurfaceClass.DEFAULT, 1.0), 2.0)
	check_approx("not-slippery deceleration multiplier is 3.0",
		controller._slope_deceleration(controller.SurfaceClass.NOT_SLIPPERY, 1.0), 3.0)
	check_approx("very-slippery surfaces slide at ten degrees",
		controller._slippery_normal_y(controller.SurfaceClass.VERY_SLIPPERY), cos(deg_to_rad(10.0)))
	check_approx("default surfaces slide at 38 degrees",
		controller._slippery_normal_y(controller.SurfaceClass.DEFAULT), cos(deg_to_rad(38.0)))


func _state_transitions() -> void:
	Input.action_release("player_crouch")
	Input.action_release("player_jump")
	Input.action_release("player_special")
	controller.current_surface = &"default"
	controller.action = controller.Action.JUMP
	controller.peak_height = controller.global_position.y
	controller.vertical_speed = -10.0
	controller._land()
	check("jump landing returns to idle", controller.action == controller.Action.IDLE)
	check("jump landing arms chain step one", controller.jump_chain == 1)

	controller.forward_speed = 20.0
	controller._start_ground_jump(32.0, controller.face_yaw)
	check("chain step one selects double jump", controller.action == controller.Action.DOUBLE_JUMP)
	controller.peak_height = controller.global_position.y
	controller.vertical_speed = -10.0
	controller._land()
	check("double-jump landing arms chain step two", controller.jump_chain == 2)

	controller.forward_speed = 24.0
	controller._start_ground_jump(32.0, controller.face_yaw)
	check("fast chain step two selects triple jump", controller.action == controller.Action.TRIPLE_JUMP)
	controller.jump_chain = 2
	controller.forward_speed = 10.0
	controller._start_ground_jump(32.0, controller.face_yaw)
	check("slow chain step two falls back to ordinary jump", controller.action == controller.Action.JUMP)

	controller.jump_chain = 0
	controller.forward_speed = 5.0
	Input.action_press("player_crouch")
	controller._start_ground_jump(32.0, controller.face_yaw)
	Input.action_release("player_crouch")
	check("crouch jump below long-jump threshold selects backflip",
		controller.action == controller.Action.BACKFLIP)

	controller.jump_chain = 0
	controller.forward_speed = 12.0
	controller.face_yaw = 0.0
	controller.action = controller.Action.TURNING_AROUND
	controller._start_ground_jump(32.0, PI)
	check("turnaround jump selects side flip", controller.action == controller.Action.SIDE_FLIP)

	controller.last_wall_normal = Vector3.RIGHT
	controller.forward_speed = 3.0
	controller._start_wall_kick()
	check("wall kick enforces its forward-speed minimum", controller.forward_speed == 24.0)
	check_approx("wall kick faces away from the wall", controller.face_yaw, PI * 0.5)

	controller.action = controller.Action.SWIMMING
	controller.velocity.y = controller.source_speed_to_mps(-3.0)
	controller._update_airborne(0.5, 0.0, controller.face_yaw)
	check("leaving water transitions swimming to fall", controller.action == controller.Action.FALL)


func _swimming() -> void:
	Input.action_release("player_jump")
	var flowing_floor := Node.new()
	flowing_floor.set_meta("platformer_force_direction", Vector3.RIGHT)
	controller.floor_collider = flowing_floor
	controller.current_surface = &"flowing_water"
	controller.forward_speed = 20.0
	controller.face_yaw = 0.0
	controller.swim_pitch = 0.0
	controller._update_swimming(1.0, Vector2.ZERO, 0.0, 0.0)
	check("water enters the swimming action group", controller.action == controller.Action.SWIMMING)
	check_approx("idle swim drag and threshold decay reduce speed", controller.forward_speed, 18.5)
	check_approx("deep-water vertical speed eases to buoyancy", controller.vertical_speed, -2.0)
	check_approx("flowing-water floor adds its current", controller.slide_velocity.x, 1.0)
	flowing_floor.free()
	controller.floor_collider = null


func _reset_runtime_values() -> void:
	controller.max_run_speed = controller.DEFAULT_MAX_TARGET_SPEED
	controller.slow_surface_speed = controller.DEFAULT_SLOW_TARGET_SPEED
	controller.ground_acceleration = controller.DEFAULT_GROUND_ACCELERATION
	controller.ground_deceleration = controller.DEFAULT_GROUND_DECELERATION
	controller.turn_rate_degrees = controller.DEFAULT_TURN_RATE_DEGREES
	controller.air_acceleration = controller.DEFAULT_AIR_ACCELERATION
	controller.air_drag = controller.DEFAULT_AIR_DRAG
	controller.gravity = controller.DEFAULT_GRAVITY
	controller.jump_velocity = controller.DEFAULT_JUMP_VELOCITY
	controller.swim_speed = controller.DEFAULT_SWIM_SPEED
	controller.buoyancy = controller.DEFAULT_BUOYANCY


func check_vec2(label: String, got: Vector2, want: Vector2, tolerance := 1e-4) -> void:
	check("%s (got %s, want %s ±%f)" % [label, got, want, tolerance], (got - want).length() <= tolerance)

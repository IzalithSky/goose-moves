class_name Q3CharacterController
extends CharacterBody3D

const Q3_MOVEMENT_MOTOR := preload("res://scripts/q3_movement_motor.gd")
const Q3_MOVEMENT_HUD := preload("res://scripts/q3_movement_hud.gd")
const Q3_UNITS_PER_FOOT := Q3_MOVEMENT_MOTOR.Q3_UNITS_PER_FOOT
const METERS_PER_FOOT := Q3_MOVEMENT_MOTOR.METERS_PER_FOOT
const Q3_METERS_PER_UNIT := Q3_MOVEMENT_MOTOR.Q3_METERS_PER_UNIT
const Q3_SPEED := Q3_MOVEMENT_MOTOR.Q3_SPEED
const Q3_GROUND_ACCELERATION := Q3_MOVEMENT_MOTOR.Q3_GROUND_ACCELERATION
const Q3_AIR_ACCELERATION := Q3_MOVEMENT_MOTOR.Q3_AIR_ACCELERATION
const Q3_FRICTION := Q3_MOVEMENT_MOTOR.Q3_FRICTION
const Q3_GRAVITY := Q3_MOVEMENT_MOTOR.Q3_GRAVITY
const Q3_JUMP_VELOCITY := Q3_MOVEMENT_MOTOR.Q3_JUMP_VELOCITY
const Q3_STOP_SPEED := Q3_MOVEMENT_MOTOR.Q3_STOP_SPEED
const Q3_STEP_HEIGHT := Q3_MOVEMENT_MOTOR.Q3_STEP_HEIGHT
const Q3_GROUND_TRACE_DISTANCE := Q3_MOVEMENT_MOTOR.Q3_GROUND_TRACE_DISTANCE
const Q3_GROUND_KICKOFF_SPEED := Q3_MOVEMENT_MOTOR.Q3_GROUND_KICKOFF_SPEED
const Q3_MAX_SLOPE_ANGLE := Q3_MOVEMENT_MOTOR.Q3_MAX_SLOPE_ANGLE
const Q3_RUN_COMMAND := Q3_MOVEMENT_MOTOR.Q3_RUN_COMMAND
const Q3_WALK_COMMAND := Q3_MOVEMENT_MOTOR.Q3_WALK_COMMAND
const Q3_CROUCH_SPEED_SCALE := Q3_MOVEMENT_MOTOR.Q3_CROUCH_SPEED_SCALE
const Q3_MINS_Z := Q3_MOVEMENT_MOTOR.Q3_MINS_Z
const Q3_STANDING_MAX_Z := Q3_MOVEMENT_MOTOR.Q3_STANDING_MAX_Z
const Q3_CROUCH_MAX_Z := Q3_MOVEMENT_MOTOR.Q3_CROUCH_MAX_Z
const Q3_STANDING_VIEWHEIGHT := Q3_MOVEMENT_MOTOR.Q3_STANDING_VIEWHEIGHT
const Q3_CROUCH_VIEWHEIGHT := Q3_MOVEMENT_MOTOR.Q3_CROUCH_VIEWHEIGHT
const Q3_STANDING_HULL_HEIGHT := Q3_MOVEMENT_MOTOR.Q3_STANDING_HULL_HEIGHT
const Q3_CROUCH_HULL_HEIGHT := Q3_MOVEMENT_MOTOR.Q3_CROUCH_HULL_HEIGHT
const Q3_STANDING_EYE_HEIGHT := Q3_MOVEMENT_MOTOR.Q3_STANDING_EYE_HEIGHT
const Q3_CROUCH_EYE_HEIGHT := Q3_MOVEMENT_MOTOR.Q3_CROUCH_EYE_HEIGHT
const Q3_SWIM_SCALE := Q3_MOVEMENT_MOTOR.Q3_SWIM_SCALE
const Q3_WATER_ACCELERATION := Q3_MOVEMENT_MOTOR.Q3_WATER_ACCELERATION
const Q3_WATER_FRICTION := Q3_MOVEMENT_MOTOR.Q3_WATER_FRICTION
const Q3_SLIME_FRICTION := Q3_MOVEMENT_MOTOR.Q3_SLIME_FRICTION
const Q3_WATER_SINK_SPEED := Q3_MOVEMENT_MOTOR.Q3_WATER_SINK_SPEED
const Q3_VOLUME_COLLISION_MASK := Q3_MOVEMENT_MOTOR.Q3_VOLUME_COLLISION_MASK
const Q3_WATER_JUMP_FORWARD_DISTANCE := Q3_MOVEMENT_MOTOR.Q3_WATER_JUMP_FORWARD_DISTANCE
const Q3_WATER_JUMP_LOW_PROBE_HEIGHT := Q3_MOVEMENT_MOTOR.Q3_WATER_JUMP_LOW_PROBE_HEIGHT
const Q3_WATER_JUMP_CLEARANCE := Q3_MOVEMENT_MOTOR.Q3_WATER_JUMP_CLEARANCE
const Q3_WATER_JUMP_FORWARD_VELOCITY := Q3_MOVEMENT_MOTOR.Q3_WATER_JUMP_FORWARD_VELOCITY
const Q3_WATER_JUMP_VELOCITY := Q3_MOVEMENT_MOTOR.Q3_WATER_JUMP_VELOCITY
const Q3_WATER_JUMP_DURATION := Q3_MOVEMENT_MOTOR.Q3_WATER_JUMP_DURATION
const WARSOW_GROUND_ACCELERATION := Q3_MOVEMENT_MOTOR.WARSOW_GROUND_ACCELERATION
const WARSOW_AIR_ACCELERATION := Q3_MOVEMENT_MOTOR.WARSOW_AIR_ACCELERATION
const WARSOW_AIR_DECELERATION := Q3_MOVEMENT_MOTOR.WARSOW_AIR_DECELERATION
const WARSOW_FRICTION := Q3_MOVEMENT_MOTOR.WARSOW_FRICTION
const WARSOW_STOP_SPEED := Q3_MOVEMENT_MOTOR.WARSOW_STOP_SPEED
const WARSOW_STRAFE_ACCELERATION := Q3_MOVEMENT_MOTOR.WARSOW_STRAFE_ACCELERATION
const WARSOW_STRAFE_WISH_SPEED := Q3_MOVEMENT_MOTOR.WARSOW_STRAFE_WISH_SPEED
const WARSOW_AIR_CONTROL := Q3_MOVEMENT_MOTOR.WARSOW_AIR_CONTROL
const WARSOW_CROUCH_SLIDE_DURATION := Q3_MOVEMENT_MOTOR.WARSOW_CROUCH_SLIDE_DURATION
const WARSOW_CROUCH_SLIDE_FADE := Q3_MOVEMENT_MOTOR.WARSOW_CROUCH_SLIDE_FADE
const WARSOW_CROUCH_SLIDE_COOLDOWN := Q3_MOVEMENT_MOTOR.WARSOW_CROUCH_SLIDE_COOLDOWN
const WARSOW_CROUCH_SLIDE_CONTROL := Q3_MOVEMENT_MOTOR.WARSOW_CROUCH_SLIDE_CONTROL
const WARSOW_WALK_SPEED := Q3_MOVEMENT_MOTOR.WARSOW_WALK_SPEED
const WARSOW_GROUND_DETACH_SPEED := Q3_MOVEMENT_MOTOR.WARSOW_GROUND_DETACH_SPEED
const WARSOW_SLIDE_OVERBOUNCE := Q3_MOVEMENT_MOTOR.WARSOW_SLIDE_OVERBOUNCE
const WARSOW_PLANE_INTERACTION_EPSILON := Q3_MOVEMENT_MOTOR.WARSOW_PLANE_INTERACTION_EPSILON
const WARSOW_WALL_JUMP_COOLDOWN := Q3_MOVEMENT_MOTOR.WARSOW_WALL_JUMP_COOLDOWN
const WARSOW_WALL_JUMP_UP_SPEED := Q3_MOVEMENT_MOTOR.WARSOW_WALL_JUMP_UP_SPEED
const WARSOW_WALL_JUMP_BOUNCE := Q3_MOVEMENT_MOTOR.WARSOW_WALL_JUMP_BOUNCE
const WARSOW_WALL_JUMP_OVERBOUNCE := Q3_MOVEMENT_MOTOR.WARSOW_WALL_JUMP_OVERBOUNCE
const WARSOW_WALL_JUMP_MAX_NORMAL_Y := Q3_MOVEMENT_MOTOR.WARSOW_WALL_JUMP_MAX_NORMAL_Y
const WARSOW_WALL_JUMP_PROBE_DIRECTIONS := Q3_MOVEMENT_MOTOR.WARSOW_WALL_JUMP_PROBE_DIRECTIONS
const WARSOW_DASH_SPEED := Q3_MOVEMENT_MOTOR.WARSOW_DASH_SPEED
const WARSOW_DASH_UP_SPEED_THRESHOLD := Q3_MOVEMENT_MOTOR.WARSOW_DASH_UP_SPEED_THRESHOLD

enum MovementMode {
	VQ3,
	WARSOW_CLASSIC,
}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var third_person_spring_arm: SpringArm3D = $Head/ThirdPersonSpringArm
@onready var third_person_camera: Camera3D = $Head/ThirdPersonSpringArm/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var character_collider_visual: MeshInstance3D = $CharacterColliderVisual
@onready var hud: Q3_MOVEMENT_HUD = $HUD

var motor := Q3_MOVEMENT_MOTOR.new()

var movement_mode:
	get:
		return motor.movement_mode
	set(value):
		motor.movement_mode = value

var auto_jump:
	get:
		return motor.auto_jump
	set(value):
		motor.auto_jump = value

var crouch_slide_enabled:
	get:
		return motor.crouch_slide_enabled
	set(value):
		motor.crouch_slide_enabled = value

var ramp_launch_enabled:
	get:
		return motor.ramp_launch_enabled
	set(value):
		motor.ramp_launch_enabled = value

var wall_jump_enabled:
	get:
		return motor.wall_jump_enabled
	set(value):
		motor.wall_jump_enabled = value

var third_person_enabled:
	get:
		return motor.third_person_enabled
	set(value):
		motor.third_person_enabled = value

var character_size:
	get:
		return motor.character_size
	set(value):
		motor.character_size = value

var move_speed:
	get:
		return motor.move_speed
	set(value):
		motor.move_speed = value

var ground_acceleration:
	get:
		return motor.ground_acceleration
	set(value):
		motor.ground_acceleration = value

var air_acceleration:
	get:
		return motor.air_acceleration
	set(value):
		motor.air_acceleration = value

var friction:
	get:
		return motor.friction
	set(value):
		motor.friction = value

var stop_speed:
	get:
		return motor.stop_speed
	set(value):
		motor.stop_speed = value

var gravity:
	get:
		return motor.gravity
	set(value):
		motor.gravity = value

var jump_velocity:
	get:
		return motor.jump_velocity
	set(value):
		motor.jump_velocity = value

var step_height:
	get:
		return motor.step_height
	set(value):
		motor.step_height = value

var max_slope_angle:
	get:
		return motor.max_slope_angle
	set(value):
		motor.max_slope_angle = value

var crouch_speed_scale:
	get:
		return motor.crouch_speed_scale
	set(value):
		motor.crouch_speed_scale = value

var walk_speed_scale:
	get:
		return motor.walk_speed_scale
	set(value):
		motor.walk_speed_scale = value

var swim_speed_scale:
	get:
		return motor.swim_speed_scale
	set(value):
		motor.swim_speed_scale = value

var water_acceleration:
	get:
		return motor.water_acceleration
	set(value):
		motor.water_acceleration = value

var water_friction:
	get:
		return motor.water_friction
	set(value):
		motor.water_friction = value

var slime_friction:
	get:
		return motor.slime_friction
	set(value):
		motor.slime_friction = value

var mouse_sensitivity:
	get:
		return motor.mouse_sensitivity
	set(value):
		motor.mouse_sensitivity = value

var pitch:
	get:
		return motor.pitch
	set(value):
		motor.pitch = value

var yaw:
	get:
		return motor.yaw
	set(value):
		motor.yaw = value

var floor_is_slick:
	get:
		return motor.floor_is_slick
	set(value):
		motor.floor_is_slick = value

var is_crouching:
	get:
		return motor.is_crouching
	set(value):
		motor.is_crouching = value

var is_crouch_sliding:
	get:
		return motor.is_crouch_sliding
	set(value):
		motor.is_crouch_sliding = value

var crouch_slide_time_remaining:
	get:
		return motor.crouch_slide_time_remaining
	set(value):
		motor.crouch_slide_time_remaining = value

var wall_jump_cooldown_remaining:
	get:
		return motor.wall_jump_cooldown_remaining
	set(value):
		motor.wall_jump_cooldown_remaining = value

var body_shape:
	get:
		return motor.body_shape
	set(value):
		motor.body_shape = value

var body_mesh:
	get:
		return motor.body_mesh
	set(value):
		motor.body_mesh = value

var water_level:
	get:
		return motor.water_level
	set(value):
		motor.water_level = value

var water_type:
	get:
		return motor.water_type
	set(value):
		motor.water_type = value

var water_jump_time_remaining:
	get:
		return motor.water_jump_time_remaining
	set(value):
		motor.water_jump_time_remaining = value


func _ready() -> void:
	motor.setup(self, {
		"head": head,
		"camera": camera,
		"third_person_spring_arm": third_person_spring_arm,
		"third_person_camera": third_person_camera,
		"collision_shape": collision_shape,
		"character_collider_visual": character_collider_visual,
		"hud": hud,
	}, Settings.CHARACTER_Q3)
	Settings.settings_changed.connect(on_settings_changed)


func _process(delta: float) -> void:
	motor.process_tick(delta)


func _physics_process(delta: float) -> void:
	motor.physics_tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	motor.handle_unhandled_input(event)


func on_settings_changed() -> void:
	motor.on_settings_changed()


func _get_movement_input() -> Vector2:
	return motor._get_movement_input()

func _get_wish_direction(movement_input: Vector2, ground_normal: Vector3) -> Vector3:
	return motor._get_wish_direction(movement_input, ground_normal)

func _get_wish_speed(movement_input: Vector2) -> float:
	return motor._get_wish_speed(movement_input)

func _get_movement_scale() -> float:
	return motor._get_movement_scale()

func _get_vertical_input() -> float:
	return motor._get_vertical_input()

func _jump_requested() -> bool:
	return motor._jump_requested()

func _apply_jump_velocity(ground_normal: Vector3) -> void:
	motor._apply_jump_velocity(ground_normal)

func _try_wall_jump(grounded: bool) -> bool:
	return motor._try_wall_jump(grounded)

func _wall_jump_height_allowed() -> bool:
	return motor._wall_jump_height_allowed()

func _get_wall_jump_normal() -> Vector3:
	return motor._get_wall_jump_normal()

func _wall_jump_collision_allowed(collision: KinematicCollision3D) -> bool:
	return motor._wall_jump_collision_allowed(collision)

func _update_crouch_slide(delta: float, grounded: bool) -> void:
	motor._update_crouch_slide(delta, grounded)

func _update_crouch_state() -> void:
	motor._update_crouch_state()

func _set_crouching(value: bool) -> void:
	motor._set_crouching(value)

func _set_stance_geometry(crouching: bool) -> void:
	motor._set_stance_geometry(crouching)

func _can_stand() -> bool:
	return motor._can_stand()

func _update_water_level() -> void:
	motor._update_water_level()

func _get_water_area_at(point: Vector3) -> Area3D:
	return motor._get_water_area_at(point)

func _water_move(movement_input: Vector2, delta: float) -> void:
	motor._water_move(movement_input, delta)

func _try_water_jump() -> bool:
	return motor._try_water_jump()

func _water_jump_move(delta: float) -> void:
	motor._water_jump_move(delta)

func _has_solid_at(point: Vector3) -> bool:
	return motor._has_solid_at(point)

func _get_swim_wish_velocity(movement_input: Vector2) -> Vector3:
	return motor._get_swim_wish_velocity(movement_input)

func _get_current_friction_coefficient() -> float:
	return motor._get_current_friction_coefficient()

func _get_current_acceleration() -> float:
	return motor._get_current_acceleration()

func _get_ground_acceleration() -> float:
	return motor._get_ground_acceleration()

func _get_ground_friction() -> float:
	return motor._get_ground_friction()

func _get_ground_stop_speed() -> float:
	return motor._get_ground_stop_speed()

func _get_air_acceleration(wish_direction: Vector3, movement_input: Vector2) -> float:
	return motor._get_air_acceleration(wish_direction, movement_input)

func _get_volume_friction() -> float:
	return motor._get_volume_friction()

func _apply_friction(delta: float, apply_ground_friction: bool) -> void:
	motor._apply_friction(delta, apply_ground_friction)

func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	motor._accelerate(wish_direction, wish_speed, acceleration, delta)

func _crouch_slide_accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	motor._crouch_slide_accelerate(wish_direction, wish_speed, acceleration, delta)

func _air_move(wish_direction: Vector3, wish_speed: float, movement_input: Vector2, delta: float) -> void:
	motor._air_move(wish_direction, wish_speed, movement_input, delta)

func _apply_air_control(wish_direction: Vector3, movement_input: Vector2, delta: float) -> void:
	motor._apply_air_control(wish_direction, movement_input, delta)

func _project_velocity_onto_plane(plane_normal: Vector3, speed: float = -1.0) -> void:
	motor._project_velocity_onto_plane(plane_normal, speed)

func _restore_velocity_on_floor_plane(plane_normal: Vector3) -> void:
	motor._restore_velocity_on_floor_plane(plane_normal)

func _get_ramp_collision_velocity_y(input_velocity: Vector3, default_velocity_y: float) -> float:
	return motor._get_ramp_collision_velocity_y(input_velocity, default_velocity_y)

func _clip_velocity(input_velocity: Vector3, plane_normal: Vector3, overbounce: float) -> Vector3:
	return motor._clip_velocity(input_velocity, plane_normal, overbounce)

func _get_ground_collision() -> KinematicCollision3D:
	return motor._get_ground_collision()

func _try_step_up(delta: float) -> bool:
	return motor._try_step_up(delta)

func _update_floor_surface() -> void:
	motor._update_floor_surface()

func _surface_is_slick(collider: Node) -> bool:
	return motor._surface_is_slick(collider)

func _apply_controller_settings() -> void:
	motor._apply_controller_settings()

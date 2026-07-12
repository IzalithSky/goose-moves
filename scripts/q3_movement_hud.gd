class_name Q3MovementHUD
extends CanvasLayer

@onready var speed_q3_number_label: Label = $BottomBar/SpeedQ3NumberLabel
@onready var speed_mps_number_label: Label = $BottomBar/SpeedMpsNumberLabel
@onready var fps_label: Label = $BottomBar/MetricsStack/FpsLabel
@onready var friction_label: Label = $BottomBar/MetricsStack/FrictionLabel
@onready var acceleration_label: Label = $BottomBar/MetricsStack/AccelerationLabel
@onready var ground_sign_label: Label = $BottomBar/FlagGrid/GroundSignLabel
@onready var slick_sign_label: Label = $BottomBar/FlagGrid/SlickSignLabel
@onready var crouch_sign_label: Label = $BottomBar/FlagGrid/CrouchSignLabel
@onready var water_sign_label: Label = $BottomBar/FlagGrid/WaterSignLabel
@onready var water_name_label: Label = $BottomBar/FlagGrid/WaterNameLabel
@onready var water_jump_sign_label: Label = $BottomBar/FlagGrid/WaterJumpSignLabel


func update_values(
	q3_speed: float,
	meters_per_second: float,
	fps: int,
	grounded: bool,
	slick: bool,
	crouching: bool,
	water_level: int,
	water_jumping: bool,
	friction: float,
	acceleration: float,
) -> void:
	speed_q3_number_label.text = "%.1f" % q3_speed
	speed_mps_number_label.text = "%.1f" % meters_per_second
	fps_label.text = "FPS  %d" % fps
	friction_label.text = "FRICTION  %.1f" % friction
	acceleration_label.text = "ACCEL  %.1f" % acceleration
	ground_sign_label.text = "+" if grounded else "-"
	slick_sign_label.text = "+" if slick else "-"
	crouch_sign_label.text = "+" if crouching else "-"
	water_sign_label.text = "+" if water_level > 0 else "-"
	water_name_label.text = "WATER:%d" % water_level if water_level > 0 else "WATER"
	water_jump_sign_label.text = "+" if water_jumping else "-"

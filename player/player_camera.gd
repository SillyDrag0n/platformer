extends Camera2D

@export_category("Follow Character")
@export var player : CharacterBody2D

@export_category("Camera Smoothing")
@export var smoothing_enabled : bool
@export_range(1, 10) var smoothing_distance : int = 8

@export_category("Camera Shake")
@export var shake_intensity: float = 0.0
@export var active_shake_time: float = 0.0
@export var shake_decay: float = 5.0
@export var shake_time: float = 0.0
@export var shake_time_speed: float = 20.0
@export var noise = FastNoiseLite.new()

var weight : float

func _ready():
	weight = float(11 - smoothing_distance) / 100 
	HealthManager.on_health_decreased.connect(screen_shake)


func _physics_process(delta):
	if active_shake_time > 0:
		shake_time += delta * shake_time_speed
		active_shake_time -= delta

		offset = Vector2(
			noise.get_noise_2d(shake_time, 0) * shake_intensity,
			noise.get_noise_2d(0, shake_time) * shake_intensity
		)

		shake_intensity = max(shake_intensity - shake_decay * delta, 0)
	else:
		offset = lerp(offset, Vector2.ZERO, 10.5 * delta)
		
	if player != null:
		var camera_position : Vector2
		
		if smoothing_enabled:
			camera_position = lerp(global_position, player.global_position, weight)
		else:
			camera_position = player.global_position
		
		global_position = camera_position.floor()

# func screen_shake(intensity: int, time:float):
func screen_shake():
	randomize()
	noise.seed = randi()
	noise.frequency = 2.0

	shake_intensity = 8
	active_shake_time = 0.5
	shake_time = 0.0

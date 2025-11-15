extends Node2D

var bullet = preload("res://player/bullet.tscn")

@export var bullet_speed := 500
@export var bullet_damage := 1
@export var cooldown := 0.75

@onready var muzzle = $Muzzle
@onready var cooldown_timer = $CooldownTimer
@onready var gun_cooldown = $GunCooldown

func _ready():
	cooldown_timer.wait_time = cooldown

func _process(delta):
	gun_cooldown.setValue(cooldown_timer.time_left / cooldown_timer.wait_time)

# --- Upgrade setters ---
func set_cooldown(new_cooldown: float):
	cooldown = new_cooldown
	cooldown_timer.wait_time = cooldown

func set_damage(new_damage: int):
	bullet_damage = new_damage

func set_speed(new_speed: int):
	bullet_speed = new_speed


# --- Fire attempt ---
func try_shoot() -> bool:
	if cooldown_timer.is_stopped():
		print("enter shoot")
		shoot()
		cooldown_timer.start()
		return true
	
	print("weapon on cooldown")
	return false

func shoot():
	var bullet_instance = bullet.instantiate() as Node2D
	get_tree().current_scene.add_child(bullet_instance)
	var camera = get_viewport().get_camera_2d()
	var mouse_global = camera.get_global_mouse_position()
	var shootdirection : Vector2 = (mouse_global - muzzle.global_position).normalized()

	bullet_instance.direction = shootdirection
	bullet_instance.rotation = bullet_instance.direction.angle()
	bullet_instance.global_position = muzzle.global_position

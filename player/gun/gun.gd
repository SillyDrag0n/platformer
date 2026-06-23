extends Node2D

var bullet = preload("res://player/gun/bullet/bullet.tscn")

@export var bullet_speed := 500
@export var bullet_damage := 1
#TODO: check if cooldown can be replaced by shoot_timer, why is it necessary?
@export var cooldown := 0.75
@export var magazine_max := 6
@export var magazine_current := 6
@onready var muzzle = $Muzzle
@onready var shoot_timer = $ShootTimer
@onready var reload_timer = $ReloadTimer
@onready var reload_ui = $ReloadUi
@onready var gun_shot_sound = $GunShot01
@onready var gun_reload_sound = $GunReload
@onready var gun_empty_sound = $GunEmpty


func _ready():
	shoot_timer.wait_time = cooldown

func _process(_delta):
	if GameInputEvents.reload_input():
		reload()
	if !reload_timer.is_stopped():
		reload_ui.set_value(reload_timer.time_left / reload_timer.wait_time)

# --- Upgrade setters ---
func set_cooldown(new_cooldown: float):
	cooldown = new_cooldown
	shoot_timer.wait_time = cooldown

func set_damage(new_damage: int):
	bullet_damage = new_damage

func set_speed(new_speed: int):
	bullet_speed = new_speed


# --- Fire attempt ---
func try_shoot() -> bool:
	if shoot_timer.is_stopped() and reload_timer.is_stopped():
		if magazine_current > 0:
			magazine_current -= 1
			shoot()
			shoot_timer.start()
			return true
		gun_empty_sound.play()
		return false
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
	bullet_instance.speed = bullet_speed
	bullet_instance.damage_amount = bullet_damage
	gun_shot_sound.play()

func reload():
	reload_timer.start()
	reload_ui.show()
	if !gun_reload_sound.playing:
		gun_reload_sound.play()

func _on_reload_timer_timeout() -> void:
	magazine_current = magazine_max
	reload_ui.hide()

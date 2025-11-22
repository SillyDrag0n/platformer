extends Node2D

var bullet = preload("res://player/gun/bullet/bullet.tscn")

@export var bullet_speed := 500
@export var bullet_damage := 1
#TODO: check if cooldown can be replaced by shoot_timer, why is it necessary?
@export var cooldown := 0.75
@export var magazineMax := 6
@export var magazineCurrent := 6
@onready var muzzle = $Muzzle
@onready var shoot_timer = $ShootTimer
@onready var reload_timer = $ReloadTimer
@onready var reload_ui = $ReloadUi
@onready var gunShot01 = $GunShot01
@onready var gunReload = $GunReload
@onready var gunEmpty = $GunEmpty


func _ready():
	shoot_timer.wait_time = cooldown

func _process(delta):	
	if GameInputEvents.reload_input():
		reload()
	if !reload_timer.is_stopped():
		reload_ui.setValue(reload_timer.time_left / reload_timer.wait_time)

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
		if magazineCurrent > 0:
			magazineCurrent -= 1
			print("enter shoot, magazine size: ", magazineCurrent)
			shoot()
			shoot_timer.start()
			return true
		print("no ammo")
		gunEmpty.play()
		return false
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
	gunShot01.play()

func reload():
	reload_timer.start()
	$ReloadUi.show()
	if !gunReload.playing:
		gunReload.play()
	print("is reloading")

func _on_reload_timer_timeout() -> void:
	print("reload finished")
	magazineCurrent = magazineMax
	$ReloadUi.hide()
	#gun_cooldown.setValue(shoot_timer.time_left / shoot_timer.wait_time)

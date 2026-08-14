extends Node2D

var bullet = preload("res://player/gun/bullet/bullet.tscn")
var muzzle_flash_effect = preload("res://player/gun/muzzle_flash_effect.tscn")

@export var default_weapon : WeaponItemData
@export var default_ammo : AmmoItemData

var weapon : WeaponItemData
var ammo : AmmoItemData
var magazine_current : int

@onready var muzzle = $Muzzle
@onready var shoot_timer = $ShootTimer
@onready var reload_timer = $ReloadTimer
@onready var reload_ui = $ReloadUi
@onready var gun_shot_sound = $GunShot01
@onready var gun_reload_sound = $GunReload
@onready var gun_empty_sound = $GunEmpty


func _ready():
	InventoryManager.equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	InventoryManager.equipped_ammo_changed.connect(_on_equipped_ammo_changed)
	equip_weapon(InventoryManager.equipped_weapon if InventoryManager.equipped_weapon else default_weapon)
	equip_ammo(InventoryManager.equipped_ammo if InventoryManager.equipped_ammo else default_ammo)

func _process(_delta):
	if GameInputEvents.reload_input():
		reload()
	if !reload_timer.is_stopped():
		reload_ui.set_value(reload_timer.time_left / reload_timer.wait_time)

# --- Equipping ---
func equip_weapon(new_weapon : WeaponItemData):
	if new_weapon == null:
		return
	weapon = new_weapon
	shoot_timer.wait_time = weapon.cooldown
	magazine_current = weapon.magazine_size

func equip_ammo(new_ammo : AmmoItemData):
	ammo = new_ammo

func _on_equipped_weapon_changed(new_weapon : WeaponItemData):
	equip_weapon(new_weapon if new_weapon else default_weapon)

func _on_equipped_ammo_changed(new_ammo : AmmoItemData):
	equip_ammo(new_ammo if new_ammo else default_ammo)


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
	var shootdirection : Vector2 = GameInputEvents.aim_input(muzzle.global_position)

	bullet_instance.direction = shootdirection
	bullet_instance.rotation = bullet_instance.direction.angle()
	bullet_instance.global_position = muzzle.global_position
	bullet_instance.speed = int(round(weapon.bullet_speed * (ammo.speed_modifier if ammo else 1.0)))
	bullet_instance.damage_amount = int(round(weapon.bullet_damage * (ammo.damage_modifier if ammo else 1.0)))
	gun_shot_sound.play()

	var flash_instance = muzzle_flash_effect.instantiate() as Node2D
	flash_instance.global_position = muzzle.global_position
	flash_instance.rotation = shootdirection.angle()
	get_tree().current_scene.add_child(flash_instance)

func reload():
	reload_timer.start()
	reload_ui.show()
	if !gun_reload_sound.playing:
		gun_reload_sound.play()

func _on_reload_timer_timeout() -> void:
	magazine_current = weapon.magazine_size
	reload_ui.hide()

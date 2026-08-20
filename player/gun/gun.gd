extends Node2D

var bullet = preload("res://player/gun/bullet/bullet.tscn")
var muzzle_flash_effect = preload("res://player/gun/muzzle_flash_effect.tscn")

@export var default_weapon : WeaponItemData
@export var default_ammo : AmmoItemData

var active_slot : InventoryManager.WeaponSlot = InventoryManager.WeaponSlot.PRIMARY
var weapon : WeaponItemData
var ammo : AmmoItemData
var magazine_current : int

@onready var muzzle = $Muzzle
@onready var weapon_sprite : Sprite2D = $Weapon
@onready var shoot_timer = $ShootTimer
@onready var reload_timer = $ReloadTimer
@onready var reload_ui = $ReloadUi
@onready var gun_shot_sound = $GunShot01
@onready var gun_reload_sound = $GunReload
@onready var gun_empty_sound = $GunEmpty

@onready var player = get_parent()


func _ready():
	InventoryManager.equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	InventoryManager.equipped_ammo_changed.connect(_on_equipped_ammo_changed)
	InventoryManager.equipped_weapon_skin_changed.connect(_on_equipped_weapon_skin_changed)
	# Primary starts unequipped in InventoryManager itself - grant and equip the default weapon
	# there (rather than only falling back to it locally below) so InventoryManager stays the
	# accurate source of truth for what's equipped, matching what Gun.gd actually fires.
	if default_weapon != null and InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.PRIMARY) == null:
		InventoryManager.add_item(default_weapon)
		InventoryManager.equip_weapon(InventoryManager.WeaponSlot.PRIMARY, default_weapon)
	if default_ammo != null and InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.PRIMARY) == null:
		InventoryManager.add_item(default_ammo)
		InventoryManager.equip_ammo(InventoryManager.WeaponSlot.PRIMARY, default_ammo)
	_refresh_active_weapon()

func _process(_delta):
	if GameInputEvents.reload_input():
		reload()
	if GameInputEvents.swap_weapon_input():
		swap_weapon()
	if !reload_timer.is_stopped():
		reload_ui.set_value(reload_timer.time_left / reload_timer.wait_time)
	if player.is_shooting:
		try_shoot()

	# Points the gun (and, since Muzzle is a child of this node, the muzzle/bullet spawn point
	# along with it) at the aim direction every frame, regardless of gameplay state - matching how
	# AimReticle already tracks aim unconditionally today.
	var aim_dir : Vector2 = GameInputEvents.aim_input(global_position)
	rotation = aim_dir.angle()
	weapon_sprite.flip_v = aim_dir.x < 0.0

# --- Equipping ---
func swap_weapon():
	active_slot = InventoryManager.WeaponSlot.SECONDARY if active_slot == InventoryManager.WeaponSlot.PRIMARY else InventoryManager.WeaponSlot.PRIMARY
	_refresh_active_weapon()

# Resolves whichever weapon should currently be applied for active_slot, falling back to
# Primary (and from there to default_weapon) so the gun is never left without one - e.g. after
# swapping to or unequipping an empty Secondary. Ammo is refreshed alongside it since ammo is
# tracked per weapon slot and active_slot may change here (the Secondary fallback above).
func _refresh_active_weapon():
	var new_weapon = InventoryManager.get_equipped_weapon(active_slot)
	if new_weapon == null:
		active_slot = InventoryManager.WeaponSlot.PRIMARY
		new_weapon = InventoryManager.get_equipped_weapon(active_slot)
		if new_weapon == null:
			new_weapon = default_weapon
	equip_weapon(new_weapon)
	_refresh_active_ammo()
	_refresh_weapon_skin()

func equip_weapon(new_weapon : WeaponItemData):
	if new_weapon == null:
		return
	weapon = new_weapon
	shoot_timer.wait_time = weapon.cooldown
	magazine_current = weapon.magazine_size

func _refresh_active_ammo():
	var new_ammo = InventoryManager.get_equipped_ammo(active_slot)
	ammo = new_ammo if new_ammo else default_ammo

# Weapon skins are equipped per-WeaponSlot rather than as a single global cosmetic slot, so this
# is resolved here (where active_slot already lives) instead of the generic cosmetics listener.
func _refresh_weapon_skin():
	var skin : CosmeticItemData = InventoryManager.get_equipped_weapon_skin(active_slot)
	weapon_sprite.texture = skin.texture if skin else null

func _on_equipped_weapon_changed(slot : InventoryManager.WeaponSlot, _new_weapon : WeaponItemData):
	if slot == active_slot:
		_refresh_active_weapon()

func _on_equipped_ammo_changed(slot : InventoryManager.WeaponSlot, _new_ammo : AmmoItemData):
	if slot == active_slot:
		_refresh_active_ammo()

func _on_equipped_weapon_skin_changed(slot : InventoryManager.WeaponSlot, _cosmetic : CosmeticItemData):
	if slot == active_slot:
		_refresh_weapon_skin()


# --- Fire attempt ---
func try_shoot() -> bool:
	if shoot_timer.is_stopped() and reload_timer.is_stopped():
		if magazine_current > 0:
			magazine_current -= 1
			shoot()
			shoot_timer.start()
			if magazine_current == 0:
				reload()
			return true
		gun_empty_sound.play()
		return false
	return false

func shoot():
	var shootdirection : Vector2 = GameInputEvents.aim_input(muzzle.global_position)
	var pellet_count : int = max(weapon.pellet_count, 1)
	var spread_rad : float = deg_to_rad(weapon.spread_angle_degrees)

	for i in range(pellet_count):
		var angle_offset : float = 0.0
		if pellet_count > 1:
			angle_offset = lerp(-spread_rad / 2.0, spread_rad / 2.0, float(i) / float(pellet_count - 1))
		_fire_bullet(shootdirection.rotated(angle_offset))

	gun_shot_sound.play()

	var flash_instance = muzzle_flash_effect.instantiate() as Node2D
	flash_instance.global_position = muzzle.global_position
	flash_instance.rotation = shootdirection.angle()
	get_tree().current_scene.add_child(flash_instance)

func _fire_bullet(direction : Vector2):
	var bullet_instance = bullet.instantiate() as Node2D
	get_tree().current_scene.add_child(bullet_instance)

	bullet_instance.direction = direction
	bullet_instance.rotation = direction.angle()
	bullet_instance.global_position = muzzle.global_position
	bullet_instance.speed = int(round(weapon.bullet_speed * (ammo.speed_modifier if ammo else 1.0)))
	bullet_instance.damage_amount = int(round(weapon.bullet_damage * (ammo.damage_modifier if ammo else 1.0)))

func reload():
	reload_timer.start()
	reload_ui.show()
	if !gun_reload_sound.playing:
		gun_reload_sound.play()

func _on_reload_timer_timeout() -> void:
	magazine_current = weapon.magazine_size
	reload_ui.hide()

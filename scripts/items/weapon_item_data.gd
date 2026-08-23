class_name WeaponItemData
extends ItemData

@export_category("Appearance")
# Shown in the player's hand while this weapon is equipped, overridden by an equipped weapon skin
# if one is active (see Gun._refresh_weapon_skin). Lets each weapon (revolver, shotgun, ...) carry
# its own default in-hand sprite without needing a cosmetic skin just to be visible at all.
@export var world_texture : Texture2D

@export_category("Weapon Stats")
@export var bullet_speed : float = 500.0
@export var bullet_damage : int = 1
@export var cooldown : float = 0.75
@export var magazine_size : int = 6
@export var pellet_count : int = 1
@export var spread_angle_degrees : float = 0.0

@export_category("Ammo")
@export var compatible_ammo : Array[AmmoItemData] = []


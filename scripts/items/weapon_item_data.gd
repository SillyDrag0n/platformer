class_name WeaponItemData
extends ItemData

@export_category("Weapon Stats")
@export var bullet_speed : float = 500.0
@export var bullet_damage : int = 1
@export var cooldown : float = 0.75
@export var magazine_size : int = 6
@export var pellet_count : int = 1
@export var spread_angle_degrees : float = 0.0

@export_category("Ammo")
@export var compatible_ammo : Array[AmmoItemData] = []


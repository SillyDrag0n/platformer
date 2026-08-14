extends Node

signal updated_inventory
signal equipped_weapon_changed(weapon : WeaponItemData)
signal equipped_ammo_changed(ammo : AmmoItemData)

var size: int = 20
var start_items: Dictionary[ItemData, int]
var is_open: bool = false

# PURE DATA (no nodes)
var item_slots: Array = []
var equipped_weapon : WeaponItemData = null
var equipped_ammo : AmmoItemData = null

func _ready():
	initialize_inventory()

func initialize_inventory():
	item_slots.clear()

	# create empty slots
	for i in range(size):
		item_slots.append({
			"item": null,
			"quantity": 0
		})

	# add start items
	for item in start_items:
		for i in range(start_items[item]):
			add_item(item)

	updated_inventory.emit()


func add_item(item: ItemData) -> bool:
	var slot_index = get_item_slot_index(item)

	# stack if possible
	if slot_index != -1:
		var slot = item_slots[slot_index]
		if slot["quantity"] < item.max_stack_size:
			slot["quantity"] += 1
			updated_inventory.emit()
			return true

	# otherwise find empty slot
	slot_index = get_empty_slot_index()
	if slot_index == -1:
		return false

	item_slots[slot_index]["item"] = item
	item_slots[slot_index]["quantity"] = 1

	updated_inventory.emit()
	return true


func remove_item(item: ItemData):
	var slot_index = get_item_slot_index(item)
	if slot_index == -1:
		return

	var slot = item_slots[slot_index]

	if slot["quantity"] <= 1:
		slot["item"] = null
		slot["quantity"] = 0
	else:
		slot["quantity"] -= 1

	updated_inventory.emit()


func equip_weapon(weapon: WeaponItemData) -> bool:
	if weapon != null and get_item_slot_index(weapon) == -1:
		return false

	equipped_weapon = weapon
	equipped_weapon_changed.emit(equipped_weapon)
	return true


func equip_ammo(ammo: AmmoItemData) -> bool:
	if ammo != null:
		if get_item_slot_index(ammo) == -1:
			return false
		if equipped_weapon != null and not equipped_weapon.compatible_ammo.is_empty() and not equipped_weapon.compatible_ammo.has(ammo):
			return false

	equipped_ammo = ammo
	equipped_ammo_changed.emit(equipped_ammo)
	return true


func get_item_slot_index(item: ItemData) -> int:
	for i in range(item_slots.size()):
		if item_slots[i]["item"] == item:
			return i
	return -1


func get_empty_slot_index() -> int:
	for i in range(item_slots.size()):
		if item_slots[i]["item"] == null:
			return i
	return -1
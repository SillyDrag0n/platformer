extends Node

enum WeaponSlot { PRIMARY, SECONDARY }

signal updated_inventory
signal equipped_weapon_changed(slot : WeaponSlot, weapon : WeaponItemData)
signal equipped_ammo_changed(slot : WeaponSlot, ammo : AmmoItemData)
signal equipped_utility_changed(utility : UtilityItemData)
signal equipped_cosmetic_changed(slot : CosmeticItemData.CosmeticSlot, cosmetic : CosmeticItemData)
signal equipped_weapon_skin_changed(slot : WeaponSlot, cosmetic : CosmeticItemData)

var size: int = 20
var start_items: Dictionary[ItemData, int]
var is_open: bool = false

# PURE DATA (no nodes)
var item_slots: Array = []
var equipped_weapons : Dictionary = {} # WeaponSlot -> WeaponItemData
var equipped_ammo : Dictionary = {} # WeaponSlot -> AmmoItemData
var equipped_utility : UtilityItemData = null
var equipped_cosmetics : Dictionary = {} # CosmeticItemData.CosmeticSlot -> CosmeticItemData (non-weapon cosmetics only)
var equipped_weapon_skins : Dictionary = {} # WeaponSlot -> CosmeticItemData (CosmeticSlot.WEAPON_SKIN)

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


func equip_weapon(slot: WeaponSlot, weapon: WeaponItemData) -> bool:
	if weapon != null and get_item_slot_index(weapon) == -1:
		return false

	equipped_weapons[slot] = weapon
	equipped_weapon_changed.emit(slot, weapon)
	return true


func get_equipped_weapon(slot: WeaponSlot) -> WeaponItemData:
	return equipped_weapons.get(slot)


func equip_ammo(slot: WeaponSlot, ammo: AmmoItemData) -> bool:
	if ammo != null and get_item_slot_index(ammo) == -1:
		return false

	equipped_ammo[slot] = ammo
	equipped_ammo_changed.emit(slot, ammo)
	return true


func get_equipped_ammo(slot: WeaponSlot) -> AmmoItemData:
	return equipped_ammo.get(slot)


func equip_utility(utility: UtilityItemData) -> bool:
	if utility != null and get_item_slot_index(utility) == -1:
		return false

	equipped_utility = utility
	equipped_utility_changed.emit(equipped_utility)
	return true


func get_equipped_utility() -> UtilityItemData:
	return equipped_utility


func equip_cosmetic(cosmetic: CosmeticItemData) -> bool:
	if get_item_slot_index(cosmetic) == -1:
		return false

	equipped_cosmetics[cosmetic.slot] = cosmetic
	equipped_cosmetic_changed.emit(cosmetic.slot, cosmetic)
	return true


func unequip_cosmetic(slot: CosmeticItemData.CosmeticSlot) -> void:
	equipped_cosmetics.erase(slot)
	equipped_cosmetic_changed.emit(slot, null)


func get_equipped_cosmetic(slot: CosmeticItemData.CosmeticSlot) -> CosmeticItemData:
	return equipped_cosmetics.get(slot)


func equip_weapon_skin(slot: WeaponSlot, cosmetic: CosmeticItemData) -> bool:
	if cosmetic != null and get_item_slot_index(cosmetic) == -1:
		return false

	equipped_weapon_skins[slot] = cosmetic
	equipped_weapon_skin_changed.emit(slot, cosmetic)
	return true


func unequip_weapon_skin(slot: WeaponSlot) -> void:
	equipped_weapon_skins.erase(slot)
	equipped_weapon_skin_changed.emit(slot, null)


func get_equipped_weapon_skin(slot: WeaponSlot) -> CosmeticItemData:
	return equipped_weapon_skins.get(slot)


func get_owned_items_by_type(type) -> Array:
	var result : Array = []
	for slot_data in item_slots:
		if slot_data["item"] != null and is_instance_of(slot_data["item"], type):
			result.append(slot_data["item"])
	return result


func get_owned_cosmetics_by_slot(slot: CosmeticItemData.CosmeticSlot) -> Array[CosmeticItemData]:
	var result : Array[CosmeticItemData] = []
	for slot_data in item_slots:
		var item = slot_data["item"]
		if item is CosmeticItemData and item.slot == slot:
			result.append(item)
	return result


func is_owned(item: ItemData) -> bool:
	return get_item_slot_index(item) != -1


func get_owned_quantity(item: ItemData) -> int:
	var slot_index = get_item_slot_index(item)
	if slot_index == -1:
		return 0
	return item_slots[slot_index]["quantity"]


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
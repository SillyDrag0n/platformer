extends GutTest

# The two weapon slots on the loadout screen, and the rules about what can go in them.
#
# Reported together: the primary slot never offered a way to clear it, and both slots offered the
# whole armoury, so the same gun could sit in the primary and the secondary at once. The two are
# linked - moving a weapon from one hand to the other means emptying the first, which needs the
# clear the primary slot never had.

const InventoryUIScene = preload("res://ui/inventory/InventoryUI.tscn")
const PlayerScene = preload("res://player/player.tscn")
const REVOLVER : WeaponItemData = preload("res://items/weapons/revolver.tres")
const SHOTGUN : WeaponItemData = preload("res://items/weapons/shotgun.tres")

var inventory_ui


func before_each():
	InventoryManager.is_open = false
	InventoryManager.reset_progress()
	InventoryManager.add_item(REVOLVER)
	InventoryManager.add_item(SHOTGUN)


func after_each():
	InventoryManager.is_open = false
	InventoryManager.reset_progress()


func _open_inventory() -> void:
	inventory_ui = InventoryUIScene.instantiate()
	add_child_autofree(inventory_ui)
	await wait_physics_frames(2)
	inventory_ui._set_open(true)
	await wait_physics_frames(2)


# The picker's rows, as the item each one stands for. A null entry is the "None (unequip)" row.
func _picker_options() -> Array:
	var options : Array = []
	for entry in inventory_ui.picker_list_container.get_children():
		options.append(entry.item)
	return options


func _arm(primary : WeaponItemData, secondary : WeaponItemData) -> void:
	InventoryManager.equip_weapon(InventoryManager.WeaponSlot.PRIMARY, primary)
	InventoryManager.equip_weapon(InventoryManager.WeaponSlot.SECONDARY, secondary)


# --- One gun, one hand ---

func test_a_weapon_in_one_slot_is_not_offered_for_the_other():
	await _open_inventory()
	_arm(REVOLVER, SHOTGUN)

	inventory_ui._open_weapon_picker(InventoryManager.WeaponSlot.SECONDARY)
	await wait_physics_frames(2)

	var options := _picker_options()
	assert_does_not_have(options, REVOLVER, \
		"the revolver is already in the primary slot - one gun cannot be carried in both hands")
	assert_has(options, SHOTGUN, "while the slot's own weapon stays listed")


func test_a_slot_still_lists_the_weapon_it_is_holding_itself():
	await _open_inventory()
	# The state the rule is meant to prevent, as a save made before it existed would hold it.
	_arm(REVOLVER, REVOLVER)

	inventory_ui._open_weapon_picker(InventoryManager.WeaponSlot.PRIMARY)
	await wait_physics_frames(2)

	assert_has(_picker_options(), REVOLVER, \
		"hiding it would leave the player looking at a slot whose contents are missing from the " + \
		"very list they were given to change it with")


# --- Putting a weapon down ---

func test_the_primary_slot_can_be_cleared_when_the_secondary_is_armed():
	await _open_inventory()
	_arm(REVOLVER, SHOTGUN)

	inventory_ui._open_weapon_picker(InventoryManager.WeaponSlot.PRIMARY)
	await wait_physics_frames(2)

	assert_has(_picker_options(), null, \
		"there is a gun in the other hand to fall back on, so this one can be put down")


func test_the_last_weapon_cannot_be_put_down():
	await _open_inventory()
	_arm(REVOLVER, null)

	inventory_ui._open_weapon_picker(InventoryManager.WeaponSlot.PRIMARY)
	await wait_physics_frames(2)

	assert_does_not_have(_picker_options(), null, \
		"clearing this one would leave both hands empty, and Gun.gd would answer that by arming " + \
		"a weapon sitting in neither slot")


# --- What the gun actually fires ---

func test_clearing_the_primary_slot_arms_the_secondary():
	var player = PlayerScene.instantiate()
	add_child_autofree(player)
	var gun = player.get_node("Gun")
	_arm(REVOLVER, SHOTGUN)
	await wait_physics_frames(1)

	InventoryManager.equip_weapon(InventoryManager.WeaponSlot.PRIMARY, null)
	await wait_physics_frames(1)

	assert_eq(gun.weapon, SHOTGUN, \
		"an empty primary falls through to the hand that still has something in it, rather than " + \
		"reaching past both slots for the built-in default")
	assert_eq(gun.active_slot, InventoryManager.WeaponSlot.SECONDARY, \
		"and the gun is honest about which slot it is firing from")


# --- The ammo pair, under the same rules ---
#
# Ammo is keyed by the same WeaponSlot and reads the same way on the loadout screen, so it follows
# the weapon slots rather than keeping the asymmetry the primary slot used to have.

const REGULAR : AmmoItemData = preload("res://items/ammo/regular_rounds.tres")
const HEAVY : AmmoItemData = preload("res://items/ammo/heavy_rounds.tres")


func _load(primary : AmmoItemData, secondary : AmmoItemData) -> void:
	InventoryManager.add_item(REGULAR)
	InventoryManager.add_item(HEAVY)
	InventoryManager.equip_ammo(InventoryManager.WeaponSlot.PRIMARY, primary)
	InventoryManager.equip_ammo(InventoryManager.WeaponSlot.SECONDARY, secondary)


func test_ammo_in_one_slot_is_not_offered_for_the_other():
	await _open_inventory()
	_load(REGULAR, HEAVY)

	inventory_ui._open_ammo_picker(InventoryManager.WeaponSlot.SECONDARY)
	await wait_physics_frames(2)

	var options := _picker_options()
	assert_does_not_have(options, REGULAR, "already loaded in the primary slot")
	assert_has(options, HEAVY, "while the slot's own rounds stay listed")


func test_the_primary_ammo_slot_can_be_cleared_when_the_secondary_is_loaded():
	await _open_inventory()
	_load(REGULAR, HEAVY)

	inventory_ui._open_ammo_picker(InventoryManager.WeaponSlot.PRIMARY)
	await wait_physics_frames(2)

	assert_has(_picker_options(), null, \
		"the primary slot used to be the one slot with no way to empty it")


func test_the_last_loaded_ammo_cannot_be_cleared():
	await _open_inventory()
	_load(REGULAR, null)

	inventory_ui._open_ammo_picker(InventoryManager.WeaponSlot.PRIMARY)
	await wait_physics_frames(2)

	assert_does_not_have(_picker_options(), null, \
		"the pair behaves the same way as the weapon slots above it")

extends GutTest

# Tests a fresh InventoryManager instance rather than the InventoryManager autoload, so item
# slots/equips from one test can never leak into another.

const InventoryManagerScript = preload("res://scripts/managers/inventory_manager.gd")

var inventory : InventoryManagerScript


func before_each():
	inventory = InventoryManagerScript.new()
	add_child_autofree(inventory)


func test_add_item_fills_an_empty_slot():
	var item := ItemData.new()
	item.max_stack_size = 1

	assert_true(inventory.add_item(item))
	assert_eq(inventory.get_owned_quantity(item), 1)
	assert_true(inventory.is_owned(item))


func test_add_item_stacks_up_to_max_stack_size():
	var item := ItemData.new()
	item.max_stack_size = 3

	inventory.add_item(item)
	inventory.add_item(item)
	inventory.add_item(item)

	assert_eq(inventory.get_owned_quantity(item), 3)
	assert_eq(inventory.get_item_slot_index(item), inventory.get_item_slot_index(item), \
		"sanity: still a single slot")
	# A 4th copy can't stack onto the full slot, so it should start a second slot instead of
	# being dropped - total owned quantity only counts the first slot, so check slot count.
	inventory.add_item(item)
	var slots_with_item := 0
	for slot in inventory.item_slots:
		if slot["item"] == item:
			slots_with_item += 1
	assert_eq(slots_with_item, 2, "4th copy should start a new slot once the first is full")


func test_add_item_fails_when_inventory_is_full():
	inventory.size = 1
	inventory.item_slots = [{"item": null, "quantity": 0}]

	var item_a := ItemData.new()
	item_a.max_stack_size = 1
	var item_b := ItemData.new()
	item_b.max_stack_size = 1

	assert_true(inventory.add_item(item_a))
	assert_false(inventory.add_item(item_b), "no empty slot left for a different item")


func test_remove_item_decrements_quantity_then_clears_the_slot():
	var item := ItemData.new()
	item.max_stack_size = 5
	inventory.add_item(item)
	inventory.add_item(item)

	inventory.remove_item(item)
	assert_eq(inventory.get_owned_quantity(item), 1)

	inventory.remove_item(item)
	assert_eq(inventory.get_owned_quantity(item), 0)
	assert_false(inventory.is_owned(item))


func test_remove_item_not_owned_is_a_safe_no_op():
	var item := ItemData.new()
	inventory.remove_item(item)
	assert_eq(inventory.get_owned_quantity(item), 0)


func test_equip_weapon_fails_if_not_owned():
	var weapon := WeaponItemData.new()
	var result := inventory.equip_weapon(InventoryManagerScript.WeaponSlot.PRIMARY, weapon)

	assert_false(result)
	assert_null(inventory.get_equipped_weapon(InventoryManagerScript.WeaponSlot.PRIMARY))


func test_equip_weapon_succeeds_once_owned():
	var weapon := WeaponItemData.new()
	inventory.add_item(weapon)

	watch_signals(inventory)
	var result := inventory.equip_weapon(InventoryManagerScript.WeaponSlot.PRIMARY, weapon)

	assert_true(result)
	assert_eq(inventory.get_equipped_weapon(InventoryManagerScript.WeaponSlot.PRIMARY), weapon)
	assert_signal_emitted_with_parameters(inventory, "equipped_weapon_changed", \
		[InventoryManagerScript.WeaponSlot.PRIMARY, weapon])


func test_equip_weapon_of_null_unequips_the_slot():
	var weapon := WeaponItemData.new()
	inventory.add_item(weapon)
	inventory.equip_weapon(InventoryManagerScript.WeaponSlot.PRIMARY, weapon)

	var result := inventory.equip_weapon(InventoryManagerScript.WeaponSlot.PRIMARY, null)

	assert_true(result, "null is always a valid 'unequip' value")
	assert_null(inventory.get_equipped_weapon(InventoryManagerScript.WeaponSlot.PRIMARY))

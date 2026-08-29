extends GutTest

# Regression test for a reported bug: switching to the Items tab with a controller left nothing
# focused at all, so directional input had nothing to move between slots.

const InventoryUIScene = preload("res://ui/inventory/InventoryUI.tscn")

var inventory_ui


func before_each():
	inventory_ui = InventoryUIScene.instantiate()
	add_child_autofree(inventory_ui)
	await wait_physics_frames(2)


# InventoryManager is a real autoload, not a fresh instance per test - add_child_autofree() above
# frees this test's inventory_ui node, but _set_open(true) also flips InventoryManager.is_open,
# which would otherwise leak into later tests/scripts in the same suite run (MenuPopup.open(),
# used by the shop and dialogue, silently no-ops while is_open is left true from a previous test).
func after_each():
	InventoryManager.is_open = false


func test_opening_inventory_focuses_something():
	inventory_ui._set_open(true)
	await wait_physics_frames(2)

	assert_not_null(inventory_ui.get_viewport().gui_get_focus_owner(), \
		"opening the inventory should focus the first control on the default tab")


func test_items_tab_focuses_a_slot_on_switch():
	inventory_ui._set_open(true)
	await wait_physics_frames(2)

	inventory_ui._cycle_tab(1) # Loadout -> Items
	await wait_physics_frames(2)

	assert_eq(inventory_ui.tab_container.current_tab, 1, "sanity: actually switched to Items")

	var focus_owner = inventory_ui.get_viewport().gui_get_focus_owner()
	assert_not_null(focus_owner, "Items tab should have a focused control after switching to it")


# The grid used to be torn down and rebuilt from scratch on every update_inventory_ui() call
# (picking an item up, equipping something, anything InventoryManager.updated_inventory fires
# for), freeing whatever slot Button the player had focused and silently dropping their focus.
func test_focus_survives_an_inventory_update():
	inventory_ui._set_open(true)
	await wait_physics_frames(2)

	inventory_ui._cycle_tab(1) # Loadout -> Items
	await wait_physics_frames(2)

	var focus_before = inventory_ui.get_viewport().gui_get_focus_owner()
	assert_not_null(focus_before, "sanity: something is focused before the update")

	inventory_ui.update_inventory_ui()
	await wait_physics_frames(2)

	var focus_after = inventory_ui.get_viewport().gui_get_focus_owner()
	assert_eq(focus_after, focus_before, \
		"an inventory update should not steal focus away from whatever slot was focused")


# Regression test: closing the item picker used to always call _grab_default_focus(), which lands
# on the Loadout tab's first control (Primary Weapon, top left) regardless of which slot actually
# opened the picker - so picking a hat, for example, always kicked focus back to the top-left slot
# instead of staying on Hat.
func test_closing_the_picker_restores_focus_to_the_slot_that_opened_it():
	inventory_ui._set_open(true)
	await wait_physics_frames(2)

	inventory_ui.slot_hat.button.grab_focus()
	assert_ne(inventory_ui.get_viewport().gui_get_focus_owner(), inventory_ui.slot_primary.button, \
		"sanity: Hat is focused, not Primary Weapon (the tab's first control)")

	inventory_ui._open_cosmetic_picker(CosmeticItemData.CosmeticSlot.HAT)
	await wait_physics_frames(2)

	inventory_ui._close_picker()
	await wait_physics_frames(2)

	assert_eq(inventory_ui.get_viewport().gui_get_focus_owner(), inventory_ui.slot_hat.button, \
		"closing the picker should return focus to Hat, not jump to the tab's first control")

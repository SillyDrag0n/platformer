extends GutTest

# Regression test for a reported bug: the arms dealer shop didn't work with a controller at all -
# ShopUI._on_opened() never grabbed focus on anything (unlike DialogueBox, which explicitly does),
# so there was nothing for directional input to move from the moment the shop opened.

const ArmsDealerScene = preload("res://tileset/structures/arms_dealer/arms_dealer.tscn")

var dealer
var shop_ui


func before_each():
	# InventoryManager.is_open is a real autoload flag, not per-test state - MenuPopup.open()
	# (which ShopUI uses) silently no-ops while it's left true, so this can't depend on every
	# other test script in the suite having cleaned up after itself.
	InventoryManager.is_open = false

	dealer = ArmsDealerScene.instantiate()
	get_tree().get_root().add_child(dealer)
	shop_ui = dealer.get_node("ShopUi")
	await wait_physics_frames(2)


func after_each():
	if is_instance_valid(dealer):
		dealer.queue_free()
	InventoryManager.is_open = false


func test_opening_the_shop_focuses_the_first_entry():
	shop_ui.open()
	await wait_physics_frames(2)

	assert_not_null(shop_ui.get_viewport().gui_get_focus_owner(), \
		"opening the shop should focus the first item's buy button")


func test_refreshing_the_shop_does_not_steal_focus():
	shop_ui.open()
	await wait_physics_frames(2)

	# Simulate a controller nudge onto some other entry before the refresh happens, same as
	# buying an item (which calls refresh_shop_ui()) would trigger mid-navigation.
	shop_ui._entry_nodes[1].buy_button.grab_focus()
	var focus_before = shop_ui.get_viewport().gui_get_focus_owner()

	shop_ui.refresh_shop_ui()
	await wait_physics_frames(2)

	var focus_after = shop_ui.get_viewport().gui_get_focus_owner()
	assert_eq(focus_after, focus_before, \
		"refreshing the shop (e.g. after buying something) should not move focus away from " + \
		"whatever entry was focused")

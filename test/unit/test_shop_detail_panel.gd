extends GutTest

# The counter display along the bottom of the shop. A shelf row is 68px and truncates the
# description to whatever fits on one line, carrying none of the numbers that decide whether
# something is worth the money - this is the bigger look at whichever row the player is on.

const ArmsDealerScene = preload("res://tileset/structures/arms_dealer/arms_dealer.tscn")
const SHOTGUN : WeaponItemData = preload("res://items/weapons/shotgun.tres")
const HEAVY_ROUNDS : AmmoItemData = preload("res://items/ammo/heavy_rounds.tres")
const SPEED_LOADER : WeaponUpgradeItemData = preload("res://items/weapons/attachements/speed_loader.tres")

var dealer
var shop_ui


func before_each():
	InventoryManager.is_open = false
	InventoryManager.reset_progress()
	CollectibleManager.reset_progress()
	dealer = ArmsDealerScene.instantiate()
	get_tree().get_root().add_child(dealer)
	shop_ui = dealer.get_node("ShopUi")
	await wait_physics_frames(2)


func after_each():
	if is_instance_valid(dealer):
		dealer.queue_free()
	InventoryManager.is_open = false
	InventoryManager.reset_progress()
	CollectibleManager.reset_progress()


func _entry_for(item : ItemData):
	for entry in shop_ui._entry_nodes:
		if entry.item == item:
			return entry
	return null


func test_opening_the_shop_describes_the_row_it_lands_on():
	shop_ui.open()
	await wait_physics_frames(2)

	assert_true(shop_ui.detail_panel.visible, "the counter is up as soon as the shop is")
	assert_eq(shop_ui.detail_name_label.text, tr(shop_ui.shop_items[0].display_name), \
		"and it describes the row the opening focus grab landed on")


func test_moving_the_highlight_changes_what_the_counter_shows():
	shop_ui.open()
	await wait_physics_frames(2)

	_entry_for(HEAVY_ROUNDS).buy_button.grab_focus()
	await wait_physics_frames(2)

	assert_eq(shop_ui.detail_name_label.text, tr(HEAVY_ROUNDS.display_name))
	assert_string_contains(shop_ui.detail_price_label.text, str(HEAVY_ROUNDS.price))


# A mouse user pressing Buy to find out what they were buying is the one thing this must not
# require - that is the press that spends the money.
func test_hovering_a_row_is_enough_to_read_it():
	shop_ui.open()
	await wait_physics_frames(2)

	_entry_for(SHOTGUN)._raise_highlight()
	await wait_physics_frames(1)

	assert_eq(shop_ui.detail_name_label.text, tr(SHOTGUN.display_name))


func test_it_carries_the_numbers_the_shelf_row_has_no_room_for():
	shop_ui.open()
	await wait_physics_frames(2)

	_entry_for(SHOTGUN)._raise_highlight()
	await wait_physics_frames(1)
	var weapon_stats : String = shop_ui.detail_stats_label.text
	assert_string_contains(weapon_stats, str(SHOTGUN.bullet_damage), "what it hits for")
	assert_string_contains(weapon_stats, str(SHOTGUN.magazine_size), "and how much it holds")

	_entry_for(SPEED_LOADER)._raise_highlight()
	await wait_physics_frames(1)
	assert_string_contains(shop_ui.detail_stats_label.text, \
		tr(SPEED_LOADER.target_weapon.display_name), \
		"an upgrade does nothing at all while any other weapon is in hand, so which gun it was " + \
		"made for is the first thing worth saying about it")


func test_buying_something_updates_what_the_counter_says_about_it():
	shop_ui.open()
	await wait_physics_frames(2)
	_entry_for(SHOTGUN)._raise_highlight()
	await wait_physics_frames(1)
	assert_eq(shop_ui.detail_stock_label.text, "", "sanity: not owned yet")

	CollectibleManager.give_pickup_award(SHOTGUN.price)
	shop_ui._on_entry_buy_pressed(SHOTGUN)
	await wait_physics_frames(2)

	assert_eq(shop_ui.detail_stock_label.text, tr("Owned"), \
		"the price stays put but what the player already has does not")

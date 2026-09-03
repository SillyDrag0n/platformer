extends GutTest

# The utility belt starts empty now - dynamite and spirit are bought, not handed out at spawn - so
# there has to be somewhere to buy them. Rosa's saloon sells spirit by the bottle; the arms dealer
# sells dynamite by the bundle. What's pinned here is that the shelves are stocked and that a
# bundle is sold whole rather than a stick at a time.

const SaloonScene = preload("res://levels/hub/saloon_interior/saloon_interior.tscn")
const SPIRIT : ItemData = preload("res://items/utility/spirit.tres")
const DYNAMITE : ItemData = preload("res://items/utility/dynamite.tres")

var _original_dollars : int


func before_each():
	_original_dollars = CollectibleManager.total_award_amount
	InventoryManager.is_open = false
	InventoryManager.initialize_inventory()


func after_each():
	CollectibleManager.total_award_amount = _original_dollars
	InventoryManager.is_open = false
	InventoryManager.initialize_inventory()


func test_the_player_no_longer_starts_with_a_utility_belt():
	var saloon = SaloonScene.instantiate()
	add_child_autofree(saloon)
	await wait_physics_frames(2)

	assert_eq(InventoryManager.get_owned_quantity(DYNAMITE), 0, \
		"dynamite is bought from the arms dealer now, not granted at spawn")
	assert_eq(InventoryManager.get_owned_quantity(SPIRIT), 0, \
		"and spirit is bought from Rosa")


func test_rosa_sells_spirit_by_the_bottle():
	var saloon = SaloonScene.instantiate()
	add_child_autofree(saloon)
	await wait_physics_frames(2)

	var barkeep = saloon.get_node("Barkeep")
	assert_has(barkeep.shop_ui.shop_items, SPIRIT, "the saloon stocks spirit")
	assert_eq(SPIRIT.price, 10, "at ten dollars a bottle")
	assert_eq(SPIRIT.purchase_quantity, 1, "sold singly, unlike the dynamite bundle")


func test_talking_to_rosa_offers_the_shop():
	var saloon = SaloonScene.instantiate()
	add_child_autofree(saloon)
	await wait_physics_frames(2)

	var barkeep = saloon.get_node("Barkeep")
	barkeep._on_interact()
	await wait_frames(1)
	assert_true(barkeep.dialogue_box.visible, "she asks first")

	# Through the Yes button rather than the callback directly: the box closes itself first, and
	# MenuPopup.open() refuses to stack a shop on top of a dialogue that is still up.
	barkeep.dialogue_box._on_yes_button_pressed()
	await wait_frames(1)
	assert_true(barkeep.shop_ui.visible, "and saying yes opens the shop")
	barkeep.shop_ui.close()


func test_dynamite_is_sold_as_a_bundle_of_three():
	assert_eq(DYNAMITE.price, 18, "eighteen dollars")
	assert_eq(DYNAMITE.purchase_quantity, 3, "for three sticks")

	var shop := _open_shop([DYNAMITE])
	await wait_frames(1)
	CollectibleManager.total_award_amount = 20

	shop._on_entry_buy_pressed(DYNAMITE)

	assert_eq(InventoryManager.get_owned_quantity(DYNAMITE), 3, \
		"one purchase hands over the whole bundle")
	assert_eq(CollectibleManager.total_award_amount, 2, "and charges for it once")


func test_a_bundle_is_not_sold_when_there_is_no_room_for_all_of_it():
	var shop := _open_shop([DYNAMITE])
	await wait_frames(1)
	CollectibleManager.total_award_amount = 100
	InventoryManager.add_item(DYNAMITE)
	var before : int = CollectibleManager.total_award_amount

	shop._on_entry_buy_pressed(DYNAMITE)

	assert_eq(InventoryManager.get_owned_quantity(DYNAMITE), 1, \
		"three into a stack that holds three doesn't fit alongside one already there")
	assert_eq(CollectibleManager.total_award_amount, before, \
		"and nothing is charged for a bundle that wasn't handed over")


func test_a_bundle_shows_what_it_contains_on_the_shelf():
	var shop := _open_shop([DYNAMITE, SPIRIT])
	await wait_frames(1)

	assert_eq(shop._entry_nodes[0].name_label.text, "3 x Dynamite", \
		"the price has to read against what the player actually gets")
	assert_eq(shop._entry_nodes[1].name_label.text, "Spirit", \
		"while a single item is just itself")


func _open_shop(items : Array[ItemData]) -> ShopUI:
	var saloon = SaloonScene.instantiate()
	add_child_autofree(saloon)
	var shop : ShopUI = saloon.get_node("Barkeep/ShopUi")
	shop.shop_items = items
	# Entries are built once in _ready(), so restock before it runs.
	for entry in shop._entry_nodes:
		entry.queue_free()
	shop._entry_nodes.clear()
	shop._create_shop_entries()
	return shop

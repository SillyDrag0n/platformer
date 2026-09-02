extends GutTest

# The inventory's tabs used to position their contents by hand: every one of them held plain
# Controls anchored at hardcoded 1440x840 offsets, with the Items and Bounties tabs split at a
# fixed y of 591. Nothing adapted - the numbers only happened to line up with a 1920x1080 window
# and the margins the screen was authored against. They are laid out by containers now, so this
# pins the property that actually matters: each tab's contents fill the tab they are in.

const InventoryUIScene = preload("res://ui/inventory/InventoryUI.tscn")

var inventory_ui


func before_each():
	InventoryManager.is_open = false
	inventory_ui = InventoryUIScene.instantiate()
	add_child_autofree(inventory_ui)
	await wait_physics_frames(2)
	inventory_ui._set_open(true)
	await wait_physics_frames(2)


func after_each():
	InventoryManager.is_open = false


func test_every_tab_fills_the_space_it_is_given():
	var tabs : TabContainer = inventory_ui.tab_container
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await wait_physics_frames(2)
		var tab : Control = tabs.get_tab_control(i)
		var title := tabs.get_tab_title(i)
		assert_almost_eq(tab.size.x, tabs.size.x, 8.0, \
			"the %s tab should be as wide as the container holding it" % title)
		assert_gt(tab.size.y, 0.0, "%s should have been given a height at all" % title)


# The two tabs that pair a list with a detail panel below it. The panel is a fixed height and the
# list takes whatever is left, rather than both being pinned to a hand-picked split point.
func test_the_list_tabs_give_their_leftover_height_to_the_list():
	var tabs : TabContainer = inventory_ui.tab_container
	for pair in [["Items", "ItemSlots", "ItemDetail"], ["Bounties", "BountyList", "BountyDetail"]]:
		var tab : Control = tabs.get_node(pair[0])
		var list : Control = tab.get_node(pair[1])
		var detail : Control = tab.get_node(pair[2])
		tabs.current_tab = tab.get_index()
		await wait_physics_frames(2)

		assert_gt(list.size.y, detail.size.y, \
			"%s's list should take the room left over, not sit in a fixed half" % pair[0])
		assert_almost_eq(list.size.y + detail.size.y, tab.size.y - 20.0, 8.0, \
			"%s's list and detail together should account for the whole tab" % pair[0])


func test_the_item_detail_icon_takes_part_in_the_layout():
	# It was a Sprite2D at a hand-placed position inside a PanelContainer, so it neither scaled
	# with the panel nor moved with it.
	assert_true(inventory_ui.item_information_icon is TextureRect, \
		"the detail icon has to be a Control to be laid out at all")

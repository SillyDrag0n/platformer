extends GutTest

# The inventory used to be the one menu that could stack on top of another. InventoryManager.is_open
# is a single shared "a menu is up" flag (see ui/menu_popup.gd), and MenuPopup.open() refuses to
# stack on it - but the inventory's own toggle was left ungated so it could always be closed. So
# opening the bag mid-conversation worked, and closing it cleared the shared flag while the
# dialogue was still on screen, handing the player their controls back with a box still up.

const InventoryUIScene = preload("res://ui/inventory/InventoryUI.tscn")
const DialogueBoxScene = preload("res://ui/dialogue/DialogueBox.tscn")

var _inventory


func before_each():
	InventoryManager.is_open = false
	GameInputEvents.release_scripted_control()
	_inventory = InventoryUIScene.instantiate()
	add_child_autofree(_inventory)
	await wait_physics_frames(2)


func after_each():
	InventoryManager.is_open = false
	GameInputEvents.release_scripted_control()


func test_the_bag_opens_when_nothing_else_is_up():
	assert_true(_inventory._can_toggle(), "the ordinary case - standing in a level, nothing on screen")


func test_the_bag_does_not_open_during_a_conversation():
	var dialogue = DialogueBoxScene.instantiate()
	add_child_autofree(dialogue)
	await wait_frames(1)
	var lines : Array[String] = ["Somethin' has been at my herd."]
	dialogue.show_dialogue("Hutch", lines)

	assert_true(dialogue.visible, "the box is up")
	assert_false(_inventory._can_toggle(), \
		"and the inventory key should do nothing while it is")

	dialogue.close()


# Same shared flag, so the shop is covered by the same guard - worth pinning because it is the
# other menu a player is most likely to press the bag button in front of.
func test_the_bag_does_not_open_over_another_menu():
	InventoryManager.is_open = true

	assert_false(_inventory._can_toggle(), "something else is holding the shared menu flag")


# A scripted beat has already taken the controls off the player; the bag should not be a way around
# that either. This is the case levels/farm_house_backyard/coyote_encounter.gd had to write a
# defensive workaround for.
func test_the_bag_does_not_open_during_a_scripted_beat():
	GameInputEvents.take_scripted_control()

	assert_false(_inventory._can_toggle(), "the player is not holding their own controls")


# The important half of the guard. An inventory that cannot be shut is a worse trap than anything
# this prevents - so once it is open, the key always closes it.
func test_an_open_bag_can_always_be_closed():
	_inventory._set_open(true)
	await wait_physics_frames(1)

	assert_true(_inventory._can_toggle(), "it is open, so the key has to be able to shut it")

	# Even if a scripted beat starts while it is open.
	GameInputEvents.take_scripted_control()
	assert_true(_inventory._can_toggle(), "and still shut it if something takes control meanwhile")

	_inventory._set_open(false)

extends GutTest

# InventoryManager.is_open is one shared flag on an autoload, and every player-input getter reads it
# (see GameInputEvents.is_input_locked()). A menu that disappears while it is still open therefore
# takes the player's controls with it: the flag stays true, and there is no longer a menu on screen
# to close and clear it. That is reachable now that a dialogue closing can lead straight into a
# scene change - the tutorial's farmer debrief ends exactly that way.

const DialogueBoxScene = preload("res://ui/dialogue/DialogueBox.tscn")


func before_each():
	InventoryManager.is_open = false


func after_each():
	InventoryManager.is_open = false


func test_a_menu_freed_while_open_hands_the_controls_back():
	var box = DialogueBoxScene.instantiate()
	add_child(box)
	box.show_dialogue("Hutch", ["Somethin' been at my herd."] as Array[String])

	assert_true(InventoryManager.is_open, "an open menu holds player input")

	box.free()

	assert_false(InventoryManager.is_open, \
		"and a menu that goes away while open has to hand it back, or the next scene starts " + \
		"with the player frozen and nothing on screen to unfreeze them")
	assert_false(GameInputEvents.is_input_locked())


func test_closing_a_menu_normally_still_works():
	var box = DialogueBoxScene.instantiate()
	add_child_autofree(box)
	box.show_dialogue("Hutch", ["Somethin' been at my herd."] as Array[String])
	box.close()

	assert_false(InventoryManager.is_open)
	assert_false(box.visible)


func test_freeing_a_closed_menu_leaves_another_menu_alone():
	var box = DialogueBoxScene.instantiate()
	add_child(box)
	# Something else owns the flag - an inventory screen, say - and this box was never opened.
	InventoryManager.is_open = true

	box.free()

	assert_true(InventoryManager.is_open, \
		"a menu that wasn't up doesn't own the flag, so tearing it down mustn't clear it")

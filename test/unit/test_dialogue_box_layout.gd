extends GutTest

# The dialogue box was the one screen in the game that never assigned game_theme.tres, so every
# NPC conversation rendered in stock Godot grey. Worse, its root was a full-screen Panel - a node
# that always paints its stylebox - so talking to anyone covered the entire world with an opaque
# slab and put the text near the bottom of it.

const DialogueScene = preload("res://ui/dialogue/DialogueBox.tscn")

var box


func before_each():
	InventoryManager.is_open = false
	box = DialogueScene.instantiate()
	add_child_autofree(box)
	await wait_physics_frames(2)


func after_each():
	InventoryManager.is_open = false


func _say(line : String) -> void:
	var lines : Array[String] = [line]
	box.show_dialogue("Hutch", lines)
	await wait_physics_frames(2)


func test_the_world_is_still_visible_behind_a_conversation():
	await _say("Somethin' has been at my herd.")

	var root : Control = box.get_node("Root")
	assert_false(root is Panel, \
		"a Panel root paints its stylebox over the whole screen, which is the game world")
	assert_not_null(root.theme, \
		"and without a theme the box renders in stock Godot grey in a western game")


func test_the_box_sits_in_the_lower_band_of_the_screen():
	await _say("Ride out and see it for yourself.")

	var card : Control = box.get_node("Root/Box")
	var screen_height : float = box.get_node("Root").size.y
	assert_gt(card.position.y, screen_height * 0.5, \
		"dialogue belongs under the action, not across the middle of it")
	assert_lt(card.position.y + card.size.y, screen_height, \
		"and it should not run off the bottom edge")


func test_the_speaker_is_named_on_its_own_plate():
	await _say("No wolf, and no rustler.")

	var nameplate : Control = box.get_node("Root/Box/BoxMargin/Body/Nameplate")
	assert_true(nameplate.visible)
	assert_lt(nameplate.size.x, box.get_node("Root/Box").size.x * 0.5, \
		"the plate should hug the name rather than stretch the width of the box")
	assert_eq(box.speaker_label.text, "Hutch")


func test_a_choice_hands_focus_to_the_first_button():
	box.show_choice("Hutch", "Care to trade?", "Yes", "No", func(): pass, func(): pass)
	await wait_physics_frames(2)

	assert_eq(box.get_viewport().gui_get_focus_owner(), box.yes_button, \
		"a controller has nothing to press otherwise")

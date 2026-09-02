extends GutTest

# Erasing a save used to ask through a ConfirmationDialog - a real OS Window rather than a Control
# in the scene. That is the same trap the inventory's item picker was pulled out of: a native
# window never reliably receives gamepad input, so the one prompt in the game standing between a
# player and a permanently deleted playthrough could be unanswerable on a pad. It is an embedded
# panel now, and these pin the behaviour that makes it safe.

const SaveSlotScene = preload("res://ui/screens/save_slot_screen.tscn")

var screen


func before_each():
	screen = SaveSlotScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(3)


func _delete_button_for_first_row() -> Button:
	# Each row is [play, delete].
	return screen.slot_list.get_child(0).get_child(1)


func test_the_prompt_is_part_of_the_scene_rather_than_an_os_window():
	assert_true(screen.confirm_panel is Control, \
		"a native Window is the one thing a controller cannot reliably answer")
	assert_false(screen.is_confirming_delete(), "and it stays down until something asks for it")


func test_it_opens_on_the_safe_answer():
	screen._on_delete_pressed(1, _delete_button_for_first_row())
	await wait_physics_frames(2)

	assert_true(screen.is_confirming_delete())
	assert_eq(screen.get_viewport().gui_get_focus_owner(), screen.confirm_cancel_button, \
		"the destructive answer must never be the one confirmed by reflex")
	assert_string_contains(screen.confirm_text.text, "1", "and it names the slot it is asking about")


func test_backing_out_returns_to_the_row_it_was_asked_from():
	var opener := _delete_button_for_first_row()
	screen._on_delete_pressed(1, opener)
	await wait_physics_frames(2)

	screen._close_delete_confirm()
	await wait_physics_frames(2)

	assert_false(screen.is_confirming_delete())
	assert_eq(screen.get_viewport().gui_get_focus_owner(), opener, \
		"closing should put the player back on the row they were working through")


func test_escape_closes_the_prompt_before_the_screen():
	screen._on_delete_pressed(1, _delete_button_for_first_row())
	await wait_physics_frames(2)

	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	screen._unhandled_input(event)
	await wait_physics_frames(2)

	assert_false(screen.is_confirming_delete(), \
		"cancel backs out one level at a time, the prompt before the screen itself")
	assert_true(is_instance_valid(screen), "and the screen itself is still standing")

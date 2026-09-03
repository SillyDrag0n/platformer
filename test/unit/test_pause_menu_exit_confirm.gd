extends GutTest

# Both ways out of the pause menu that abandon a level in progress - RETURN TO TOWN and MAIN MENU -
# ask before they act. The prompt is one embedded panel serving both buttons (see
# ui/screens/pause_menu_screen.gd), which is the same shape the save slots' delete prompt uses and
# for the same reason: a native ConfirmationDialog is a real OS Window, and a pause menu is exactly
# where a player is holding a gamepad it would not answer.

const PauseMenuScene = preload("res://ui/screens/pause_menu_screen.tscn")

var menu


func before_each():
	menu = PauseMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_physics_frames(2)


func after_each():
	get_tree().paused = false


func test_neither_exit_acts_on_a_single_press():
	assert_false(menu.is_confirming(), "the prompt stays down until something asks for it")

	menu._on_return_to_hub_button_pressed()
	await wait_physics_frames(2)

	assert_true(menu.is_confirming(), \
		"riding out of a level part-way is not something to do by brushing a button")
	assert_true(menu.is_inside_tree(), "and nothing has happened yet - the menu is still up")


func test_it_opens_on_the_safe_answer():
	menu._on_main_menu_button_pressed()
	await wait_physics_frames(2)

	assert_eq(menu.get_viewport().gui_get_focus_owner(), menu.confirm_stay_button, \
		"the answer that throws away what the player is doing must not be the reflex one")


func test_the_prompt_says_which_way_out_it_is_asking_about():
	menu._on_return_to_hub_button_pressed()
	await wait_physics_frames(2)
	var hub_text : String = menu.confirm_text.text

	menu.close_confirm()
	menu._on_main_menu_button_pressed()
	await wait_physics_frames(2)

	assert_ne(menu.confirm_text.text, hub_text, \
		"one panel serves both buttons, so it has to be re-worded each time rather than " + \
		"asking about whichever was pressed first")


func test_backing_out_returns_to_the_button_it_was_asked_from():
	menu._on_main_menu_button_pressed()
	await wait_physics_frames(2)

	menu.close_confirm()
	await wait_physics_frames(2)

	assert_false(menu.is_confirming())
	assert_eq(menu.get_viewport().gui_get_focus_owner(), menu.main_menu_button, \
		"closing should put the player back on the button they were considering")


# Escape is the gesture that backs out of everything in this game, and it has to peel one layer at
# a time - answering the prompt with it should not also unpause the game underneath.
func test_escape_closes_the_prompt_before_the_menu():
	get_tree().paused = true
	menu._on_return_to_hub_button_pressed()
	await wait_physics_frames(2)

	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	menu._unhandled_input(event)
	await wait_physics_frames(2)

	assert_false(menu.is_confirming(), "the prompt goes first")
	assert_true(get_tree().paused, "and the game stays paused behind it")
	assert_true(menu.is_inside_tree(), "with the menu still up")

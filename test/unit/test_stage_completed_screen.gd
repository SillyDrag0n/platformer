extends GutTest

# The screen shown between the level that finishes a leg of a bounty and the ride back to town:
# what the player just did, what they were paid for it, and what the contract asks next. The
# bounty's own reward screen is for the end of the whole contract - this one fires two stages
# earlier, which is why driving the coyote off used to end on nothing at all.

const StageCompletedScene = preload("res://ui/screens/stage_completed.tscn")
const BOUNTY_ID := "missing_cattle"

var _original_objectives : Dictionary
var _original_completed : bool


func before_each():
	var bounty := _bounty()
	_original_objectives = {}
	_original_completed = bounty.completed
	bounty.completed = false
	for stage in bounty.stages:
		for objective in stage.objectives:
			_original_objectives[objective.id] = objective.completed
			objective.completed = false
	UiManager.clear_completed_stage()


func after_each():
	var bounty := _bounty()
	bounty.completed = _original_completed
	for stage in bounty.stages:
		for objective in stage.objectives:
			objective.completed = _original_objectives.get(objective.id, false)
	UiManager.clear_completed_stage()


func _bounty() -> BountyData:
	return GameStateManager.get_bounty_by_id(BOUNTY_ID)


func _finish_first_stage() -> void:
	for objective in _bounty().stages[0].objectives:
		GameStateManager.complete_objective(BOUNTY_ID, objective.id)


# Staged directly rather than through open_stage_completed_screen(), which would change the scene
# out from under the test runner.
func _show_screen(payment : int) -> CanvasLayer:
	var bounty := _bounty()
	UiManager.completed_stage_bounty = bounty
	UiManager.completed_stage = bounty.stages[0]
	UiManager.completed_stage_payment = payment
	UiManager.completed_stage_exit_key = "Hub"

	var screen = StageCompletedScene.instantiate()
	add_child_autofree(screen)
	await wait_frames(1)
	return screen


func test_it_reports_the_leg_that_was_just_finished():
	_finish_first_stage()
	var screen := await _show_screen(15)

	assert_eq(screen.stage_title_label.text, "Investigate the Missing Cattle", \
		"the leg they just saw through")
	assert_string_contains(screen.done_label.text, "[x] Go to the attack site")
	assert_string_contains(screen.done_label.text, "[x] It escapes", \
		"with every line of it ticked off")


func test_it_reports_what_the_leg_paid():
	_finish_first_stage()
	var screen := await _show_screen(15)

	assert_true(screen.payment_label.visible)
	assert_string_contains(screen.payment_label.text, "15", \
		"the fifteen dollars Hutch pressed on them, which otherwise landed with no acknowledgement")


func test_a_leg_that_paid_nothing_shows_no_payment_line():
	_finish_first_stage()
	var screen := await _show_screen(0)

	assert_false(screen.payment_label.visible, \
		"not every leg of a job pays on its own, and a '$0' line reads as a bug")


func test_it_points_at_what_the_contract_asks_next():
	_finish_first_stage()
	var screen := await _show_screen(15)

	assert_string_contains(screen.next_label.text, "Seek the Shaman", "the next leg by name")
	assert_string_contains(screen.next_label.text, "Find the shaman", "and what it asks of them")


func test_the_last_leg_has_nothing_to_point_at():
	for stage in _bounty().stages:
		for objective in stage.objectives:
			GameStateManager.complete_objective(BOUNTY_ID, objective.id)
	var screen := await _show_screen(0)

	assert_false(screen.next_label.visible, \
		"the end of the contract is the bounty's own reward screen's job, so there is nothing " + \
		"left for this one to send them to")


func test_the_continue_button_holds_focus_for_a_controller():
	_finish_first_stage()
	var screen := await _show_screen(15)

	assert_eq(screen.get_viewport().gui_get_focus_owner(), screen.continue_button, \
		"a screen with one button still has to hand it focus, or a pad has nothing to press")

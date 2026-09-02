extends GutTest

# Quitting part-way through a bounty and coming back to it.
#
# Two things went wrong here. The game only ever saved from the Exit Game button, so closing the
# window - which is how most people quit - wrote nothing at all and lost the session. And even a
# save that was written did not record which contract was in hand, so reloading left the player
# with the job still on the board but nothing active.

const BOUNTY_ID := "missing_cattle"

var _real_save_path : String
var _real_slot : int


func before_each():
	# SaveManager.save_path points at the player's real save directory - redirected to a scratch
	# location so this can never touch or delete it.
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch_contract/"
	SaveManager.active_slot = 1
	GameStateManager.reset_progress()


func after_each():
	var slot_file := SaveManager.slot_path(1)
	if FileAccess.file_exists(slot_file):
		DirAccess.remove_absolute(slot_file)
	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot
	GameStateManager.reset_progress()


# Accepted off the board and played as far as the coyote den, the contract's last leg.
func _play_to_the_last_leg() -> BountyData:
	var bounty : BountyData = GameStateManager.get_bounty_by_id(BOUNTY_ID)
	GameStateManager.set_active_bounty(bounty)
	for i in 2:
		for objective in bounty.stages[i].objectives:
			GameStateManager.complete_objective(BOUNTY_ID, objective.id)
	return bounty


func test_the_contract_is_still_in_hand_after_a_reload():
	var bounty := _play_to_the_last_leg()
	assert_eq(bounty.get_current_stage_index(), 2, "sanity: he is on the last leg")

	SaveManager.save_game()
	GameStateManager.reset_progress()
	assert_null(GameStateManager.active_bounty, "sanity: a fresh launch has no job in hand")

	SaveManager.load_slot(1)

	assert_not_null(GameStateManager.active_bounty, \
		"the job the player was part-way through should come back with them")
	assert_eq(GameStateManager.active_bounty.id, BOUNTY_ID)
	assert_eq(GameStateManager.active_bounty.get_current_stage_index(), 2, \
		"and on the leg they left off at, not back at the start")


func test_the_bounty_is_still_on_the_board_after_a_reload():
	_play_to_the_last_leg()
	SaveManager.save_game()
	GameStateManager.reset_progress()
	SaveManager.load_slot(1)

	var ids : Array[String] = []
	for bounty in GameStateManager.get_unlocked_bounties():
		ids.append(bounty.id)
	assert_has(ids, BOUNTY_ID, "the contract should still be posted")


func test_nothing_in_hand_saves_and_loads_as_nothing_in_hand():
	SaveManager.save_game()
	GameStateManager.reset_progress()
	SaveManager.load_slot(1)

	assert_null(GameStateManager.active_bounty, \
		"a player who has taken no job should not be handed one by the loader")


# The window's close button and Alt+F4 reach the game as NOTIFICATION_WM_CLOSE_REQUEST, which
# Godot acts on itself unless told otherwise - so nothing was ever written on the way out.
func test_the_game_asks_to_handle_its_own_quit():
	assert_false(get_tree().auto_accept_quit, \
		"otherwise closing the window quits before anything can be saved")

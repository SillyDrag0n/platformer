extends GutTest

# Coverage for SaveManager persisting the one-shot story flags on GameStateManager -
# has_shown_hub_welcome (gates WelcomeNPC's auto-greet timer, see npc/welcome_npc.gd) and
# has_driven_off_coyote (gates the tutorial's cactus coyote encounter, see
# levels/farm_house_backyard/coyote_encounter.gd). Both used to / would otherwise live only in
# memory, so they'd reset on every game restart and replay their one-time moment each relaunch.

var _real_save_path : String
var _real_save_file_name : String
var _original_has_shown_hub_welcome : bool
var _original_has_driven_off_coyote : bool


func before_each():
	# SaveManager.save_path/save_file_name point at the player's real save file - redirected to a
	# scratch location so this can never touch or delete it.
	_real_save_path = SaveManager.save_path
	_real_save_file_name = SaveManager.save_file_name
	SaveManager.save_path = "user://test_scratch/"
	SaveManager.save_file_name = "test_save_data.tres"

	_original_has_shown_hub_welcome = GameStateManager.has_shown_hub_welcome
	_original_has_driven_off_coyote = GameStateManager.has_driven_off_coyote


func after_each():
	var scratch_full_path := SaveManager.save_path + SaveManager.save_file_name
	if FileAccess.file_exists(scratch_full_path):
		DirAccess.remove_absolute(scratch_full_path)

	SaveManager.save_path = _real_save_path
	SaveManager.save_file_name = _real_save_file_name
	GameStateManager.has_shown_hub_welcome = _original_has_shown_hub_welcome
	GameStateManager.has_driven_off_coyote = _original_has_driven_off_coyote


func test_has_shown_hub_welcome_survives_a_save_and_load_round_trip():
	GameStateManager.has_shown_hub_welcome = true
	SaveManager.save_game()

	GameStateManager.has_shown_hub_welcome = false
	SaveManager.load_game()

	assert_true(GameStateManager.has_shown_hub_welcome, \
		"loading a save made after the auto-greet fired should restore the flag")


func test_has_driven_off_coyote_survives_a_save_and_load_round_trip():
	GameStateManager.has_driven_off_coyote = true
	SaveManager.save_game()

	GameStateManager.has_driven_off_coyote = false
	SaveManager.load_game()

	assert_true(GameStateManager.has_driven_off_coyote, \
		"loading a save made after the coyote was run off should restore the flag, so the " + \
		"fight can't be re-staged")

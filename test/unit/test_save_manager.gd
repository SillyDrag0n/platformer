extends GutTest

# Coverage for SaveManager persisting the one-shot story flags on GameStateManager - the hub
# welcome (gates WelcomeNPC's auto-greet timer, see npc/welcome_npc.gd) and the coyote being run
# off (gates the tutorial encounter, see
# levels/regions/plains/farm_house_backyard/coyote_encounter.gd, and retires the hub's tutorial
# furniture). Both would otherwise live only in memory, so they would reset on every restart and
# replay their one-time moment each relaunch.
#
# They are saved as one dictionary rather than a field each, so what matters is that the pool round
# -trips - a beat added later comes along for free.

var _real_save_path : String
var _real_slot : int
var _original_has_shown_hub_welcome : bool
var _original_has_driven_off_coyote : bool


func before_each():
	# SaveManager.save_path points at the player's real save directory - redirected to a
	# scratch location so this can never touch or delete it.
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch/"
	SaveManager.active_slot = 1

	_original_has_shown_hub_welcome = GameStateManager.has_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN)
	_original_has_driven_off_coyote = GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF)


func after_each():
	var scratch_full_path := SaveManager.slot_path(1)
	if FileAccess.file_exists(scratch_full_path):
		DirAccess.remove_absolute(scratch_full_path)

	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot
	GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN, _original_has_shown_hub_welcome)
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, _original_has_driven_off_coyote)


func test_the_hub_welcome_flag_survives_a_save_and_load_round_trip():
	GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN, true)
	SaveManager.save_game()

	GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN, false)
	SaveManager.load_game()

	assert_true(GameStateManager.has_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN), \
		"loading a save made after the auto-greet fired should restore the flag")


func test_the_coyote_driven_off_flag_survives_a_save_and_load_round_trip():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, true)
	SaveManager.save_game()

	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, false)
	SaveManager.load_game()

	assert_true(GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), \
		"loading a save made after the coyote was run off should restore the flag, so the " + \
		"fight can't be re-staged")


# Money used to be picked up off the ground only, so losing it on a restart cost the player
# nothing they'd notice. Story beats hand it out now - Hutch pays for the coyote job - so it has
# to survive the trip.
func test_dollars_survive_a_save_and_load_round_trip():
	var original_dollars : int = CollectibleManager.total_award_amount

	CollectibleManager.total_award_amount = 15
	SaveManager.save_game()
	CollectibleManager.total_award_amount = 0
	SaveManager.load_game()

	assert_eq(CollectibleManager.total_award_amount, 15, \
		"what the farmer paid should still be in the player's pocket after a restart")

	CollectibleManager.total_award_amount = original_dollars


# A beat that has no named constant yet still has to survive the trip - that is the whole point of
# pooling them, and the thing a field-per-beat save could never do.
func test_a_story_flag_the_save_format_has_never_seen_before_round_trips():
	GameStateManager.set_story_flag(&"some_later_beat")
	SaveManager.save_game()

	GameStateManager.story_flags.erase("some_later_beat")
	SaveManager.load_game()

	assert_true(GameStateManager.has_story_flag(&"some_later_beat"), \
		"adding a story beat should need no change to SaveDataResource or SaveManager")
	GameStateManager.story_flags.erase("some_later_beat")


# A save written before the beats were pooled carries a bool field per beat instead. A player
# mid-tutorial must not find the coyote back at the carcass on their next launch.
func test_a_save_from_before_the_flags_were_pooled_still_restores_them():
	var legacy := SaveDataResource.new()
	legacy.has_shown_hub_welcome = true
	legacy.has_driven_off_coyote = true
	ResourceSaver.save(legacy, SaveManager.slot_path(1))

	GameStateManager.story_flags.clear()
	SaveManager.load_game()

	assert_true(GameStateManager.has_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN), \
		"the old has_shown_hub_welcome field should carry over")
	assert_true(GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), \
		"and so should has_driven_off_coyote - otherwise the tutorial restages itself")

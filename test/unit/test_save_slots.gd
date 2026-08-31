extends GutTest

# Three save files (scripts/managers/save_manager.gd). The interesting part isn't the three paths -
# it's that a slot is a whole separate playthrough. Managers hold their progress in memory for the
# entire session and load_game() only overwrites what the file happens to mention, so without
# _reset_game_state() the second slot a player opens would be wearing the first one's hat.

const SPIRIT := preload("res://items/utility/spirit.tres")

var _real_save_path : String
var _real_slot : int


func before_each():
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch/slots/"
	SaveManager.active_slot = SaveManager.NO_SLOT


func after_each():
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var path := SaveManager.slot_path(slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot
	SaveManager.start_new_game(_real_slot)


func test_there_are_three_slots_and_they_are_separate_files():
	assert_eq(SaveManager.SLOT_COUNT, 3)

	var paths : Array[String] = []
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		paths.append(SaveManager.slot_path(slot))
	assert_eq(paths.size(), paths.duplicate().size(), "sanity")
	for i in paths.size():
		for j in range(i + 1, paths.size()):
			assert_ne(paths[i], paths[j], "each slot needs its own file or they overwrite each other")


func test_an_untouched_slot_is_empty():
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		assert_false(SaveManager.has_save(slot), "slot %d starts empty" % slot)
		assert_true(SaveManager.read_slot_summary(slot).is_empty(), \
			"and has nothing to put on the slot screen")


func test_saving_one_slot_leaves_the_others_empty():
	SaveManager.start_new_game(2)
	PlayerManager.player_name = "Cassidy"
	SaveManager.save_game()

	assert_true(SaveManager.has_save(2), "slot 2 was written")
	assert_false(SaveManager.has_save(1), "and slot 1 is untouched")
	assert_false(SaveManager.has_save(3), "and so is slot 3")


func test_the_slot_screen_can_read_a_slot_without_loading_it():
	SaveManager.start_new_game(1)
	PlayerManager.player_name = "Cassidy"
	CollectibleManager.total_award_amount = 240
	SaveManager.save_game()

	# Whatever the running game is doing now, the summary should describe the file.
	PlayerManager.player_name = "Someone Else"
	var summary := SaveManager.read_slot_summary(1)

	assert_eq(summary["player_name"], "Cassidy", "read off the file, not off the running game")
	assert_eq(summary["dollars"], 240)
	assert_gt(summary["saved_at_unix"], 0, "and stamped, so the screen can show when it was played")


# The reason _reset_game_state() exists. Everything below this line is what a shared-state bug
# would look like to a player: opening a second save and finding the first one's progress in it.
func test_opening_a_second_slot_does_not_carry_the_first_ones_progress():
	SaveManager.start_new_game(1)
	PlayerManager.player_name = "Cassidy"
	CollectibleManager.total_award_amount = 500
	InventoryManager.add_item(SPIRIT)
	QuestManager.report_kill("bandit")
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF)
	GameStateManager.unlock_bounty("missing_cattle")
	GameStateManager.complete_objective("missing_cattle", "reach_attack_site")
	SaveManager.save_game()

	SaveManager.start_new_game(2)

	assert_eq(CollectibleManager.total_award_amount, 0, "a new save starts broke")
	assert_eq(QuestManager.get_kill_count("bandit"), 0, "with nothing killed yet")
	assert_eq(InventoryManager.get_owned_quantity(SPIRIT), 0, "and an empty bag")
	assert_false(GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), \
		"the coyote has not been run off in this playthrough")
	assert_false(GameStateManager.is_objective_completed("missing_cattle", "reach_attack_site"), \
		"and no line of the contract is ticked off")


# The bounties are shared authored resources this game ticks off in place, so this is the half of
# the reset most likely to rot: it can only work if the authored values were copied aside at boot.
func test_a_new_slot_restores_the_bounties_the_designer_authored():
	var bounty := GameStateManager.get_bounty_by_id("missing_cattle")
	var authored_unlocked : bool = GameStateManager._authored_bounty_state[bounty.id]["unlocked"]

	SaveManager.start_new_game(1)
	GameStateManager.unlock_bounty("missing_cattle")
	GameStateManager.complete_bounty("missing_cattle")

	SaveManager.start_new_game(2)

	assert_eq(bounty.unlocked, authored_unlocked, "back to however the board was authored")
	assert_false(bounty.completed, "and the job is not done in this playthrough")


func test_loading_a_slot_restores_that_slots_playthrough():
	SaveManager.start_new_game(1)
	PlayerManager.player_name = "Cassidy"
	CollectibleManager.total_award_amount = 500
	SaveManager.save_game()

	SaveManager.start_new_game(2)
	PlayerManager.player_name = "Doc"
	CollectibleManager.total_award_amount = 10
	SaveManager.save_game()

	SaveManager.load_slot(1)

	assert_eq(PlayerManager.player_name, "Cassidy", "slot 1's playthrough came back")
	assert_eq(CollectibleManager.total_award_amount, 500, "with its own money, not slot 2's")


func test_deleting_a_slot_empties_only_that_slot():
	SaveManager.start_new_game(1)
	SaveManager.save_game()
	SaveManager.start_new_game(2)
	SaveManager.save_game()

	SaveManager.delete_slot(1)

	assert_false(SaveManager.has_save(1), "slot 1 is gone")
	assert_true(SaveManager.has_save(2), "and slot 2 is not")


# Deleting the slot you are playing has to let go of it, or the next autosave would quietly
# re-create the file the player just asked to be rid of.
func test_deleting_the_slot_currently_being_played_stops_writing_to_it():
	SaveManager.start_new_game(1)
	SaveManager.save_game()

	SaveManager.delete_slot(1)
	SaveManager.save_game()

	assert_eq(SaveManager.active_slot, SaveManager.NO_SLOT, "no slot is active any more")
	assert_false(SaveManager.has_save(1), "and the autosave did not bring it back")


# Autosaves fire from level exits, the inventory closing and quitting the game - some of which are
# reachable from the menus, before any slot has been picked.
func test_saving_with_no_slot_chosen_writes_nothing():
	SaveManager.active_slot = SaveManager.NO_SLOT

	SaveManager.save_game()

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		assert_false(SaveManager.has_save(slot), "nothing invented a file to write into")


# An existing playthrough must not be stranded by the move to slots. The old game wrote one
# save_data.tres; it becomes slot 1 on the first boot of a build that has slots.
func test_a_save_from_before_slots_becomes_slot_one():
	var legacy := SaveDataResource.new()
	legacy.player_name = "Cassidy"
	legacy.dollars = 320
	if !DirAccess.dir_exists_absolute(SaveManager.save_path):
		DirAccess.make_dir_absolute(SaveManager.save_path)
	ResourceSaver.save(legacy, SaveManager.save_path + SaveManager.LEGACY_SAVE_FILE)

	SaveManager._migrate_legacy_save_file()

	assert_true(SaveManager.has_save(1), "the old save is playable again, as slot 1")
	assert_eq(SaveManager.read_slot_summary(1)["player_name"], "Cassidy", "and it is the same save")
	assert_false(FileAccess.file_exists(SaveManager.save_path + SaveManager.LEGACY_SAVE_FILE), \
		"moved rather than copied, so there is nothing left to migrate next boot")


func test_the_migration_never_overwrites_a_real_slot_one():
	SaveManager.start_new_game(1)
	PlayerManager.player_name = "Doc"
	SaveManager.save_game()

	var legacy := SaveDataResource.new()
	legacy.player_name = "Cassidy"
	ResourceSaver.save(legacy, SaveManager.save_path + SaveManager.LEGACY_SAVE_FILE)
	SaveManager._migrate_legacy_save_file()

	assert_eq(SaveManager.read_slot_summary(1)["player_name"], "Doc", \
		"a slot the player has actually used must not be clobbered by a stale legacy file")
	DirAccess.remove_absolute(SaveManager.save_path + SaveManager.LEGACY_SAVE_FILE)

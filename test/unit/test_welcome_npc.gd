extends GutTest

# Coverage for WelcomeNPC (npc/welcome_npc.gd) - the hub NPC who greets a first-time player.
#
# He used to be the thing that put the game's first bounty on the board, and his greeting was
# gated on that bounty still being locked. Missing Cattle is authored unlocked now, so the job is
# always there to take and the greeting is its own beat, gated on FLAG_HUB_WELCOME_SHOWN alone.
# GameStateManager's bounty list and InventoryManager.is_open are real singleton state, so
# before/after_each save and restore them.

const WelcomeNpcScene = preload("res://npc/WelcomeNPC.tscn")
const BOUNTY_ID := "missing_cattle"

var _original_unlocked : bool


func before_each():
	_original_unlocked = GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked
	GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN, false)
	InventoryManager.is_open = false


func after_each():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = _original_unlocked
	GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN, false)
	InventoryManager.is_open = false


func _spawn(delay : float = 0.05):
	var npc = WelcomeNpcScene.instantiate()
	npc.greet_delay_seconds = delay
	add_child_autofree(npc)
	return npc


# --- The first job is not his to hand over ---

func test_the_first_bounty_is_on_the_board_from_the_start():
	GameStateManager.reset_progress()

	assert_true(GameStateManager.is_bounty_unlocked(BOUNTY_ID), \
		"a brand new game should already have the first contract posted")
	var unlocked_ids : Array[String] = []
	for bounty in GameStateManager.get_unlocked_bounties():
		unlocked_ids.append(bounty.id)
	assert_has(unlocked_ids, BOUNTY_ID, "and the board should be listing it")


func test_it_is_still_there_for_a_player_who_never_talks_to_him():
	GameStateManager.reset_progress()
	var npc = _spawn()
	await wait_seconds(0.1)
	npc.dialogue_box.close()
	InventoryManager.is_open = false

	assert_true(GameStateManager.is_bounty_unlocked(BOUNTY_ID), \
		"talking to him is no longer what puts it on the board")


# --- The greeting is its own beat ---

func test_he_greets_a_first_time_player():
	var npc = _spawn()

	await wait_seconds(0.1)

	assert_true(npc.dialogue_box.visible, \
		"the welcome should not depend on the bounty still being locked - it never is now")


func test_he_does_not_greet_again_once_the_beat_has_played():
	GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN)
	var npc = _spawn()

	await wait_seconds(0.1)

	assert_false(npc.dialogue_box.visible, "one forced intro per playthrough is enough")


func test_interacting_manually_shows_dialogue_immediately():
	var npc = _spawn(10.0)

	npc._on_interact()

	assert_true(npc.dialogue_box.visible)


func test_re_entering_the_hub_does_not_force_greet_again():
	# Leaving and coming back is a fresh NPC instance, same as a scene reload. The player already
	# got the forced intro once and should not be ambushed by it on every hub spawn-in.
	var first_npc = _spawn()
	await wait_seconds(0.1)
	assert_true(first_npc.dialogue_box.visible, "first hub visit should still auto-greet")
	InventoryManager.is_open = false

	var second_npc = _spawn()
	await wait_seconds(0.1)

	assert_false(second_npc.dialogue_box.visible, \
		"a later hub visit should not force the greeting again")

	second_npc._on_interact()
	assert_true(second_npc.dialogue_box.visible, "manual interact should still work")

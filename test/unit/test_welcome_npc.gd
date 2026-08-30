extends GutTest

# Coverage for WelcomeNPC (npc/welcome_npc.gd) - the hub NPC that auto-greets a first-time player
# and puts the game's first bounty on the board once its dialogue is closed. GameStateManager's
# bounty list and InventoryManager.is_open are real singleton state, so before/after_each save and
# restore them.

const WelcomeNpcScene = preload("res://npc/WelcomeNPC.tscn")
const BOUNTY_ID := "missing_cattle"

var _original_unlocked : bool


func before_each():
	_original_unlocked = GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = false
	GameStateManager.has_shown_hub_welcome = false
	InventoryManager.is_open = false


func after_each():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = _original_unlocked
	GameStateManager.has_shown_hub_welcome = false
	InventoryManager.is_open = false


func test_auto_greets_after_delay_when_bounty_is_locked():
	var npc = WelcomeNpcScene.instantiate()
	npc.greet_delay_seconds = 0.05
	add_child_autofree(npc)

	await wait_seconds(0.1)

	assert_true(npc.dialogue_box.visible)


func test_does_not_auto_greet_if_already_unlocked():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var npc = WelcomeNpcScene.instantiate()
	npc.greet_delay_seconds = 0.05
	add_child_autofree(npc)

	await wait_seconds(0.1)

	assert_false(npc.dialogue_box.visible)


func test_closing_dialogue_unlocks_the_bounty():
	var npc = WelcomeNpcScene.instantiate()
	npc.greet_delay_seconds = 0.05
	add_child_autofree(npc)
	await wait_seconds(0.1)

	npc.dialogue_box.close()

	assert_true(GameStateManager.is_bounty_unlocked(BOUNTY_ID))


func test_interacting_manually_shows_dialogue_immediately():
	var npc = WelcomeNpcScene.instantiate()
	npc.greet_delay_seconds = 10.0
	add_child_autofree(npc)

	npc._on_interact()

	assert_true(npc.dialogue_box.visible)


func test_re_entering_the_hub_does_not_force_greet_again():
	# Simulates leaving and re-entering the hub (a fresh NPC instance, same as a scene reload)
	# without ever having talked to the first one - the bounty is still locked, but the player
	# already got the forced intro once and shouldn't be ambushed by it on every hub spawn-in.
	var first_npc = WelcomeNpcScene.instantiate()
	first_npc.greet_delay_seconds = 0.05
	add_child_autofree(first_npc)
	await wait_seconds(0.1)
	assert_true(first_npc.dialogue_box.visible, "first hub visit should still auto-greet")

	# Simulate the player wandering off without formally dismissing that first dialogue - the
	# bounty stays locked (closing it is what unlocks it), so this isolates the new session flag
	# from the pre-existing is_bounty_unlocked gate, which already has its own test coverage.
	InventoryManager.is_open = false

	var second_npc = WelcomeNpcScene.instantiate()
	second_npc.greet_delay_seconds = 0.05
	add_child_autofree(second_npc)
	await wait_seconds(0.1)

	assert_false(second_npc.dialogue_box.visible, \
		"a later hub visit should not force the greeting again while still locked")

	second_npc._on_interact()
	assert_true(second_npc.dialogue_box.visible, "manual interact should still work")

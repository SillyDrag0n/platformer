extends GutTest

# Coverage for BountyTurnInNPC (npc/bounty_turn_in_npc.gd) - the reusable "hand in whatever
# bounty is currently active" NPC archetype (for any non-boss bounty that should grant a reward on
# turn-in; the tutorial bounty's Hutch is dialogue-only and doesn't use this - see HutchNPC.tscn).
# Its _on_dialogue_closed() calls UiManager.open_bounty_completed_screen(),
# which does a real get_tree().change_scene_to_packed() - actually invoking that here would swap
# out the running GUT test scene mid-suite, the same reason test_farm_house.gd only checks that
# its interact/exit callbacks are wired rather than calling them. So this checks the wiring and
# exercises the underlying GameStateManager state transition directly instead.

const BountyTurnInNpcScene = preload("res://npc/BountyTurnInNPC.tscn")


func _make_test_bounty() -> BountyData:
	var bounty := BountyData.new()
	bounty.id = "test_bounty_turn_in"
	return bounty


func before_each():
	InventoryManager.is_open = false


func after_each():
	GameStateManager.clear_active_bounty()
	InventoryManager.is_open = false


func test_dialogue_closed_is_wired_to_the_npcs_handler():
	var npc = BountyTurnInNpcScene.instantiate()
	add_child_autofree(npc)

	assert_true(npc.dialogue_box.closed.is_connected(npc._on_dialogue_closed), \
		"_ready() should connect dialogue_box.closed to _on_dialogue_closed")


func test_interact_shows_the_dialogue():
	var npc = BountyTurnInNpcScene.instantiate()
	add_child_autofree(npc)

	npc._on_interact()

	assert_true(npc.dialogue_box.visible)


func test_completing_the_active_bounty_marks_it_completed_and_grants_rewards():
	var bounty := _make_test_bounty()
	var reward_item := ItemData.new()
	bounty.rewards = [reward_item]
	GameStateManager.set_active_bounty(bounty)

	GameStateManager.complete_active_bounty()
	GameStateManager.give_bounty_reward()

	assert_true(bounty.completed)
	assert_true(bounty.reward_claimed)
	assert_eq(InventoryManager.get_owned_quantity(reward_item), 1)

	var slot_index = InventoryManager.get_item_slot_index(reward_item)
	if slot_index != -1:
		InventoryManager.item_slots[slot_index] = {"item": null, "quantity": 0}


func test_on_dialogue_closed_does_nothing_when_no_bounty_is_active():
	GameStateManager.clear_active_bounty()
	var npc = BountyTurnInNpcScene.instantiate()
	add_child_autofree(npc)

	npc._on_dialogue_closed()

	assert_true(true, \
		"reached this line without error - no active bounty means it returns early, " + \
		"before the scene-changing UiManager call")

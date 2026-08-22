extends GutTest

# QuestManager's item-requirement paths (can_turn_in/turn_in) read and write the real
# InventoryManager autoload directly rather than an injectable dependency, so those tests touch
# global state. _test_items tracks anything added to it so after_each can strip it back out again
# and leave the singleton clean for whatever runs next (including the actual game, if the editor
# session keeps running after the test suite finishes).

const QuestManagerScript = preload("res://scripts/managers/quest_manager.gd")

var quest_manager
var _test_items : Array[ItemData] = []


func before_each():
	quest_manager = QuestManagerScript.new()
	add_child_autofree(quest_manager)
	_test_items.clear()


func after_each():
	for item in _test_items:
		var slot_index = InventoryManager.get_item_slot_index(item)
		if slot_index != -1:
			InventoryManager.item_slots[slot_index] = {"item": null, "quantity": 0}


func _make_owned_item(quantity : int) -> ItemData:
	var item := ItemData.new()
	item.max_stack_size = quantity
	_test_items.append(item)
	for i in range(quantity):
		InventoryManager.add_item(item)
	return item


func _make_kill_quest(enemy_id : String, kill_amount : int) -> QuestData:
	var quest := QuestData.new()
	quest.id = "test_kill_%s" % enemy_id
	quest.required_enemy_id = enemy_id
	quest.required_kill_amount = kill_amount
	return quest


func test_receive_quest_adds_it_once():
	var quest := _make_kill_quest("bandit", 1)

	watch_signals(quest_manager)
	quest_manager.receive_quest(quest)
	quest_manager.receive_quest(quest) # duplicate offer, e.g. re-talking to the same NPC

	assert_true(quest_manager.is_received(quest))
	assert_signal_emit_count(quest_manager, "quest_received", 1)


func test_report_kill_increments_only_the_matching_enemy_id():
	quest_manager.report_kill("bandit")
	quest_manager.report_kill("bandit")
	quest_manager.report_kill("scorpion")

	assert_eq(quest_manager.get_kill_count("bandit"), 2)
	assert_eq(quest_manager.get_kill_count("scorpion"), 1)
	assert_eq(quest_manager.get_kill_count("never_killed"), 0)


func test_can_turn_in_kill_quest_requires_enough_kills():
	var quest := _make_kill_quest("bandit", 3)

	assert_false(quest_manager.can_turn_in(quest))

	quest_manager.report_kill("bandit")
	quest_manager.report_kill("bandit")
	assert_false(quest_manager.can_turn_in(quest), "2 of 3 required kills")

	quest_manager.report_kill("bandit")
	assert_true(quest_manager.can_turn_in(quest), "3 of 3 required kills")


func test_progress_fraction_for_kill_quest():
	var quest := _make_kill_quest("bandit", 4)
	quest_manager.report_kill("bandit")

	assert_eq(quest_manager.get_progress_current(quest), 1)
	assert_eq(quest_manager.get_progress_target(quest), 4)
	assert_almost_eq(quest_manager.get_progress_fraction(quest), 0.25, 0.001)


func test_progress_current_is_clamped_and_pinned_once_completed():
	var quest := _make_kill_quest("bandit", 2)
	quest_manager.report_kill("bandit")
	quest_manager.report_kill("bandit")
	quest_manager.report_kill("bandit") # 3 kills, but the quest only needs 2

	assert_eq(quest_manager.get_progress_current(quest), 2, \
		"progress should clamp to the target, not overshoot")

	quest_manager.mark_completed(quest.id)
	assert_eq(quest_manager.get_progress_current(quest), 2, \
		"a completed quest should still read as fully done")


func test_turn_in_item_quest_consumes_items_and_grants_rewards():
	var required_item := _make_owned_item(2)
	var reward_item := ItemData.new()
	_test_items.append(reward_item)

	var quest := QuestData.new()
	quest.id = "test_item_quest"
	quest.required_item = required_item
	quest.required_amount = 2
	quest.reward_items = [reward_item]

	assert_true(quest_manager.can_turn_in(quest))

	watch_signals(quest_manager)
	quest_manager.turn_in(quest)

	assert_eq(InventoryManager.get_owned_quantity(required_item), 0, \
		"required items should be consumed")
	assert_eq(InventoryManager.get_owned_quantity(reward_item), 1, \
		"reward item should be granted")
	assert_true(quest_manager.is_completed(quest))
	assert_signal_emitted_with_parameters(quest_manager, "quest_completed", [quest.id])


func test_turn_in_does_nothing_if_requirements_are_not_met():
	var required_item := _make_owned_item(1)
	var quest := QuestData.new()
	quest.id = "test_underfunded_quest"
	quest.required_item = required_item
	quest.required_amount = 5

	quest_manager.turn_in(quest)

	assert_eq(InventoryManager.get_owned_quantity(required_item), 1, \
		"nothing should be consumed when the requirement isn't met")
	assert_false(quest_manager.is_completed(quest))


func test_mark_completed_is_idempotent():
	watch_signals(quest_manager)
	quest_manager.mark_completed("dup_quest")
	quest_manager.mark_completed("dup_quest")

	assert_signal_emit_count(quest_manager, "quest_completed", 1)

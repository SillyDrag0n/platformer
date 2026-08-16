extends Node

signal quest_received(quest : QuestData)
signal quest_completed(quest_id : String)

var completed_quest_ids : Array[String] = []
var enemy_kill_counts : Dictionary = {} # enemy_id (String) -> kill count (int)
var received_quests : Array[QuestData] = []


func is_received(quest : QuestData) -> bool:
	return quest != null and received_quests.has(quest)


# Used both by QuestNPC when a quest is first offered and by SaveManager when restoring a save -
# safe to call repeatedly since it's a no-op once the quest is already known.
func receive_quest(quest : QuestData) -> void:
	if quest == null or is_received(quest):
		return
	received_quests.append(quest)
	quest_received.emit(quest)


func is_completed(quest : QuestData) -> bool:
	return quest != null and completed_quest_ids.has(quest.id)


func can_turn_in(quest : QuestData) -> bool:
	if quest == null or is_completed(quest):
		return false
	if quest.required_enemy_id != "":
		return get_kill_count(quest.required_enemy_id) >= quest.required_kill_amount
	return InventoryManager.get_owned_quantity(quest.required_item) >= quest.required_amount


func get_progress_target(quest : QuestData) -> int:
	if quest.required_enemy_id != "":
		return quest.required_kill_amount
	return quest.required_amount


# Clamped to the target and pinned there once completed, since a turned-in quest's required
# items are gone from the inventory by then but the quest should still read as 100% done.
func get_progress_current(quest : QuestData) -> int:
	var target := get_progress_target(quest)
	if is_completed(quest):
		return target
	var current : int
	if quest.required_enemy_id != "":
		current = get_kill_count(quest.required_enemy_id)
	else:
		current = InventoryManager.get_owned_quantity(quest.required_item)
	return clampi(current, 0, target)


func get_progress_fraction(quest : QuestData) -> float:
	var target := get_progress_target(quest)
	if target <= 0:
		return 1.0
	return float(get_progress_current(quest)) / float(target)


func turn_in(quest : QuestData) -> void:
	if !can_turn_in(quest):
		return

	if quest.required_enemy_id == "":
		for i in range(quest.required_amount):
			InventoryManager.remove_item(quest.required_item)
	for reward in quest.reward_items:
		InventoryManager.add_item(reward)

	mark_completed(quest.id)


func report_kill(enemy_id : String) -> void:
	if enemy_id == "":
		return
	enemy_kill_counts[enemy_id] = get_kill_count(enemy_id) + 1


func get_kill_count(enemy_id : String) -> int:
	return enemy_kill_counts.get(enemy_id, 0)


# Used both by turn_in() above and by SaveManager when restoring a save - restoring must not
# redo the turn_in transaction (the reward/item removal is already reflected in the save).
func mark_completed(id : String) -> void:
	if completed_quest_ids.has(id):
		return
	completed_quest_ids.append(id)
	quest_completed.emit(id)

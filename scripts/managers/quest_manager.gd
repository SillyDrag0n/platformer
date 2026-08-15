extends Node

signal quest_completed(quest_id : String)

var completed_quest_ids : Array[String] = []


func is_completed(quest : QuestData) -> bool:
	return quest != null and completed_quest_ids.has(quest.id)


func can_turn_in(quest : QuestData) -> bool:
	if quest == null or is_completed(quest):
		return false
	return InventoryManager.get_owned_quantity(quest.required_item) >= quest.required_amount


func turn_in(quest : QuestData) -> void:
	if !can_turn_in(quest):
		return

	for i in range(quest.required_amount):
		InventoryManager.remove_item(quest.required_item)
	for reward in quest.reward_items:
		InventoryManager.add_item(reward)

	mark_completed(quest.id)


# Used both by turn_in() above and by SaveManager when restoring a save - restoring must not
# redo the turn_in transaction (the reward/item removal is already reflected in the save).
func mark_completed(id : String) -> void:
	if completed_quest_ids.has(id):
		return
	completed_quest_ids.append(id)
	quest_completed.emit(id)

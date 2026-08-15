class_name QuestNPC
extends NPC

@export var quest : QuestData
@export var speaker_name : String = ""

@onready var dialogue_box : DialogueBox = $DialogueBox


func _on_interact() -> void:
	if QuestManager.is_completed(quest):
		dialogue_box.show_dialogue(speaker_name, quest.complete_dialogue)
	elif QuestManager.can_turn_in(quest):
		QuestManager.turn_in(quest)
		dialogue_box.show_dialogue(speaker_name, quest.complete_dialogue)
	else:
		dialogue_box.show_dialogue(speaker_name, quest.offer_dialogue)

class_name QuestNPC
extends NPC

@export var quest : QuestData
@export var speaker_name : String = ""

@onready var dialogue_box : DialogueBox = $DialogueBox


func _ready() -> void:
	super._ready()
	dialogue_box.line_shown.connect(_on_dialogue_line_shown)


func _on_interact() -> void:
	if QuestManager.is_completed(quest):
		dialogue_box.show_dialogue(speaker_name, quest.complete_dialogue)
	elif QuestManager.can_turn_in(quest):
		QuestManager.turn_in(quest)
		dialogue_box.show_dialogue(speaker_name, quest.complete_dialogue)
	else:
		dialogue_box.show_dialogue(speaker_name, quest.offer_dialogue)


# The quest is granted on the second line of the offer dialogue rather than the first, so the
# deputy gets a beat to set up the situation before the ask lands. line_shown also fires while
# complete_dialogue is playing, but receive_quest() is a no-op once the quest is already known.
func _on_dialogue_line_shown(line_index : int) -> void:
	if line_index == 1:
		QuestManager.receive_quest(quest)

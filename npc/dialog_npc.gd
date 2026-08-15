class_name DialogNPC
extends NPC

@export var speaker_name : String = ""
@export var dialogue_lines : Array[String] = []

@onready var dialogue_box : DialogueBox = $DialogueBox


func _on_interact() -> void:
	dialogue_box.show_dialogue(speaker_name, dialogue_lines)

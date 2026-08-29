class_name BountyTurnInNPC
extends NPC

@export var speaker_name : String = ""
@export var dialogue_lines : Array[String] = []

@onready var dialogue_box : DialogueBox = $DialogueBox


func _ready() -> void:
	super._ready()
	dialogue_box.closed.connect(_on_dialogue_closed)


func _on_interact() -> void:
	dialogue_box.show_dialogue(speaker_name, dialogue_lines)


func _on_dialogue_closed() -> void:
	if GameStateManager.active_bounty == null:
		return
	GameStateManager.complete_active_bounty()
	GameStateManager.give_bounty_reward()
	UiManager.open_bounty_completed_screen()
	GameStateManager.clear_active_bounty()

class_name DialogNPC
extends NPC

@export var speaker_name : String = ""
@export var dialogue_lines : Array[String] = []

@export_category("Bounty Progress")
# Lines this conversation ticks off the bounty's checklist once it has been read to the end -
# see scripts/bounties/bounty_stage_data.gd. Left empty, this is a plain talking NPC.
@export var bounty_id : String = ""
@export var completes_objectives : Array[String] = []

@onready var dialogue_box : DialogueBox = $DialogueBox


func _ready() -> void:
	super._ready()
	if bounty_id != "" and not completes_objectives.is_empty():
		dialogue_box.closed.connect(_on_dialogue_closed)


func _on_dialogue_closed() -> void:
	for objective_id in completes_objectives:
		GameStateManager.complete_objective(bounty_id, objective_id)
	# Progress the player earned by riding out here shouldn't hang on them getting home again.
	SaveManager.save_game()


func _on_interact() -> void:
	dialogue_box.show_dialogue(speaker_name, dialogue_lines)


# The same conversation an interaction would start, but with lines handed in by whoever is staging
# the beat and without waiting to be talked to - for a forced conversation the player has no say
# in (see levels/farm_house_backyard/coyote_encounter.gd, where Hutch starts talking the moment
# the screen fades back in). Goes through this NPC's own box, so the line is credited to them.
func speak(lines : Array[String]) -> void:
	dialogue_box.show_dialogue(speaker_name, lines)

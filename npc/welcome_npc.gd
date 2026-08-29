class_name WelcomeNPC
extends NPC

@export var speaker_name : String = "Old Timer"
@export var dialogue_lines : Array[String] = []
@export var bounty_to_unlock_id : String = "tutorial_missing_cattle"
@export var greet_delay_seconds : float = 1.0

@onready var dialogue_box : DialogueBox = $DialogueBox
@onready var greet_timer : Timer = $GreetTimer

var _has_greeted := false


func _ready() -> void:
	super._ready()
	dialogue_box.closed.connect(_on_dialogue_closed)
	var already_unlocked := GameStateManager.is_bounty_unlocked(bounty_to_unlock_id)
	if not already_unlocked and not GameStateManager.has_shown_hub_welcome:
		greet_timer.start(greet_delay_seconds)


# A child Timer (freed automatically with this node) rather than get_tree().create_timer() -
# the latter is owned by the SceneTree itself, so leaving the hub (or a test freeing this node)
# before it fires leaked a dangling SceneTreeTimer instead of being cancelled.
func _on_greet_timer_timeout() -> void:
	if not _has_greeted:
		GameStateManager.has_shown_hub_welcome = true
		_greet()


func _on_interact() -> void:
	_greet()


func _greet() -> void:
	_has_greeted = true
	dialogue_box.show_dialogue(speaker_name, dialogue_lines)


func _on_dialogue_closed() -> void:
	if not GameStateManager.is_bounty_unlocked(bounty_to_unlock_id):
		GameStateManager.unlock_bounty(bounty_to_unlock_id)

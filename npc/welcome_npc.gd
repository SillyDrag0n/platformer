class_name WelcomeNPC
extends NPC

@export var speaker_name : String = "Old Timer"
@export var dialogue_lines : Array[String] = []
# Any bounty this NPC should put on the board when his dialogue closes. Missing Cattle no longer
# needs it - it is authored unlocked so the first job is always there to take - but the hook stays
# for an NPC who is genuinely the one handing a contract over.
@export var bounty_to_unlock_id : String = "missing_cattle"
@export var greet_delay_seconds : float = 1.0

@onready var dialogue_box : DialogueBox = $DialogueBox
@onready var greet_timer : Timer = $GreetTimer

var _has_greeted := false


func _ready() -> void:
	super._ready()
	dialogue_box.closed.connect(_on_dialogue_closed)
	# Gated on the story beat alone. It used to also require the bounty to still be locked, which
	# only worked while the Old Timer was the thing that put it on the board - now that Missing
	# Cattle ships unlocked, that condition would be false on the very first visit and he would
	# never say a word.
	if not GameStateManager.has_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN):
		greet_timer.start(greet_delay_seconds)


# A child Timer (freed automatically with this node) rather than get_tree().create_timer() -
# the latter is owned by the SceneTree itself, so leaving the hub (or a test freeing this node)
# before it fires leaked a dangling SceneTreeTimer instead of being cancelled.
func _on_greet_timer_timeout() -> void:
	if not _has_greeted:
		GameStateManager.set_story_flag(GameStateManager.FLAG_HUB_WELCOME_SHOWN)
		_greet()


func _on_interact() -> void:
	_greet()


func _greet() -> void:
	_has_greeted = true
	dialogue_box.show_dialogue(speaker_name, dialogue_lines)


func _on_dialogue_closed() -> void:
	if not GameStateManager.is_bounty_unlocked(bounty_to_unlock_id):
		GameStateManager.unlock_bounty(bounty_to_unlock_id)

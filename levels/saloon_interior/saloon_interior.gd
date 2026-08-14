extends Node2D

@onready var exit_door : Area2D = $ExitDoor


func _ready() -> void:
	exit_door.interact = _on_exit_interact


func _on_exit_interact():
	exit_door.is_interactable = false
	SceneManager.transition_to_scene("Hub")

class_name InteriorLevel
extends Node2D

# The inside of one of the hub's buildings - saloon, bank, arms dealer, post office, sheriff's
# office. They are all the same shape: a room with whoever works there in it, and a door back out
# to town. Only the room's contents differ, and those are authored in the scene, so the script is
# shared rather than copied per building.
#
# Deliberately not a Level: interiors have no respawn marker of their own, and claiming
# RespawnManager's wiring with a null marker would be worse than leaving the last real level's
# in place. It also leaves MusicManager alone, which is how the town's theme comes in through the
# door with the player - a Level with an empty music slot silences it instead.

@onready var exit_door : Area2D = $ExitDoor


func _ready() -> void:
	exit_door.interact = _on_exit_interact


func _on_exit_interact() -> void:
	# Latched off so a second interaction during the fade can't start the transition twice.
	exit_door.is_interactable = false
	SceneManager.transition_to_scene_faded("Hub")

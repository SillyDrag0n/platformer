extends Node2D

@onready var player : CharacterBody2D = $Player
@onready var camera : Camera2D = $PlayerCamera
@onready var respawn_marker : Marker2D = $RespawnPosition
@onready var exit_door : Area2D = $ExitDoor


func _ready() -> void:
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)
	exit_door.interact = _on_exit_interact


func set_player_instance(player_instance : CharacterBody2D) -> void:
	player = player_instance


func _on_exit_interact():
	exit_door.is_interactable = false
	SceneManager.transition_to_scene_faded("Hub")

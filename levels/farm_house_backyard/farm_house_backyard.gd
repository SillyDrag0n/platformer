extends Node2D

@onready var player : CharacterBody2D = $Player
@onready var camera : Camera2D = $PlayerCamera
@onready var respawn_marker : Marker2D = $RespawnPosition

func _ready() -> void:
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)

func set_player_instance(player_instance : CharacterBody2D) -> void:
	player = player_instance

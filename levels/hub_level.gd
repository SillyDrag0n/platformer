extends Node2D

@onready var player : CharacterBody2D = $Player


func _ready() -> void:
	if SceneManager.has_pending_spawn_position:
		player.global_position = SceneManager.consume_pending_spawn_position()

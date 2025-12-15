extends Node2D

@export var camera: Camera2D
@export var respawn_marker: Marker2D
@export var player: CharacterBody2D


func _ready():
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)


func setPlayerInstance(playerInstance: CharacterBody2D):
	player = playerInstance


func _on_death_zone_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		player.player_death()

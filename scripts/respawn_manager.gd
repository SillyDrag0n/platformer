extends Node

var player_scene = preload("res://player/player.tscn")
var camera: Camera2D
var respawn_marker: Marker2D

func set_respawn_nodes(cam: Camera2D, marker: Marker2D):
	camera = cam
	respawn_marker = marker

func Respawn():
	var player_instance = player_scene.instantiate()
	get_parent().add_child(player_instance)
	player_instance.global_position = respawn_marker.global_position
	HealthManager.set_health_max()
	camera.player = player_instance

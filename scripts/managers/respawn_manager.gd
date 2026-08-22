extends Node

var player_scene = preload("res://player/player.tscn")
var camera: Camera2D
var respawn_marker: Marker2D
var current_level: Node2D

func set_respawn_nodes(cam: Camera2D, marker: Marker2D, currLvl: Node2D):
	camera = cam
	respawn_marker = marker
	current_level = currLvl

func respawn():
	var player_instance = player_scene.instantiate()
	# add_child() runs the new player's _ready() synchronously, which emits
	# PlayerManager.player_spawned - HealthManager and the resource bar UI both already listen
	# for that to reset health and refresh the display, so nothing further is needed here.
	get_parent().add_child(player_instance)
	player_instance.global_position = respawn_marker.global_position
	camera.player = player_instance
	current_level.set_player_instance(player_instance)

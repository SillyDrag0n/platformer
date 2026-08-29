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
	# camera/respawn_marker/current_level are whichever level last called set_respawn_nodes() -
	# if that level has since been unloaded (left the hub and came back, a scene transition raced
	# with this call, etc.) without a newer call replacing them, these are stale references to
	# freed nodes. Degrading to "spawn without repositioning/rewiring" beats a hard crash that
	# leaves the player stuck on the death screen with no way to continue.
	if not is_instance_valid(respawn_marker) or not is_instance_valid(camera) or not is_instance_valid(current_level):
		push_warning("RespawnManager.respawn(): respawn_marker/camera/current_level is stale - " + \
			"whatever level should have called set_respawn_nodes() didn't, or was unloaded without a newer call replacing it.")

	var player_instance = player_scene.instantiate()
	# Parented under current_level (where the scene-authored player already lives), not this
	# autoload's own parent (the SceneTree root) - a sibling of the level rather than a child of
	# it left the level with no actual child node behind the player reference it just got handed.
	# Falls back to root only in the already-broken case where current_level itself is stale.
	var spawn_parent : Node = current_level if is_instance_valid(current_level) else get_parent()
	# add_child() runs the new player's _ready() synchronously, which emits
	# PlayerManager.player_spawned - HealthManager and the resource bar UI both already listen
	# for that to reset health and refresh the display, so nothing further is needed here.
	spawn_parent.add_child(player_instance)

	if is_instance_valid(respawn_marker):
		player_instance.global_position = respawn_marker.global_position
	if is_instance_valid(camera):
		camera.player = player_instance
	if is_instance_valid(current_level):
		current_level.set_player_instance(player_instance)

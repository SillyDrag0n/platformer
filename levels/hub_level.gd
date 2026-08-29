extends Node2D

@onready var player : CharacterBody2D = $Player
@onready var camera : Camera2D = $PlayerCamera
@onready var respawn_marker : Marker2D = $RespawnPosition


func _ready() -> void:
	# Without this, dying (or respawning) while RespawnManager's last-known respawn point still
	# belongs to whatever level was active before the hub - or, on a fresh boot, was never set at
	# all - crashes respawn() on a null respawn_marker the moment it tries to read its
	# global_position. Same wiring test_level.gd already does for itself.
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)

	if SceneManager.has_pending_spawn_position:
		player.global_position = SceneManager.consume_pending_spawn_position()


func set_player_instance(player_instance : CharacterBody2D) -> void:
	player = player_instance

extends Node2D

@export var camera: Camera2D
@export var respawn_marker: Marker2D

func _ready():
    RespawnManager.set_respawn_nodes(camera, respawn_marker)

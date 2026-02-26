extends Node

@export var world_map_scene: PackedScene

func open_world_map():
    get_tree().change_scene_to_packed(world_map_scene)
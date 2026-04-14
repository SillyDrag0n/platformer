extends Node

@export var world_map_scene: PackedScene
@export var bounty_completed_scene: PackedScene

func open_world_map():
    get_tree().change_scene_to_packed(world_map_scene)

func open_bounty_completed_screen():
    get_tree().change_scene_to_packed(bounty_completed_scene)
extends Node

@export var bounty_board_scene: PackedScene
@export var bounty_completed_scene: PackedScene

func open_bounty_board():
	get_tree().change_scene_to_packed(bounty_board_scene)

func open_bounty_completed_screen():
	get_tree().change_scene_to_packed(bounty_completed_scene)
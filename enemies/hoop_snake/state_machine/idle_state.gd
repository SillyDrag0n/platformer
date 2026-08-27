extends NodeState

@export var character_body_2d : CharacterBody2D


func enter():
	character_body_2d.velocity.x = 0.0


func exit():
	pass

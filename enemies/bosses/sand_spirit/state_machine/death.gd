extends NodeState

@export var boss: CharacterBody2D

func enter():
	boss.play_animation(boss.Animations.Death)
	boss.die()

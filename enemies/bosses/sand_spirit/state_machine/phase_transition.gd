extends NodeState

@export var Boss: CharacterBody2D

var done = false

func enter():
	done = false
	Boss.velocity = Vector2.ZERO
	Boss.play_animation("phase_change")

	await get_tree().create_timer(1.0).timeout
	done = true

func physics_update(_delta):

	if done:
		return "Ambush"

	return null
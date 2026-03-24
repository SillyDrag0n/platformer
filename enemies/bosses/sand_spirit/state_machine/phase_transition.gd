extends NodeState

@export var boss: BossStateController

var done = false

func enter():
	done = false
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.PhaseTransition)

	await get_tree().create_timer(1.0).timeout
	done = true

func physics_update(_delta):

	if done:
		return "Ambush"

	return null
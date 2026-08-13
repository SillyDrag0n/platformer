extends NodeState

@export var boss: BossStateController

func enter():
	boss.play_animation(boss.Animations.Death)
	boss.die()

extends NodeState

@export var boss: BossStateController

signal finished

var timer

func enter():
	boss.visible = false
	timer = 1.0
	boss.play_animation(boss.Animations.AmbushAttack)

func on_physics_process(delta):

	timer -= delta

	if timer <= 0:
		ambush()
		finished.emit()

func ambush():
	#TODO: implement ambush attack
	print("Ambush attack")
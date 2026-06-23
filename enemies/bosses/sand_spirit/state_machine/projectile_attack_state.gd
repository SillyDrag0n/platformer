extends NodeState

@export var boss: BossStateController

signal finished

func enter():
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.ProjectileAttack)
	shoot()
	finish_next_frame()
	
func shoot():
	#TODO: implement shoot attack
	pass

func finish_next_frame():
	await get_tree().process_frame
	finished.emit()

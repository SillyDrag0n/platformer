extends NodeState

@export var boss: BossStateController

signal finished

func enter():
	boss.velocity = Vector2.ZERO
	# TODO: Add increase when phase changes
	boss.play_animation(boss.Animations.DustDevilAttack)
	spawn_dust_devils(boss.phase)
	finish_next_frame()

func finish_next_frame():
	await get_tree().process_frame
	finished.emit()

func spawn_dust_devils(count):
	#TODO: implement dust devils attack
	print("Boss spawn dust devils ", count)

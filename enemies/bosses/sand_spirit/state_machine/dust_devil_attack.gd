extends NodeState

@export var Boss: CharacterBody2D

signal finished

func enter():
	Boss.velocity = Vector2.ZERO
	# TODO: Add increase when phase changes
	spawn_dust_devils(Boss.phase)
	finished.emit()

func spawn_dust_devils(count):
	#TODO: implement dust devils attack
	print("Boss spawn dust devils " + count)
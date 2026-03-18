extends NodeState

@export var Boss: CharacterBody2D

signal finished

var timer

func enter():
	Boss.visible = false
	timer = 1.0

func on_physics_process(delta):

	timer -= delta

	if timer <= 0:
		ambush()
		finished.emit()

func ambush():
	#TODO: implement ambush attack
	print("Ambush attack")
extends NodeState

@export var boss: CharacterBody2D

signal finished

var timer

func enter():
	timer = randf_range(1.0, 2.0) / boss.phase

func on_physics_process(delta):
	timer -= delta
	if timer <= 0:
		finished.emit()
extends NodeState

@export var boss: BossStateController

signal finished

var timer: float

func enter():
	timer = randf_range(1.0, 2.0) / boss.phase

func physics_update(delta):
	timer -= delta
	if timer <= 0:
		finished.emit()
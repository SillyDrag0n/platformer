extends NodeState

@export var Boss: CharacterBody2D

signal finished

func enter():
	Boss.velocity = Vector2.ZERO
	shoot()
	finished.emit()

func shoot():
	#TODO: implement shoot attack
	print("Boos Shoot Projectile")

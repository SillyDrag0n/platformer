extends NodeState

@export var Boss: CharacterBody2D

signal finished

func enter():
	Boss.velocity = Vector2.ZERO
	shoot()
	finish_next_frame()
	
func shoot():
	#TODO: implement shoot attack
	print("Boos Shoot Projectile")

func finish_next_frame():
	await get_tree().process_frame
	finished.emit()
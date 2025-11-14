extends Node

var bullet = preload("res://player/bullet.tscn")
#TODO: remove variable "move_x_direction" -> probably redundant if shoot at mouse position is implemented

func createBullet(direction, global_position, move_x_direction = true):
	var bullet_instance = bullet.instantiate() as Node2D
	bullet_instance.direction = direction
	bullet_instance.move_x_direction = true
	bullet_instance.global_position = global_position
	get_parent().add_child(bullet_instance)
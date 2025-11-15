extends Node

var bullet = preload("res://player/bullet.tscn")

func createBullet(direction : Vector2, global_position, move_x_direction = true):
	var bullet_instance = bullet.instantiate() as Node2D
	bullet_instance.direction = direction
	bullet_instance.rotation = direction.angle()
	bullet_instance.global_position = global_position
	get_parent().add_child(bullet_instance)

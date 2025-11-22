extends NodeState

var bullet = preload("res://player/gun/bullet/bullet.tscn")

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var gun : Node2D

var muzzle_position : Vector2

func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	if GameInputEvents.shoot_input():
		gun.try_shoot()
	
	# run state
	var direction : float = GameInputEvents.movement_input()
	
	if direction and character_body_2d.is_on_floor():
		transition.emit("Run")
	
	# jump state
	if GameInputEvents.jump_input():
		transition.emit("Jump")


func enter():
	animated_sprite_2d.play("shoot_crouch")


func exit():
	animated_sprite_2d.stop()
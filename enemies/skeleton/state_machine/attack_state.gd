extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D


func enter():
	animated_sprite_2d.play("attack")
	character_body_2d.set_chase(false)
	character_body_2d.shoot_enabled = true


func exit():
	animated_sprite_2d.stop()
	character_body_2d.shoot_enabled = false

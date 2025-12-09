extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D
@export var chase_timer: Timer


func enter():
	animated_sprite_2d.play("chase")
	chase_timer.start()
	character_body_2d.set_chase(true)


func exit():
	animated_sprite_2d.stop()
	character_body_2d.set_chase(false)

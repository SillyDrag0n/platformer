extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D
	
	
func enter():
	animated_sprite_2d.play("idle")
	character_body_2d.set_chase(false)


func exit():
	animated_sprite_2d.stop()

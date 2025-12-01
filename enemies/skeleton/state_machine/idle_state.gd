extends NodeState

@export var animated_sprite_2d: AnimatedSprite2D
	
	
func enter():
	animated_sprite_2d.play("idle")


func exit():
	animated_sprite_2d.stop()


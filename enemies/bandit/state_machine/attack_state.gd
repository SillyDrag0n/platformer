extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D

# Brief pause on the "popped up and aiming" pose before the shot actually fires, so the player
# gets a readable beat to react before ducking back down to reload.
const AIM_DURATION : float = 0.5

var timer : float
var has_fired : bool


func enter():
	animated_sprite_2d.play("attack")
	character_body_2d.set_chase(false)
	timer = AIM_DURATION
	has_fired = false


func physics_update(delta):
	timer -= delta
	if timer <= 0 and not has_fired:
		has_fired = true
		character_body_2d.shoot()
		return "Reload"
	return null


func exit():
	animated_sprite_2d.stop()

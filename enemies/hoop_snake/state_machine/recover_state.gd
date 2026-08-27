extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var friction : float = 600.0

var pause_timer : float = 0.0
var is_stopped : bool = false


func enter():
	is_stopped = false
	pause_timer = character_body_2d.recover_pause


func physics_update(delta):
	if not is_stopped:
		character_body_2d.velocity.x = move_toward(character_body_2d.velocity.x, 0.0, friction * delta)
		animated_sprite_2d.rotation += (character_body_2d.velocity.x / character_body_2d.visual_radius) * delta
		if character_body_2d.velocity.x == 0.0:
			is_stopped = true
		return null

	pause_timer -= delta
	if pause_timer <= 0.0:
		return "Roll" if PlayerManager.player != null else "Idle"
	return null


func exit():
	pass

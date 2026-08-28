extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var friction : float = 600.0

# A roll that ends because the player jumped clean over it (has_overshot_player()) means the snake
# is already facing the wrong way with nothing blocking it - it should spin back around and chase
# again almost immediately, not sit through the same long pause a roll that dead-ended at a wall
# or ledge needs before re-aiming.
@export var overshoot_pause_scale : float = 0.3

var pause_timer : float = 0.0
var is_stopped : bool = false


func enter():
	is_stopped = false
	var pause : float = character_body_2d.recover_pause
	if character_body_2d.has_overshot_player():
		pause *= overshoot_pause_scale
	pause_timer = pause


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

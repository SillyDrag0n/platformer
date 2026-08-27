extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D

# Safety net (has_overshot_player() below is what normally ends a roll once it passes the player)
# so the snake always eventually coasts to a stop even with no player, wall, or ledge to trigger
# Recover on its own.
@export var max_roll_duration : float = 2.0

var roll_timer : float = 0.0


func enter():
	character_body_2d.roll_direction = character_body_2d.get_player_direction()
	character_body_2d.velocity.x = character_body_2d.roll_direction * character_body_2d.roll_speed
	roll_timer = max_roll_duration


func physics_update(delta):
	character_body_2d.velocity.x = character_body_2d.roll_direction * character_body_2d.roll_speed
	animated_sprite_2d.rotation += (character_body_2d.velocity.x / character_body_2d.visual_radius) * delta

	roll_timer -= delta
	if roll_timer <= 0.0:
		return "Recover"
	if character_body_2d.has_overshot_player():
		return "Recover"
	if character_body_2d.is_on_wall() or not character_body_2d.is_ground_ahead(character_body_2d.roll_direction):
		return "Recover"
	return null


func exit():
	pass

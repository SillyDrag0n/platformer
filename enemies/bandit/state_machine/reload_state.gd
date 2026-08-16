extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D
@export var hurtbox_collision_shape: CollisionShape2D

const RELOAD_DURATION : float = 2.0

# No dedicated crouch art yet - squash, drop, and darken the idle pose to read as "taking
# cover" until there's a real duck animation to swap in.
const DUCK_SCALE_Y : float = 0.6
const DUCK_OFFSET_Y : float = 13.0
const DUCK_MODULATE : Color = Color(0.6, 0.6, 0.6)

var timer : float


func enter():
	animated_sprite_2d.play("idle")
	animated_sprite_2d.scale.y = DUCK_SCALE_Y
	animated_sprite_2d.position.y += DUCK_OFFSET_Y
	animated_sprite_2d.modulate = DUCK_MODULATE
	# Shrink the hurtbox to match the squashed pose, otherwise the bandit still gets hit
	# as if standing tall while it visibly ducks.
	hurtbox_collision_shape.scale.y = DUCK_SCALE_Y
	hurtbox_collision_shape.position.y += DUCK_OFFSET_Y
	character_body_2d.set_chase(false)
	timer = RELOAD_DURATION


func physics_update(delta):
	timer -= delta
	if timer <= 0:
		return "Attack"
	return null


func exit():
	animated_sprite_2d.stop()
	animated_sprite_2d.scale.y = 1.0
	animated_sprite_2d.position.y -= DUCK_OFFSET_Y
	animated_sprite_2d.modulate = Color.WHITE
	hurtbox_collision_shape.scale.y = 1.0
	hurtbox_collision_shape.position.y -= DUCK_OFFSET_Y

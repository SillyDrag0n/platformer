extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D
@export var hurtbox_collision_shape: CollisionShape2D
@export var collision_shape: CollisionShape2D

const RELOAD_DURATION : float = 2.0

# No dedicated crouch art yet - squash, drop, and darken the idle pose to read as "taking
# cover" until there's a real duck animation to swap in.
const DUCK_SCALE_Y : float = 0.6
const DUCK_OFFSET_Y : float = 13.0
const DUCK_MODULATE : Color = Color(0.6, 0.6, 0.6)

var timer : float

# CapsuleShape2D silently ignores non-uniform node scaling (Godot only supports uniform scale on
# capsule/circle shapes), so scaling hurtbox_collision_shape.scale.y alone - the previous approach
# here - never actually shrank the hitbox despite the visible squash. Shrinking the shape
# resource's own height instead works regardless of shape type. Duplicated in _ready() so this
# bandit's duck doesn't shrink every other bandit sharing the same inline sub-resource.
var _hurtbox_shape : CapsuleShape2D
var _hurtbox_full_height : float

# The body capsule gets the same treatment as the hurtbox, and for the same two reasons: a
# non-uniform node scale would be silently ignored on a capsule, and the shape is an inline
# sub-resource every bandit in the level shares until it's duplicated per instance. Its rest
# position is kept as well, since the duck offsets it (see enter()).
var _body_shape : CapsuleShape2D
var _body_full_height : float
var _body_rest_position : Vector2


func _ready() -> void:
	_hurtbox_shape = hurtbox_collision_shape.shape.duplicate()
	hurtbox_collision_shape.shape = _hurtbox_shape
	_hurtbox_full_height = _hurtbox_shape.height

	_body_shape = collision_shape.shape.duplicate()
	collision_shape.shape = _body_shape
	_body_full_height = _body_shape.height
	_body_rest_position = collision_shape.position


func enter():
	animated_sprite_2d.play("idle")
	animated_sprite_2d.scale.y = DUCK_SCALE_Y
	animated_sprite_2d.position.y += DUCK_OFFSET_Y
	animated_sprite_2d.modulate = DUCK_MODULATE
	# Shrink the hurtbox to match the squashed pose, otherwise the bandit still gets hit
	# as if standing tall while it visibly ducks.
	_hurtbox_shape.height = _hurtbox_full_height * DUCK_SCALE_Y
	hurtbox_collision_shape.position.y += DUCK_OFFSET_Y
	# The body capsule ducks too, otherwise he still takes up standing room while visibly crouched -
	# the player can't clear him with a jump he ought to. Shrunk from the top only, with the bottom
	# edge left where it was so his feet stay on the ground rather than the whole body dropping,
	# which is the same trick the player's own crouch uses (lower_body_controller.gd's
	# apply_crouch_collision()).
	var ducked_height : float = _body_full_height * DUCK_SCALE_Y
	_body_shape.height = ducked_height
	collision_shape.position = _body_rest_position \
		+ Vector2(0.0, (_body_full_height - ducked_height) * 0.5)
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
	_hurtbox_shape.height = _hurtbox_full_height
	hurtbox_collision_shape.position.y -= DUCK_OFFSET_Y
	_body_shape.height = _body_full_height
	collision_shape.position = _body_rest_position

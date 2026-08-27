extends NodeState

@export var character_body_2d : CharacterBody2D
@export var collision_shape : CollisionShape2D


# Collision has to be switched off while attached, not just the position pinned - otherwise the
# snake's own solid body and the player's are still overlapping every frame, and the Gravity
# node's move_and_slide() (which still runs right after this) shoves them apart again the instant
# they're pinned together, reading as constant jitter/glitching on both the snake and the player.
# set_deferred() avoids "flushing queries" errors from toggling a shape's disabled state from
# inside a physics/area callback (enter() here is reached from attach_to_player(), itself called
# from the PlayerDetector area's body_entered signal).
func enter():
	character_body_2d.velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)


# Pinned directly to the player's position rather than left to physics/move_and_slide, since the
# player can be moving, falling, or landing while the snake is latched on - it just needs to follow,
# not collide. Re-zeroing velocity every frame (rather than once in enter()) keeps the Gravity
# node's own move_and_slide() call later this frame from nudging the pinned position by whatever
# gravity it accumulates in the meantime.
func physics_update(_delta):
	if character_body_2d.attached_player == null or not is_instance_valid(character_body_2d.attached_player):
		return "Recover"
	character_body_2d.velocity = Vector2.ZERO
	character_body_2d.global_position = character_body_2d.attached_player.global_position + character_body_2d.follow_offset
	return null


func exit():
	collision_shape.set_deferred("disabled", false)

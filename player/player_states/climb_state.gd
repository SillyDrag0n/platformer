extends NodeState

# On a ladder. Gravity is off, the player is held to the ladder's centre line, and up/down walks
# them along it - the same climb_up/force_fall axis that lets out and takes in the grapple rope
# (see grapple_state.gd), so "up and down move you along whatever you are hanging from" means one
# thing everywhere.
#
# Aiming and shooting are deliberately left alone: the upper body is its own controller driving the
# arms and head by IK, so a player on a ladder can still cover the room below them without this
# state having to allow it.

@export var character_body_2d : CharacterBody2D

@export_category("Climb")
@export var climb_speed : float = 130.0
# Stepping off sideways. Enough to clear the rails and land on a ledge beside them, not enough to
# read as a jump.
@export var step_off_speed : float = 140.0
@export var step_off_lift : float = -110.0
# Letting go with jump. Smaller than a standing jump (normal_state's -375): the player is pushing
# off a rung, not off the ground.
@export var release_jump_speed : float = -300.0

# How far the player's origin sits above their feet - the capsule in player.tscn is 66 tall, so
# 33. Climbing positions feet, since that is what has to end up level with the floor at the top.
const FEET_OFFSET : float = 33.0

# Mirrors normal_state.gd's own constant: the layer it toggles while rising, and the layer a ladder
# is nearly always threaded through.
const ONE_WAY_PLATFORM_LAYER : int = 8

var ladder : Ladder


func on_process(_delta : float):
	pass


func on_physics_process(delta : float):
	if not is_instance_valid(ladder):
		transition.emit("Normal")
		return

	# Held to the rungs. No gravity and no horizontal drift: a ladder is the one place in this game
	# where the player is not falling and not being carried anywhere.
	character_body_2d.velocity = Vector2(0.0, GameInputEvents.climb_input() * -climb_speed)
	character_body_2d.global_position.x = ladder.global_position.x

	character_body_2d.move_and_slide()
	_clamp_to_ladder()

	# Jump lets go, pushing off the rung.
	if GameInputEvents.jump_input():
		character_body_2d.velocity.y = release_jump_speed
		transition.emit("Normal")
		return

	# A direction steps off sideways - the way off at the top, and the way to bail out anywhere
	# else. Checked after the climb above so a frame holding both still climbs rather than
	# jittering between the two.
	var direction : float = GameInputEvents.movement_input()
	if direction != 0.0:
		character_body_2d.velocity = Vector2(direction * step_off_speed, step_off_lift)
		transition.emit("Normal")
		return

	# Climbed off the bottom onto the ground.
	if character_body_2d.is_on_floor() and GameInputEvents.climb_input() < 0.0:
		transition.emit("Normal")


# The rungs run out at both ends. Feet may reach the top rung - which is level with the floor the
# ladder serves, so that is the position the player steps off from - and no further, and may not go
# below the bottom one.
func _clamp_to_ladder() -> void:
	var feet : float = character_body_2d.global_position.y + FEET_OFFSET
	var clamped : float = clampf(feet, ladder.top_y(), ladder.bottom_y())
	if not is_equal_approx(clamped, feet):
		character_body_2d.global_position.y = clamped - FEET_OFFSET
		character_body_2d.velocity.y = 0.0


func enter():
	ladder = Ladder.at_body(character_body_2d)
	if not is_instance_valid(ladder):
		return
	character_body_2d.velocity = Vector2.ZERO
	# One-way platforms are what a ladder usually runs through, and while climbing the player has
	# to pass both ways through them - normal_state re-enables that mask as soon as it has them
	# back (see its own note on why it is toggled at all).
	character_body_2d.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)


func exit():
	ladder = null
	character_body_2d.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)

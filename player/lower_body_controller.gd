extends Node

# Everything below the hip: which AnimationPlayer clip is playing and which way the legs face.
# The upper body (arms/head aiming at the mouse/stick) is driven independently by
# upper_body_controller.gd, since aim direction can't be baked into a keyframed clip the way a
# walk cycle can.

@export var character_body_2d : CharacterBody2D
@export var state_machine : NodeFiniteStateMachine
@export var animation_player : AnimationPlayer
@export var leg_targets : Node2D

@export_category("Walk Cycle")
@export var walk_speed_reference : float = 300.0
@export var min_walk_speed_scale : float = 0.5

@export_category("Dash")
@export var dash_speed_scale : float = 1.8

var facing : float = 1.0


func _physics_process(_delta : float) -> void:
	update_facing()

	var state_name : String = state_machine.current_node_state.name.to_lower()
	match state_name:
		"dead":
			# Plays once (non-looping clip) and then holds its final frame - play_clip()'s
			# current_animation guard means this only actually triggers .play() on the first frame
			# of the state, so the collapse isn't restarted every subsequent frame.
			play_clip("death", 1.0)
		"hurt":
			# No dedicated hurt pose yet - reuse idle, same placeholder convention the old
			# animation_controller.gd used before the skeleton rig existed.
			play_clip("idle", 1.0)
		"grapple":
			# No dedicated swinging pose yet - reuse fall, same convention as before.
			play_clip("fall", 1.0)
		"dash":
			# No dedicated dash pose yet - reuse walk at a faster cycle, same convention as before.
			play_clip("walk", dash_speed_scale)
		_:
			play_normal_clip()


func play_normal_clip() -> void:
	var direction : float = GameInputEvents.movement_input()
	var grounded : bool = character_body_2d.is_on_floor()
	var crouching : bool = grounded and GameInputEvents.crouch_input() and direction == 0.0

	if not grounded and character_body_2d.velocity.y < 0.0:
		play_clip("jump", 1.0)
	elif not grounded:
		play_clip("fall", 1.0)
	elif crouching:
		play_clip("crouch", 1.0)
	elif direction != 0.0:
		var speed_ratio : float = clampf(absf(character_body_2d.velocity.x) / walk_speed_reference, min_walk_speed_scale, 1.0)
		play_clip("walk", speed_ratio)
	else:
		play_clip("idle", 1.0)


func play_clip(clip_name : String, speed_scale : float) -> void:
	if animation_player.current_animation != clip_name:
		animation_player.play(clip_name)
	animation_player.speed_scale = speed_scale


# Legs mirror to face whichever way the character is actually moving. Falls back to velocity
# when there's no held input (e.g. during Dash, where movement is locked to dash_direction) and
# holds the last facing at a full stop, rather than snapping back to a default.
func update_facing() -> void:
	var direction : float = GameInputEvents.movement_input()
	if direction == 0.0 and absf(character_body_2d.velocity.x) > 1.0:
		direction = signf(character_body_2d.velocity.x)
	if direction != 0.0:
		facing = signf(direction)
	leg_targets.scale.x = facing

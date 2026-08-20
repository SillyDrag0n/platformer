extends Node

@export var legs : AnimatedSprite2D
@export var upper_body : AnimatedSprite2D
@export var character_body_2d : CharacterBody2D
@export var state_machine : NodeFiniteStateMachine
@export var player : Node


func _physics_process(_delta : float) -> void:
	# Dash/Grapple/Hurt/Dead drive Legs themselves from their own enter() - this controller only
	# owns movement animation while the gameplay state is Normal, so the two never fight over it.
	if state_machine.current_node_state.name.to_lower() != "normal":
		return

	var direction : float = GameInputEvents.movement_input()
	var grounded : bool = character_body_2d.is_on_floor()
	var crouching : bool = grounded and GameInputEvents.crouch_input() and direction == 0.0

	var legs_animation : String
	if not grounded and character_body_2d.velocity.y < 0.0:
		legs_animation = "jump"
	elif not grounded:
		legs_animation = "fall"
	elif crouching:
		# No dedicated non-shooting crouch art exists yet - reuse shoot_crouch as the closest
		# available pose, same placeholder convention used elsewhere in this refactor.
		legs_animation = "shoot_crouch"
	elif direction != 0.0:
		legs_animation = "run"
	else:
		legs_animation = "idle"

	if legs.animation != legs_animation:
		legs.play(legs_animation)
	if direction != 0.0:
		legs.flip_h = direction < 0.0

	# UpperBody mirrors Legs' pose so the two composited full-body frames overlap and read as one
	# sprite, except while actually shooting, where it shows the one generic recoil pose instead -
	# this is the expected source of the "double exposure while shooting" artifact until legs and
	# upper body are split into real separate art.
	var upper_body_animation : String = "shoot_stand" if player.is_shooting else legs_animation
	if upper_body.animation != upper_body_animation:
		upper_body.play(upper_body_animation)

	var aim_dir : Vector2 = GameInputEvents.aim_input(upper_body.global_position)
	upper_body.rotation = aim_dir.angle()
	upper_body.flip_v = aim_dir.x < 0.0

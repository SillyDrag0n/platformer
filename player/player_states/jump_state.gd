extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var grapple_hook : Node2D

@export_category("Jump State")
@export var jump_height :  float = -350
@export var jump_horizontal_speed : int = 200
@export var max_jump_horizontal_speed : int = 200
@export var max_jump_count : int = 1
@export var jump_gravity : int = 1000
@export var air_deceleration : float = 1800

const ONE_WAY_PLATFORM_LAYER : int = 8

var current_jump_count : int
var coyote_jump : bool

var footstep_dust_effect = preload("res://player/effects/footstep_dust_effect.tscn")

func on_process(delta : float):
	pass


func on_physics_process(delta : float):

	character_body_2d.velocity.y += jump_gravity * delta

	# only treat this as a landing if we're not still actively rising - a one-way platform
	# grazed from below while ascending can briefly report is_on_floor() at the corner, which
	# would otherwise re-trigger the launch below and cause a visible stick/hitch
	if character_body_2d.is_on_floor() and character_body_2d.velocity.y >= 0.0:
		current_jump_count = 0
		character_body_2d.velocity.y = jump_height
		coyote_jump = false
		current_jump_count += 1
	
	if coyote_jump:
		character_body_2d.velocity.y = jump_height
		coyote_jump = false
		current_jump_count += 1
	
	# multiple jumps
	if !character_body_2d.is_on_floor() and GameInputEvents.jump_input() and current_jump_count != max_jump_count:
		character_body_2d.velocity.y = jump_height
		current_jump_count += 1
	
	var direction : float = GameInputEvents.movement_input()
	
	if !character_body_2d.is_on_floor():
		if direction != 0:
			animated_sprite_2d.flip_h = false if direction > 0 else true
			character_body_2d.velocity.x += direction * jump_horizontal_speed
			character_body_2d.velocity.x = clamp(character_body_2d.velocity.x, -max_jump_horizontal_speed, max_jump_horizontal_speed)
		else:
			character_body_2d.velocity.x = move_toward(character_body_2d.velocity.x, 0, air_deceleration * delta)

	# ignore one-way platforms entirely while still rising, so a jump that doesn't quite clear
	# one can never get caught straddling its underside. Re-enable once we're no longer
	# ascending so landing on top still works normally on the way down. Evaluated last so it
	# reflects this frame's final velocity, including any (re)launch above.
	character_body_2d.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, character_body_2d.velocity.y >= 0.0)

	character_body_2d.move_and_slide()

	# transitioning states

	# idle state (ignore a spurious floor read while still rising into a platform's underside)
	if character_body_2d.is_on_floor() and character_body_2d.velocity.y >= 0.0:
		spawn_dust()
		transition.emit("Idle")

	# grapple state
	if GameInputEvents.grapple_input() and grapple_hook.find_anchor(character_body_2d.global_position) != null:
		transition.emit("Grapple")

func enter():
	coyote_jump = true
	animated_sprite_2d.play("jump")
	spawn_dust()


func exit():
	coyote_jump = false
	animated_sprite_2d.stop()
	character_body_2d.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)


func spawn_dust():
	var dust = footstep_dust_effect.instantiate() as Node2D
	dust.global_position = character_body_2d.global_position
	character_body_2d.get_parent().add_child(dust)

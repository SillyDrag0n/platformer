extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var grapple_hook : Node2D

@export_category("Run State")
@export var speed : int = 700
@export var max_horizontal_speed: int = 250

const GRAVITY : int = 1000
const FOOTSTEP_INTERVAL := 0.22

var footstep_dust_effect = preload("res://player/effects/footstep_dust_effect.tscn")
var footstep_timer: float

func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	var direction : float = GameInputEvents.movement_input()

	if direction:
		character_body_2d.velocity.x += direction * speed
		character_body_2d.velocity.x = clamp(character_body_2d.velocity.x, -max_horizontal_speed, max_horizontal_speed)

	if direction != 0:
		animated_sprite_2d.flip_h = false if direction > 0 else true

	character_body_2d.velocity.y += GRAVITY * delta

	character_body_2d.move_and_slide()

	footstep_timer -= delta
	if footstep_timer <= 0:
		footstep_timer = FOOTSTEP_INTERVAL
		spawn_footstep_dust()

	# transitioning states
	
	# idle state
	if direction == 0:
		transition.emit("Idle")
	
	# jump state
	if GameInputEvents.jump_input():
		transition.emit("Jump")
	
	#shoot run state
	if direction != 0 and GameInputEvents.shoot_input():
		transition.emit("ShootRun")
	
		# fall state
	if !character_body_2d.is_on_floor():
		transition.emit("Fall")

	# grapple state
	if AbilityManager.is_unlocked("grapple_hook") and GameInputEvents.grapple_input() and grapple_hook.find_anchor(character_body_2d.global_position) != null:
		transition.emit("Grapple")


func enter():
	animated_sprite_2d.play("run")
	footstep_timer = FOOTSTEP_INTERVAL


func exit():
	animated_sprite_2d.stop()


func spawn_footstep_dust():
	var dust = footstep_dust_effect.instantiate() as Node2D
	dust.global_position = character_body_2d.global_position
	character_body_2d.get_parent().add_child(dust)

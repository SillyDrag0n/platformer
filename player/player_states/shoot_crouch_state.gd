extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var gun : Node2D

func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	if GameInputEvents.shoot_input():
		gun.try_shoot()
	
	# run state
	var direction : float = GameInputEvents.movement_input()
	
	if direction and character_body_2d.is_on_floor():
		transition.emit("Run")
	
	# jump state
	if GameInputEvents.jump_input():
		transition.emit("Jump")
	
	# fall state
	if !character_body_2d.is_on_floor():
		transition.emit("Fall")
	
	# idle state (toggle crouch off)
	if GameInputEvents.crouch_input():
		transition.emit("Idle")


func enter():
	animated_sprite_2d.play("shoot_crouch")


func exit():
	animated_sprite_2d.stop()
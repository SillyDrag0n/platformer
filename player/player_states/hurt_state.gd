extends NodeState

@export var character_body_2d : CharacterBody2D

@export_category("Hurt State")
@export var hurt_duration : float = 0.3
@export var gravity : int = 900

var hurt_timer : float = 0.0


func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	hurt_timer -= delta

	if not character_body_2d.is_on_floor():
		character_body_2d.velocity.y += gravity * delta

	character_body_2d.move_and_slide()

	if hurt_timer <= 0.0:
		transition.emit("Normal")


func enter():
	hurt_timer = hurt_duration


func exit():
	pass

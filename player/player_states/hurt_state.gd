extends NodeState

@export var character_body_2d : CharacterBody2D
@export var legs : AnimatedSprite2D

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
	# No dedicated hurt pose exists yet - reuse idle as a placeholder, same convention Dash/Grapple
	# already use for their own missing art (dash reuses "run", grapple reuses "fall").
	legs.play("idle")


func exit():
	legs.stop()

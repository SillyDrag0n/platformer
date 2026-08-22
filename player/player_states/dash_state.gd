extends NodeState

@export var character_body_2d : CharacterBody2D
@export var player : Node

@export_category("Dash State")
@export var dash_speed : float = 900.0
@export var dash_duration : float = 0.18
@export var dash_cooldown : float = 0.8

var dash_direction : Vector2
var dash_timer : float
var cooldown_remaining : float = 0.0


# Runs every frame regardless of which FSM state is active (unlike on_process/on_physics_process,
# which the FSM only calls for the current state), since this node always exists as a permanent
# child of StateMachine - that's what lets the cooldown count down while dashing isn't active.
func _process(delta : float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta


func can_dash() -> bool:
	return cooldown_remaining <= 0.0


func on_physics_process(delta : float):
	dash_timer -= delta
	character_body_2d.velocity = dash_direction * dash_speed
	character_body_2d.move_and_slide()

	if dash_timer <= 0.0:
		transition.emit("Normal")


func enter():
	var direction : float = GameInputEvents.movement_input()
	if direction == 0.0:
		direction = last_facing()

	dash_direction = Vector2(direction, 0.0)
	dash_timer = dash_duration
	cooldown_remaining = dash_cooldown

	player.set_invulnerable(true)


func exit():
	player.set_invulnerable(false)


# Pose selection for Dash lives in lower_body_controller.gd (which plays the walk cycle faster
# while this state is active) - this only needs a facing to dash toward when there's no held
# movement input, so it falls back to whichever way the character last actually faced.
func last_facing() -> float:
	return sign(character_body_2d.velocity.x) if character_body_2d.velocity.x != 0.0 else 1.0

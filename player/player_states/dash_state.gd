extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
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
		transition.emit("Fall")


func enter():
	var direction : float = GameInputEvents.movement_input()
	if direction == 0.0:
		direction = -1.0 if animated_sprite_2d.flip_h else 1.0

	dash_direction = Vector2(direction, 0.0)
	dash_timer = dash_duration
	cooldown_remaining = dash_cooldown

	player.set_invulnerable(true)
	# No dedicated dash sprite exists yet - reuse the run animation as a placeholder.
	animated_sprite_2d.play("run")


func exit():
	player.set_invulnerable(false)
	animated_sprite_2d.stop()

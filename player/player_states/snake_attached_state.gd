extends NodeState

@export var character_body_2d : CharacterBody2D
@export var player : Node

@export_category("Snake Attached")
@export var crawl_speed : float = 40.0
@export var gravity : int = 900
@export var jump_presses_required : int = 6

# Set by player.attach_snake() right before transitioning into this state.
var snake : Node2D = null
var press_count : int = 0


func on_process(_delta : float):
	pass


func on_physics_process(delta : float):
	if snake == null or not is_instance_valid(snake):
		transition.emit("Normal")
		return

	if not character_body_2d.is_on_floor():
		character_body_2d.velocity.y += gravity * delta

	var direction : float = GameInputEvents.movement_input()
	character_body_2d.velocity.x = direction * crawl_speed
	character_body_2d.move_and_slide()

	# Jump is repurposed here as the "shake it off" struggle input rather than an actual jump -
	# spamming it is how the player fights the snake off their legs.
	if GameInputEvents.jump_input():
		press_count += 1
		if press_count >= jump_presses_required:
			var freed_snake := snake
			snake = null
			freed_snake.detach()
			transition.emit("Normal")


func enter():
	press_count = 0


func exit():
	snake = null

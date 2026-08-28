extends NodeState

@export var character_body_2d : CharacterBody2D
@export var player : Node

@export_category("Snake Attached")
@export var crawl_speed : float = 40.0
@export var gravity : int = 900
@export var jump_presses_required : int = 6
@export var bite_interval : float = 2.0 # how often the snake bites while attached

# Set by player.attach_snake() right before transitioning into this state.
var snake : Node2D = null
var press_count : int = 0
var bite_timer : float = 0.0


func on_process(_delta : float):
	pass


func on_physics_process(delta : float):
	if snake == null or not is_instance_valid(snake):
		transition.emit("Normal")
		return

	if not character_body_2d.is_on_floor():
		character_body_2d.velocity.y += gravity * delta

	bite_timer += delta
	if bite_timer >= bite_interval:
		bite_timer -= bite_interval
		player.apply_snake_bite(snake.damage_amount)
		# A lethal bite transitions the player state machine to "Dead" synchronously, which calls
		# this state's exit() (nulling snake) before control returns here - bail out rather than
		# keep acting as if still attached.
		if snake == null:
			return

	var direction : float = GameInputEvents.movement_input()
	character_body_2d.velocity.x = direction * crawl_speed
	character_body_2d.move_and_slide()

	# Jump is repurposed here as the "shake it off" struggle input rather than an actual jump -
	# spamming it is how the player fights the snake off their legs.
	if GameInputEvents.jump_input():
		press_count += 1
		PlayerManager.snake_grab_progress.emit(press_count, jump_presses_required)
		if press_count >= jump_presses_required:
			var freed_snake := snake
			snake = null
			freed_snake.detach()
			transition.emit("Normal")


func enter():
	press_count = 0
	bite_timer = 0.0
	PlayerManager.snake_grab_started.emit(jump_presses_required)


func exit():
	snake = null
	PlayerManager.snake_grab_ended.emit()

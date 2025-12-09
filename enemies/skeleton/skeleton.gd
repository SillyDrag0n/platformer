extends CharacterBody2D

const SPEED = 100.0
@export var is_chasing: bool = false

func _physics_process(delta: float) -> void:
	chase_player(delta)

func chase_player(delta):
	if is_chasing == true:
		print("Chase started")
		var player_global_position = GameManager.get_global_player_position()
		var direction = (player_global_position - global_position).normalized()
		velocity.x = direction.x * SPEED

	if is_chasing == false:
		print("Chase stopped")
		velocity.x = 0
	
	move_and_slide()
	

func set_chase(should_chase: bool):
	is_chasing = should_chase

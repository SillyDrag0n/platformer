extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var HEALTH_TOTAL : float = 20
var HEALTH_CURRENT : float = 20
@export var DAMAGE_BASE : float = 5

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	move_and_slide()

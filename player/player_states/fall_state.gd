extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var jump_horizontal_speed : int = 200
@export var max_jump_horizontal_speed : int = 200	

@export_category("Fall State")
@export var coyote_time : float = 0.1

const GRAVITY : int = 700
var coyote_jump : bool


func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	var direction : float = GameInputEvents.movement_input()
	
	if !character_body_2d.is_on_floor():
		get_coyote_time()
		character_body_2d.velocity.y += GRAVITY * delta

		if direction != 0:
			animated_sprite_2d.flip_h = false if direction > 0 else true
			character_body_2d.velocity.x += direction * jump_horizontal_speed
			character_body_2d.velocity.x = clamp(character_body_2d.velocity.x, -max_jump_horizontal_speed, max_jump_horizontal_speed)
		else:
			character_body_2d.velocity.x = 0
	
	character_body_2d.move_and_slide()
	
	# transitioning states
	
	# idle state
	if character_body_2d.is_on_floor():
		transition.emit("Idle")
	
	# jump state
	if GameInputEvents.jump_input() and coyote_jump:
		transition.emit("Jump")


func enter():
	coyote_jump = true
	animated_sprite_2d.play("fall")


func exit():
	animated_sprite_2d.stop()


func get_coyote_time():
	await get_tree().create_timer(coyote_time).timeout
	coyote_jump = false

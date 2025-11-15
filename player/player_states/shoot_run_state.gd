extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var muzzle : Marker2D

@export_category("Run State")
@export var speed : int = 1000
@export var max_horizontal_speed: int = 300

const GRAVITY : int = 1000
var muzzle_position : Vector2

func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	var direction : float = GameInputEvents.movement_input()
	
	gun_muzzle_position(direction)
	
	if direction:
		character_body_2d.velocity.x += direction * speed
		character_body_2d.velocity.x = clamp(character_body_2d.velocity.x, -max_horizontal_speed, max_horizontal_speed)
	
	if direction != 0:
		animated_sprite_2d.flip_h = false if direction > 0 else true
	
	character_body_2d.velocity.y += GRAVITY * delta
	
	if GameInputEvents.shoot_input():
		gun_muzzle_position(direction)
		var camera = get_viewport().get_camera_2d()
		var mouse_global = camera.get_global_mouse_position()
		var shootdirection : Vector2 = (mouse_global - muzzle.global_position).normalized()
		GunManager.createBullet(shootdirection, muzzle.global_position)
	
	character_body_2d.move_and_slide()
	
	# transitioning states
	
	# fall state
	if !character_body_2d.is_on_floor():
		transition.emit("Fall")
	
	# idle state
	if direction == 0:
		transition.emit("Idle")
	
	# jump state
	if GameInputEvents.jump_input():
		transition.emit("jump")


func enter():
	muzzle.position = Vector2(18, -26)
	muzzle_position = muzzle.position
	
	animated_sprite_2d.play("shoot_run")


func exit():
	animated_sprite_2d.stop()


func gun_muzzle_position(direction : float):
	if direction > 0:
		muzzle.position.x = muzzle_position.x
	elif direction < 0:
		muzzle.position.x = -muzzle_position.x

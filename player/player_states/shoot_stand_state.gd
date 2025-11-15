extends NodeState

var bullet = preload("res://player/bullet.tscn")

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var muzzle : Marker2D
@export var hold_gun_time : float = 2.0

var muzzle_position : Vector2

func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	if GameInputEvents.shoot_input():
		gun_muzzle_position()
		var camera = get_viewport().get_camera_2d()
		var mouse_global = camera.get_global_mouse_position()
		var shootdirection : Vector2 = (mouse_global - muzzle.global_position).normalized()
		GunManager.createBullet(shootdirection, muzzle.global_position)
	
	# run state	
	var direction : float = GameInputEvents.movement_input()
	
	if direction and character_body_2d.is_on_floor():
		transition.emit("Run")
	
	# jump state
	if GameInputEvents.jump_input():
		transition.emit("Jump")


func enter():
	muzzle.position = Vector2(18, -26)
	muzzle_position = muzzle.position
	get_tree().create_timer(hold_gun_time).timeout.connect(on_hold_gun_timout)
	animated_sprite_2d.play("shoot_stand")


func exit():
	animated_sprite_2d.stop()


func on_hold_gun_timout():
	transition.emit("Idle")


func gun_muzzle_position():
	if !animated_sprite_2d.flip_h:
		muzzle.position.x = muzzle_position.x
	elif animated_sprite_2d.flip_h:
		muzzle.position.x = -muzzle_position.x

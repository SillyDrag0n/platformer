extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var attack_timer : Timer
@export var muzzle : Marker2D	

var skeleton_projectile = preload("res://enemies/skeleton/skeleton_projectile.tscn")

var player_global_position : Vector2
var can_shoot : bool = true

func on_physics_process(_delta : float):
	animated_sprite_2d.play("aggro")
	player_global_position = GameManager.get_global_player_position()
	if character_body_2d.global_position > player_global_position:
		animated_sprite_2d.flip_h = true
	elif character_body_2d.global_position < player_global_position:
		animated_sprite_2d.flip_h = false
		
	shoot_at_player()

func exit():
	pass

func shoot_at_player():
	if can_shoot:
		var projectile_instance = skeleton_projectile.instantiate() as Node2D
		get_tree().current_scene.add_child(projectile_instance)

		animated_sprite_2d.play("shoot")
		projectile_instance.direction = player_global_position
		projectile_instance.rotation = projectile_instance.direction.angle()
		projectile_instance.global_position = muzzle.global_position
		attack_timer.start()


func _on_attack_timer_timeout() -> void:
	can_shoot = true

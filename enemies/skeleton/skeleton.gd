extends CharacterBody2D

@export var is_chasing: bool = false
@export var gun_muzzle: Marker2D
@export var gun_timer: Timer

var cactus_attack = preload("res://enemies/skeleton/skeleton_attack.tscn")

const SPEED = 100.0
var can_shoot: bool = true
var shoot_enabled: bool = false


func _physics_process(_delta: float) -> void:
	chase_player()
	if shoot_enabled:
		shoot()


func chase_player():
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


func shoot():
	if can_shoot:
		can_shoot = false
		gun_timer.start()
		var attack = cactus_attack.instantiate() as Node2D
		attack.global_position = gun_muzzle.global_position
		var player_global_position = GameManager.get_global_player_position()
		attack.direction = (player_global_position - global_position).normalized()
		attack.rotation = attack.direction.angle()
		print_debug("Shoot projectile")
		get_tree().current_scene.add_child(attack)

func _on_attack_timer_timeout() -> void:
	can_shoot = true

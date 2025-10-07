extends CharacterBody2D

var enemy_death_effect = preload("res://enemies/enemy_death_effect.tscn")
var cactus_attack = preload("res://enemies/cactus/cactus_attack.tscn")

@export var wait_time : int = 3
@export var health_amount : int = 3
@export var damage_amount : int = 1

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var timer = $Timer

enum State { Idle, Scout, Aggro, Attack }
var current_state : State
var can_attack : bool
var attack_position : Vector2
	
func _ready():
	timer.wait_time = wait_time
	current_state = State.Idle
	can_attack = true

func _process(delta):
	enemy_attack()
	enemy_animations()

func enemy_attack():
	if current_state == State.Aggro && can_attack:
		current_state = State.Attack
		print_debug("Attack")
		spawn_attacks(get_tree().get_nodes_in_group("attack_spawns_left"), -1)
		spawn_attacks(get_tree().get_nodes_in_group("attack_spawns_right"), 1)

func spawn_attacks(bullet_spawns, direction):
	for spawnpoint in bullet_spawns:
		var attack = cactus_attack.instantiate() as Node2D
		attack.global_position = spawnpoint.global_position
		attack.direction = direction
		print_debug("Shoot projectile")
		get_tree().current_scene.add_child(attack)

func enemy_animations():
	if current_state == State.Idle:
		animated_sprite_2d.play("idle")

	elif current_state == State.Scout:
		animated_sprite_2d.play("scout")

	elif current_state == State.Attack:
		animated_sprite_2d.play("attack")
		can_attack = false
		timer.start()	

	elif current_state == State.Aggro && !can_attack:
		animated_sprite_2d.play("aggro")

func _on_timer_timeout():
	can_attack = true

func _on_hurtbox_area_entered(area : Area2D):
	if area.get_parent().has_method("get_damage_amount"):
		var node = area.get_parent() as Node
		health_amount -= node.damage_amount
		print("Health amount: ", health_amount)
		
		if health_amount <= 0:
			var enemy_death_effect_instance = enemy_death_effect.instantiate() as Node2D
			enemy_death_effect_instance.global_position = global_position
			get_parent().add_child(enemy_death_effect_instance)
			queue_free()

func _on_aggro_area_body_entered(body:Node2D):
	current_state = State.Aggro

func _on_scout_area_body_entered(body:Node2D):
		current_state = State.Scout

func _on_scout_area_body_exited(body:Node2D):
	current_state = State.Idle

func _on_animated_sprite_2d_animation_finished():
	if current_state == State.Attack:
		current_state = State.Aggro

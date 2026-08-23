extends Enemy

var cactus_attack = preload("res://enemies/cactus/cactus_attack.tscn")

@export var wait_time : int = 3

@export var attack_spawns_left_01 : Marker2D
@export var attack_spawns_left_02 : Marker2D
@export var attack_spawns_right_01 : Marker2D
@export var attack_spawns_right_02 : Marker2D

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
		spawn_attacks(attack_spawns_left_01, -1)
		spawn_attacks(attack_spawns_left_02, -1)
		spawn_attacks(attack_spawns_right_01, 1)
		spawn_attacks(attack_spawns_right_02, 1)

func spawn_attacks(spawnpoint, direction):
	var attack = cactus_attack.instantiate() as Node2D
	attack.global_position = spawnpoint.global_position
	attack.direction = direction
	ProjectileLayer.spawn(attack)

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

func _on_aggro_area_body_entered(body:Node2D):
	current_state = State.Aggro

func _on_scout_area_body_entered(body:Node2D):
	current_state = State.Scout

func _on_scout_area_body_exited(body:Node2D):
	current_state = State.Idle

func _on_animated_sprite_2d_animation_finished():
	if current_state == State.Attack:
		current_state = State.Aggro

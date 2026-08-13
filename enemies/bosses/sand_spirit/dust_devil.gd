extends Node2D

const DESPAWN_Y := 800.0

@export var speed : float = 180
@export var damage_amount : int = 1
@export var life_time : float = 6.0

var direction : Vector2 = Vector2.ZERO

func _ready():
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	$Timer.wait_time = life_time
	$Timer.start()

func _physics_process(delta):
	var move = direction * speed * delta
	global_position += move
	if global_position.y > DESPAWN_Y:
		queue_free()

func _on_timer_timeout():
	queue_free()

func get_damage_amount() -> int:
	return damage_amount

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	queue_free()

func _on_hurtbox_body_entered(_body: Node2D) -> void:
	queue_free()

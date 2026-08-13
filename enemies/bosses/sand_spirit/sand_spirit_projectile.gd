extends AnimatedSprite2D

@export var speed : float = 350
@export var direction : Vector2
@export var damage_amount : int = 1

func _ready():
	rotation = direction.angle()
	$Timer.start()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_timer_timeout():
	queue_free()

func get_damage_amount() -> int:
	return damage_amount

func _on_hitbox_area_entered(_area: Area2D) -> void:
	queue_free()

func _on_hitbox_body_entered(_body: Node2D) -> void:
	queue_free()

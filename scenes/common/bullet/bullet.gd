extends Area2D

@export var speed : float = 500
var baseDamage : float = 10
var bullet_direction : Vector2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position -= bullet_direction * speed * delta
	rotation = bullet_direction.angle()

func _on_body_entered(body:Node2D) -> void:
	print("Bullet entered Node2D")

func _on_area_entered(area:Area2D) -> void:
	print("Bullet entered Area2D")

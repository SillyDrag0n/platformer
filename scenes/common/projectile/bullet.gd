extends Area2D

@export var speed : float = 500
var bullet_direction : Vector2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position -= bullet_direction * speed * delta
	rotation = bullet_direction.angle()
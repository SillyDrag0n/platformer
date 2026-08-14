extends Area2D

@export var radius : float = 6.0
@export var color : Color = Color(1.0, 0.85, 0.2)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 24, color, 1.0)

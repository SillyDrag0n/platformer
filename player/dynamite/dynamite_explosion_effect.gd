extends Node2D

const DURATION : float = 0.35
const COLOR := Color(1.0, 0.55, 0.15, 0.85)

var radius : float = 64.0
var _progress : float = 0.0


func set_radius(new_radius : float) -> void:
	radius = new_radius


func _ready() -> void:
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tween.tween_callback(queue_free)


func _set_progress(value : float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var current_radius : float = radius * _progress
	var color := COLOR
	color.a *= (1.0 - _progress)
	draw_circle(Vector2.ZERO, current_radius, color)

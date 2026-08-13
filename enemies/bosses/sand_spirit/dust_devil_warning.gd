extends Node2D

@onready var marker := $Marker


func _ready():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(marker, "scale", Vector2(3.0, 3.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(marker, "scale", Vector2(2.0, 2.0), 0.3).set_trans(Tween.TRANS_SINE)


func _on_timer_timeout():
	queue_free()

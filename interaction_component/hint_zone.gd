class_name HintZone
extends Area2D

@export var watch_action : StringName = &""
@export var hint_text_format : String = "Press %s to..."

var _fired := false


func _on_hint_zone_body_entered(body : Node2D) -> void:
	if _fired or not body.is_in_group("Player"):
		return
	_fired = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_hint(watch_action, hint_text_format)

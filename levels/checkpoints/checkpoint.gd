extends Node2D

@export var checkpoint_active : bool = false
@export var respawn_marker: Marker2D
@export var animated_sprite_2d : AnimatedSprite2D

func _on_area_2d_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		respawn_marker.global_position = position
		checkpoint_active = true
		animated_sprite_2d.play("active")
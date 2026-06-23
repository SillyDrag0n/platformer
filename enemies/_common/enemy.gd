class_name Enemy
extends CharacterBody2D

const DEATH_EFFECT: PackedScene = preload("res://enemies/_common/enemy_death_effect.tscn")

@export var health_amount: int = 3
@export var damage_amount: int = 1


func _on_hurtbox_area_entered(area: Area2D) -> void:
	var source := area.get_parent()
	if source != null and source.has_method("get_damage_amount"):
		take_damage(source.get_damage_amount())


func take_damage(amount: int) -> void:
	health_amount -= amount
	if health_amount <= 0:
		die()


func die() -> void:
	var effect := DEATH_EFFECT.instantiate() as Node2D
	effect.global_position = global_position
	get_parent().add_child(effect)
	queue_free()

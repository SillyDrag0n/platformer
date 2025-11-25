extends CharacterBody2D

signal PlayerDeath()

var bullet = preload("res://player/gun/bullet/bullet.tscn")
var player_death_effect = preload("res://player/player_death_effect/player_death_effect.tscn")

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var muzzle : Marker2D = $Muzzle

func _ready() -> void:
	GameManager.player = self

func player_death():
	var player_death_effect_instance = player_death_effect.instantiate() as Node2D
	player_death_effect_instance.global_position = global_position
	get_parent().add_child(player_death_effect_instance)
	PlayerDeath.emit()
	queue_free()


func _on_hurtbox_body_entered(body : Node2D):
	if body.is_in_group("Enemy"):
		print("Enemy entered ", body.damage_amount)
		
		var tween = get_tree().create_tween()
		tween.tween_property(animated_sprite_2d, "material:shader_parameter/enabled", true, 0)
		tween.tween_property(animated_sprite_2d, "material:shader_parameter/enabled", false, 0.2)
		
		HealthManager.decrease_health(body.damage_amount)
		CheckPlayerHealth()


func _on_hurtbox_area_entered(area:Area2D) -> void:
	if area.get_parent().has_method("get_damage_amount"):
		var node = area.get_parent() as Node
		print("Enemy entered ", node.damage_amount)
		
		var tween = get_tree().create_tween()
		tween.tween_property(animated_sprite_2d, "material:shader_parameter/enabled", true, 0)
		tween.tween_property(animated_sprite_2d, "material:shader_parameter/enabled", false, 0.2)
		
		HealthManager.decrease_health(node.damage_amount)
		CheckPlayerHealth()


func CheckPlayerHealth():
	if HealthManager.current_health == 0:
		player_death()

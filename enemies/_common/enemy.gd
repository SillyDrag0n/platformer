class_name Enemy
extends CharacterBody2D

const DEATH_EFFECT: PackedScene = preload("res://enemies/_common/enemy_death_effect.tscn")
const HIT_FLASH_SHADER: Shader = preload("res://player/player_hit_flash_shader.tres")
const DYNAMITE_PICKUP_SCENE: PackedScene = preload("res://pickups/dynamite_pickup/dynamite_pickup.tscn")

@export var health_amount: int = 3
@export var damage_amount: int = 1
@export var enemy_id: String = "" # matches QuestData.required_enemy_id for kill-count quests

# Chance (0 = never, per-enemy opt-in) to drop a stick of dynamite on death - e.g. bandits.
@export_range(0.0, 1.0) var dynamite_drop_chance: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _on_hurtbox_area_entered(area: Area2D) -> void:
	var source := area.get_parent()
	if source != null and source.has_method("get_damage_amount"):
		take_damage(source.get_damage_amount())


func take_damage(amount: int) -> void:
	health_amount -= amount
	flash_hit()
	if health_amount <= 0:
		die()


func flash_hit() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.material == null:
		var flash_material := ShaderMaterial.new()
		flash_material.shader = HIT_FLASH_SHADER
		animated_sprite.material = flash_material
	var tween = create_tween()
	tween.tween_property(animated_sprite, "material:shader_parameter/enabled", true, 0)
	tween.tween_property(animated_sprite, "material:shader_parameter/enabled", false, 0.2)


func die() -> void:
	QuestManager.report_kill(enemy_id)
	_maybe_drop_dynamite()
	var effect := DEATH_EFFECT.instantiate() as Node2D
	effect.global_position = global_position
	get_parent().add_child(effect)
	queue_free()


func _maybe_drop_dynamite() -> void:
	if dynamite_drop_chance <= 0.0 or randf() > dynamite_drop_chance:
		return
	var pickup := DYNAMITE_PICKUP_SCENE.instantiate()
	pickup.global_position = global_position
	get_parent().add_child(pickup)

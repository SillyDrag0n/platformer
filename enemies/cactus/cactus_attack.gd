extends AnimatedSprite2D

var bullet_impact_effect = preload("res://player/bullet_impact_effect.tscn")

@export var speed : int = 350
@export var damage_amount : int = 1
var direction : int


func _physics_process(delta):
	move_local_x(direction * speed * delta)

func _on_timer_timeout():
	queue_free()

func get_damage_amount() -> int:
	return damage_amount

func bullet_impact():
	var bullet_impact_effect_instance = bullet_impact_effect.instantiate() as Node2D
	bullet_impact_effect_instance.global_position = global_position
	get_parent().add_child(bullet_impact_effect_instance)
	queue_free()

func _attack_on_hurtbox_area_entered(area:Area2D) -> void:
	print("Enemy attack entered area")
	bullet_impact()

func _attack_on_hurtbox_body_entered(body:Node2D) -> void:
	print("Enemy attack entered body")
	bullet_impact()
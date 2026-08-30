extends AnimatedSprite2D

# One spine from the cactus coyote's volley (see enemies/cactus_coyote/cactus_coyote.gd). Same
# shape as enemies/cactus/cactus_attack.gd - the player's own Hurtbox picks this up off the
# EnemyAttacks layer and asks it for get_damage_amount() - but travels along a Vector2 like the
# sand spirit's projectile does, since the volley is fanned rather than fired flat.

const IMPACT_EFFECT : PackedScene = preload("res://enemies/_common/bullet/bullet_impact_effect.tscn")

# Slow enough to react to on sight: the whole point of the fan is that a sidestep or a jump beats
# it, which only holds if the player has time to read where the spines are going.
@export var speed : float = 200.0
@export var damage_amount : int = 1

var direction : Vector2 = Vector2.RIGHT


func _ready() -> void:
	rotation = direction.angle()


func _physics_process(delta : float) -> void:
	global_position += direction * speed * delta


func _on_timer_timeout() -> void:
	queue_free()


func get_damage_amount() -> int:
	return damage_amount


func _on_hurtbox_area_entered(_area : Area2D) -> void:
	_impact()


func _on_hurtbox_body_entered(_body : Node2D) -> void:
	_impact()


func _impact() -> void:
	var effect := IMPACT_EFFECT.instantiate() as Node2D
	effect.global_position = global_position
	get_parent().add_child(effect)
	queue_free()

class_name Collectible
extends Node2D

@export var award_amount : int = 1

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label


func _ready() -> void:
	label.hide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("Player"):
		return

	animated_sprite_2d.hide()

	label.text = "%s" % award_amount
	CollectibleManager.give_pickup_award(award_amount)
	label.show()

	var tween := get_tree().create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -10), 0.5).from_current()
	tween.tween_callback(queue_free)

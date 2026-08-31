extends Node2D

const DYNAMITE_ITEM : ItemData = preload("res://items/utility/dynamite.tres")

@export var pickup_amount : int = 1

@onready var sprite : Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = DYNAMITE_ITEM.icon
	PickupDrop.fall_to_ground(self)


func _on_area_2d_body_entered(body : Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	# Dynamite is capped (see max_stack_size on dynamite.tres) - if the player's already full,
	# leave the pickup in the world instead of silently discarding the extra over the cap.
	var room : int = DYNAMITE_ITEM.max_stack_size - InventoryManager.get_owned_quantity(DYNAMITE_ITEM)
	if room <= 0:
		return

	for i in mini(pickup_amount, room):
		InventoryManager.add_item(DYNAMITE_ITEM)
	queue_free()

extends Node2D

const DYNAMITE_ITEM : ItemData = preload("res://items/utility/dynamite.tres")

@export var dynamite_amount : int = 2

@onready var interactable : Area2D = $Interactable


func _ready() -> void:
	interactable.interact = _on_interact


func _on_interact() -> void:
	# Same cap handling as DynamitePickup - a crate opened while already full just stays closed
	# rather than wasting the contents.
	var room : int = DYNAMITE_ITEM.max_stack_size - InventoryManager.get_owned_quantity(DYNAMITE_ITEM)
	if room <= 0:
		return

	for i in mini(dynamite_amount, room):
		InventoryManager.add_item(DYNAMITE_ITEM)
	queue_free()

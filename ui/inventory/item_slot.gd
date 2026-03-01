class_name ItemSlot
extends ColorRect

var item : ItemData
var quantity : int

@onready var icon = $Icon
@onready var quantity_label = $QuantityLabel

@export var empty_texture: Texture2D


func set_slot_data(new_item: ItemData, new_quantity: int):
	item = new_item
	quantity = new_quantity
	update_visuals()

func update_visuals():
	if item and item.icon:
		icon.texture = item.icon
		quantity_label.text = str(quantity)
		quantity_label.visible = quantity > 1
	else:
		icon.texture = empty_texture
		quantity_label.text = ""
		quantity_label.visible = false

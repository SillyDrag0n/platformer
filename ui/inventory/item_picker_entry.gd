class_name ItemPickerEntry
extends ColorRect

signal selected(item : ItemData)

var item : ItemData

@export var empty_texture : Texture2D

@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var name_label : Label = $HBoxContainer/NameLabel


func set_item_data(new_item : ItemData) -> void:
	item = new_item
	if item and item.icon:
		icon_rect.texture = item.icon
		name_label.text = item.display_name
	elif item:
		icon_rect.texture = empty_texture
		name_label.text = item.display_name
	else:
		icon_rect.texture = empty_texture
		name_label.text = "None (unequip)"


func _on_button_pressed() -> void:
	selected.emit(item)

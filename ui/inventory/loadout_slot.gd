class_name LoadoutSlot
extends ColorRect

signal selected

@export var slot_name : String = ""
@export var empty_texture : Texture2D

@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var slot_name_label : Label = $HBoxContainer/VBoxContainer/SlotNameLabel
@onready var item_name_label : Label = $HBoxContainer/VBoxContainer/ItemNameLabel


func _ready() -> void:
	slot_name_label.text = slot_name


func set_item(item : ItemData) -> void:
	if item and item.icon:
		icon_rect.texture = item.icon
		item_name_label.text = item.display_name
	elif item:
		icon_rect.texture = empty_texture
		item_name_label.text = item.display_name
	else:
		icon_rect.texture = empty_texture
		item_name_label.text = "Empty"


func _on_button_pressed() -> void:
	selected.emit()

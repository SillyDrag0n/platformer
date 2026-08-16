class_name ItemPickerEntry
extends ColorRect

signal selected(item : ItemData)

const NORMAL_COLOR := Color(1, 1, 1, 0.15)
const FOCUSED_COLOR := Color(1, 1, 1, 0.45)

var item : ItemData

@export var empty_texture : Texture2D

@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var name_label : Label = $HBoxContainer/NameLabel
@onready var button : Button = $Button


func _ready() -> void:
	# The Button covering this entry is fully transparent, which also hides its built-in focus
	# outline - drive the highlight manually instead.
	button.focus_entered.connect(func(): color = FOCUSED_COLOR)
	button.focus_exited.connect(func(): color = NORMAL_COLOR)


func set_item_data(new_item : ItemData, none_label : String = "None (unequip)") -> void:
	item = new_item
	if item and item.icon:
		icon_rect.texture = item.icon
		name_label.text = item.display_name
	elif item:
		icon_rect.texture = empty_texture
		name_label.text = item.display_name
	else:
		icon_rect.texture = empty_texture
		name_label.text = none_label


func _on_button_pressed() -> void:
	selected.emit(item)

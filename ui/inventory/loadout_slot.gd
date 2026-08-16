class_name LoadoutSlot
extends ColorRect

signal selected

const NORMAL_COLOR := Color(1, 1, 1, 0.15)
const FOCUSED_COLOR := Color(1, 1, 1, 0.45)

@export var slot_name : String = ""
@export var empty_texture : Texture2D
# Slots that can never truly be empty (weapon skins, outfit) use this instead of "Empty" -
# there's always a default look underneath, so calling it empty is misleading.
@export var empty_label : String = "Empty"

@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var slot_name_label : Label = $HBoxContainer/VBoxContainer/SlotNameLabel
@onready var item_name_label : Label = $HBoxContainer/VBoxContainer/ItemNameLabel
@onready var button : Button = $Button


func _ready() -> void:
	slot_name_label.text = slot_name
	# The Button covering this slot is fully transparent (so it doesn't paint over the icon/
	# labels), which also hides its built-in focus outline - drive the highlight manually instead.
	button.focus_entered.connect(func(): color = FOCUSED_COLOR)
	button.focus_exited.connect(func(): color = NORMAL_COLOR)


func set_item(item : ItemData) -> void:
	if item and item.icon:
		icon_rect.texture = item.icon
		item_name_label.text = item.display_name
	elif item:
		icon_rect.texture = empty_texture
		item_name_label.text = item.display_name
	else:
		icon_rect.texture = empty_texture
		item_name_label.text = empty_label


func _on_button_pressed() -> void:
	selected.emit()

class_name ItemSlot
extends ColorRect

signal selected(item : ItemData)

var item : ItemData
var quantity : int

@onready var icon = $Icon
@onready var quantity_label = $QuantityLabel
@onready var button : Button = $Button

# Captured in _ready() so focus_exited restores whatever color was actually authored in the
# editor, rather than a hardcoded assumption of what "normal" looks like.
var _rest_color : Color

# Matches the theme's own hover/selected-tab accent (game_theme.tres) rather than inventing a new
# one, so a focused slot reads as the same kind of highlight as the rest of the UI.
const FOCUS_COLOR := Color(0.960784, 0.615686, 0.156863, 0.6)


func _ready() -> void:
	_rest_color = color
	button.pressed.connect(_on_button_pressed)
	# Button's own focus stylebox never shows here: self_modulate = 0 on it (see ItemSlot.tscn)
	# makes it fully transparent so its click-hitbox doesn't paint over the Icon sprite underneath,
	# which also zeroes out anything its theme would draw for it, focus outline included - so the
	# slot's own background tint stands in as the focus indicator instead.
	button.focus_entered.connect(_on_focus_entered)
	button.focus_exited.connect(_on_focus_exited)


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
		icon.texture = null
		quantity_label.text = ""
		quantity_label.visible = false


func _on_button_pressed() -> void:
	selected.emit(item)


func _on_focus_entered() -> void:
	color = FOCUS_COLOR
	# Navigating onto a slot (keyboard/gamepad) previews it the same way pressing it does, so the
	# info panel always matches whichever slot is currently focused without an extra confirm press.
	selected.emit(item)


func _on_focus_exited() -> void:
	color = _rest_color

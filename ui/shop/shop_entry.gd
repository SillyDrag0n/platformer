class_name ShopEntry
extends ColorRect

signal buy_pressed(item : ItemData)

var item : ItemData

@export var empty_texture : Texture2D

@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var name_label : Label = $HBoxContainer/NameLabel
@onready var price_label : Label = $HBoxContainer/PriceLabel
@onready var buy_button : Button = $HBoxContainer/BuyButton


func set_item_data(new_item : ItemData) -> void:
	item = new_item
	icon_rect.texture = item.icon if item.icon else empty_texture
	name_label.text = tr(item.display_name)
	price_label.text = str(item.price)

	var already_owned : bool = item.max_stack_size <= 1 and InventoryManager.is_owned(item)
	buy_button.disabled = already_owned or !CollectibleManager.can_afford(item.price)
	buy_button.text = tr("Owned") if already_owned else tr("Buy")


func _on_buy_button_pressed() -> void:
	buy_pressed.emit(item)

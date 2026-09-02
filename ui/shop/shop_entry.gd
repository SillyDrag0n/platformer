class_name ShopEntry
extends ColorRect

signal buy_pressed(item : ItemData)
# The row the player is looking at, for the counter display at the bottom of the shop (see
# ui/shop/shop_ui.gd). Raised by focus and by hover both: a controller only ever moves focus, and
# a mouse user would otherwise have to press Buy - the one thing that spends their money - just to
# read what they were buying.
signal highlighted(item : ItemData)

var item : ItemData

@export var empty_texture : Texture2D

@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var name_label : Label = $HBoxContainer/NameColumn/NameLabel
@onready var description_label : Label = $HBoxContainer/NameColumn/DescriptionLabel
@onready var price_label : Label = $HBoxContainer/PriceLabel
@onready var buy_button : Button = $HBoxContainer/BuyButton


# The shelf rows were the one list in the game that never marked the row you were on - the only
# thing showing your place was the focus ring on the Buy button at the far right of it. They pick
# up the same accent a focused loadout slot or picker entry uses.
const NORMAL_COLOR := Color(0.945098, 0.882353, 0.760784, 0.12)
const FOCUSED_COLOR := Color(0.960784, 0.615686, 0.156863, 0.32)


func _ready() -> void:
	color = NORMAL_COLOR
	buy_button.focus_entered.connect(_raise_highlight)
	buy_button.mouse_entered.connect(_raise_highlight)
	mouse_entered.connect(_raise_highlight)
	buy_button.focus_entered.connect(func(): color = FOCUSED_COLOR)
	buy_button.focus_exited.connect(func(): color = NORMAL_COLOR)


func _raise_highlight() -> void:
	if item != null:
		highlighted.emit(item)


func set_item_data(new_item : ItemData) -> void:
	item = new_item
	icon_rect.texture = item.icon if item.icon else empty_texture
	# A bundle says so on the shelf, so the price reads against what the player actually gets.
	name_label.text = tr(item.display_name) if item.purchase_quantity <= 1 \
		else "%d x %s" % [item.purchase_quantity, tr(item.display_name)]
	description_label.text = tr(item.description)
	description_label.visible = item.description != ""
	price_label.text = str(item.price)

	var already_owned : bool = item.max_stack_size <= 1 and InventoryManager.is_owned(item)
	# A bundle is all or nothing: three sticks for eighteen dollars shouldn't hand over one just
	# because that is all the room left in the stack.
	var has_room : bool = InventoryManager.get_owned_quantity(item) + item.purchase_quantity \
		<= item.max_stack_size
	buy_button.disabled = already_owned or not has_room or !CollectibleManager.can_afford(item.price)
	buy_button.text = tr("Owned") if already_owned else tr("Buy")


func _on_buy_button_pressed() -> void:
	buy_pressed.emit(item)

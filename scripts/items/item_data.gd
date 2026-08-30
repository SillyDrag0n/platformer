class_name ItemData
extends Resource

@export var display_name : String
@export var description : String
@export var max_stack_size : int = 1
@export var icon : Texture
@export var price : int = 0

# How many come in one purchase. Dynamite is sold as a bundle of three, so a shop hands over that
# many for one price - and will not sell a bundle there is no room for (see ui/shop/shop_entry.gd).
@export var purchase_quantity : int = 1

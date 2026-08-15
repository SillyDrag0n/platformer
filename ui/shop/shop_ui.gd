class_name ShopUI
extends MenuPopup

@export var shop_title : String = "Shop"
@export var shop_items : Array[ItemData] = []
@export var portrait : Texture2D

@export var title_label : Label
@export var currency_label : Label
@export var portrait_rect : TextureRect
@export var entry_list_container : VBoxContainer
@export var entry_scene : PackedScene


func _ready() -> void:
	super._ready()
	title_label.text = shop_title
	portrait_rect.texture = portrait
	portrait_rect.visible = portrait != null
	CollectibleManager.on_collectible_award_received.connect(_on_currency_changed)
	InventoryManager.updated_inventory.connect(refresh_shop_ui)


func _on_opened() -> void:
	refresh_shop_ui()


func _on_currency_changed(_total : int) -> void:
	_refresh_currency_label()


func _refresh_currency_label() -> void:
	currency_label.text = "Gold: %d" % CollectibleManager.total_award_amount


func refresh_shop_ui() -> void:
	_refresh_currency_label()

	for child in entry_list_container.get_children():
		child.queue_free()

	for item in shop_items:
		var entry = entry_scene.instantiate()
		entry_list_container.add_child(entry)
		entry.set_item_data(item)
		entry.buy_pressed.connect(_on_entry_buy_pressed)


func _on_entry_buy_pressed(item : ItemData) -> void:
	if item.max_stack_size <= 1 and InventoryManager.is_owned(item):
		return
	if !CollectibleManager.can_afford(item.price):
		return

	if InventoryManager.add_item(item):
		CollectibleManager.spend(item.price)
		refresh_shop_ui()

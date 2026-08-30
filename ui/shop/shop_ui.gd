class_name ShopUI
extends MenuPopup

@export var shop_title : String = "Shop"
@export var shop_items : Array[ItemData] = []
@export var portrait : Texture2D

@export var title_label : Label
@export var currency_label : Label
@export var portrait_rect : TextureRect
@export var entry_list_container : VBoxContainer
@export var entry_list_scroll : ScrollContainer
@export var entry_scene : PackedScene
@export var close_button : Button

# Built once by _create_shop_entries() - shop_items is a fixed @export array, never changing size
# at runtime, so refresh_shop_ui() just updates these in place by index instead of rebuilding.
var _entry_nodes : Array = []


func _ready() -> void:
	super._ready()
	title_label.text = tr(shop_title)
	portrait_rect.texture = portrait
	portrait_rect.visible = portrait != null
	CollectibleManager.on_collectible_award_received.connect(_on_currency_changed)
	InventoryManager.updated_inventory.connect(refresh_shop_ui)
	_create_shop_entries()


# MenuPopup.open() never grabs focus on its own (see DialogueBox._on_opened() for the same fix) -
# without this a controller had nothing focused to navigate from the moment the shop opened.
func _on_opened() -> void:
	refresh_shop_ui()
	if not _entry_nodes.is_empty():
		_entry_nodes[0].buy_button.grab_focus()
	else:
		close_button.grab_focus()


func _on_currency_changed(_total : int) -> void:
	_refresh_currency_label()


func _refresh_currency_label() -> void:
	currency_label.text = tr("Dollars: %d") % CollectibleManager.total_award_amount


# Just refreshes each existing entry's data in place - rebuilding from scratch on every refresh
# (buying something, any inventory change) used to free and reinstantiate every entry's Button,
# silently dropping controller focus the moment anything changed, the same bug the inventory's
# item grid had (see inventory_ui.gd's update_inventory_ui()).
func refresh_shop_ui() -> void:
	_refresh_currency_label()
	for i in range(_entry_nodes.size()):
		_entry_nodes[i].set_item_data(shop_items[i])


func _create_shop_entries() -> void:
	for item in shop_items:
		var entry = entry_scene.instantiate()
		entry_list_container.add_child(entry)
		entry.set_item_data(item)
		entry.buy_pressed.connect(_on_entry_buy_pressed)
		# ScrollContainer doesn't scroll to a focused child on its own - see the identical fix in
		# settings_menu_screen.gd's _connect_scroll_follow() for why this is needed at all.
		entry.buy_button.focus_entered.connect(entry_list_scroll.ensure_control_visible.bind(entry.buy_button))
		_entry_nodes.append(entry)


func _on_entry_buy_pressed(item : ItemData) -> void:
	# Covers both non-stackable items (max_stack_size 1, e.g. weapons) and stackable ones without
	# room for the whole purchase (dynamite is sold three at a time into a stack that holds three) -
	# add_item() would otherwise silently start a second, invisible slot once the first is full, and
	# a bundle would end up half paid for.
	if InventoryManager.get_owned_quantity(item) + item.purchase_quantity > item.max_stack_size:
		return
	if !CollectibleManager.can_afford(item.price):
		return

	for i in item.purchase_quantity:
		if not InventoryManager.add_item(item):
			return
	CollectibleManager.spend(item.price)
	refresh_shop_ui()

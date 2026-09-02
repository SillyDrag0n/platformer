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

# The counter display along the bottom of the shop: a proper look at whichever row the player is
# on, since a 68px shelf row can only fit a truncated line of description and none of the numbers
# that decide whether something is worth buying.
@export var detail_panel : PanelContainer
@export var detail_icon : TextureRect
@export var detail_name_label : Label
@export var detail_description_label : Label
@export var detail_stats_label : Label
@export var detail_price_label : Label
@export var detail_stock_label : Label

# Reads as a list rather than a run-on sentence at a glance, and BoldPixels has the middle dot.
const STAT_SEPARATOR := "   ·   "

const COSMETIC_SLOT_NAMES := {
	CosmeticItemData.CosmeticSlot.HAT: "Hat",
	CosmeticItemData.CosmeticSlot.OUTFIT: "Outfit",
	CosmeticItemData.CosmeticSlot.WEAPON_SKIN: "Weapon skin",
	CosmeticItemData.CosmeticSlot.ACCESSORY: "Accessory",
}

# Built once by _create_shop_entries() - shop_items is a fixed @export array, never changing size
# at runtime, so refresh_shop_ui() just updates these in place by index instead of rebuilding.
var _entry_nodes : Array = []

# Whatever the counter display is currently showing, so a purchase can redraw it in place - the
# price stays put but "Owned" and the held count do not.
var _detail_item : ItemData = null


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
	detail_panel.visible = not _entry_nodes.is_empty()
	if not _entry_nodes.is_empty():
		_entry_nodes[0].buy_button.grab_focus()
		# Filled outright rather than left to the focus grab above to raise it. Re-opening a shop
		# whose first row still held focus moves nothing, so no highlight would be raised and the
		# counter would sit there describing whatever the player last looked at.
		_show_detail(shop_items[0])
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
	# Buying something changes what the counter has to say about it - the price does not move, but
	# "Owned" and the held count do.
	if _detail_item != null:
		_show_detail(_detail_item)


func _create_shop_entries() -> void:
	for item in shop_items:
		var entry = entry_scene.instantiate()
		entry_list_container.add_child(entry)
		entry.set_item_data(item)
		entry.buy_pressed.connect(_on_entry_buy_pressed)
		# ScrollContainer doesn't scroll to a focused child on its own - see the identical fix in
		# settings_menu_screen.gd's _connect_scroll_follow() for why this is needed at all.
		entry.buy_button.focus_entered.connect(entry_list_scroll.ensure_control_visible.bind(entry.buy_button))
		entry.highlighted.connect(_show_detail)
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


# --- The counter display ---

func _show_detail(item : ItemData) -> void:
	if item == null:
		return
	_detail_item = item
	detail_icon.texture = item.icon
	detail_icon.visible = item.icon != null
	detail_name_label.text = tr(item.display_name) if item.purchase_quantity <= 1 \
		else "%d x %s" % [item.purchase_quantity, tr(item.display_name)]
	# The shelf row truncates this to whatever fits on one line; here it gets to run on as far as
	# it was written.
	detail_description_label.text = tr(item.description)
	detail_description_label.visible = item.description != ""

	var stats : String = _stat_text(item)
	detail_stats_label.text = stats
	detail_stats_label.visible = stats != ""

	detail_price_label.text = "$%d" % item.price
	var stock : String = _stock_text(item)
	detail_stock_label.text = stock
	detail_stock_label.visible = stock != ""


# The numbers behind a purchase, pulled off whichever kind of item this is. Nothing on the shelf
# row carries these, so a player comparing the shotgun against the revolver they already have had
# no way to see what the money was actually buying them.
func _stat_text(item : ItemData) -> String:
	var parts : PackedStringArray = []

	if item is WeaponItemData:
		var weapon : WeaponItemData = item
		parts.append(tr("Damage %d") % weapon.bullet_damage)
		parts.append(tr("Magazine %d") % weapon.magazine_size)
		parts.append(tr("Rate %.2fs") % weapon.cooldown)
		# Only worth saying for a weapon that actually scatters - every other gun would read
		# "1 pellet", which says nothing.
		if weapon.pellet_count > 1:
			parts.append(tr("%d pellets") % weapon.pellet_count)
	elif item is AmmoItemData:
		var ammo : AmmoItemData = item
		parts.append(tr("Damage x%.2f") % ammo.damage_modifier)
		parts.append(tr("Speed x%.2f") % ammo.speed_modifier)
	elif item is WeaponUpgradeItemData:
		var upgrade : WeaponUpgradeItemData = item
		# Which gun it was made for matters more than anything else about it: an upgrade does
		# nothing at all while any other weapon is in hand (see Gun.get_active_reload_window).
		if upgrade.target_weapon != null:
			parts.append(tr("Fits the %s") % tr(upgrade.target_weapon.display_name))
		if upgrade.active_reload_window > 0.0:
			parts.append(tr("Reload window %d%%") % roundi(upgrade.active_reload_window * 100.0))
	elif item is CosmeticItemData:
		parts.append(tr(COSMETIC_SLOT_NAMES.get(item.slot, "Cosmetic")))

	return STAT_SEPARATOR.join(parts)


# What the player already has of this, so the price is read against their own shelf rather than in
# the abstract. A one-off they own says so; anything stackable shows how much room is left.
func _stock_text(item : ItemData) -> String:
	if item.max_stack_size <= 1:
		return tr("Owned") if InventoryManager.is_owned(item) else ""
	return tr("Held: %d / %d") % [InventoryManager.get_owned_quantity(item), item.max_stack_size]

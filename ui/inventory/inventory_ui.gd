extends CanvasLayer

const BOUNTY_LIST_FONT = preload("res://ui/font/BoldPixels.ttf")

@export var item_grid : GridContainer
@export var item_slot_scene : PackedScene

@export var bounty_list_container : VBoxContainer
@export var bounty_title_label : Label
@export var bounty_status_label : Label
@export var bounty_description_label : Label
@export var bounty_detail_icon : TextureRect
@export var bounty_entry_scene : PackedScene
@export var default_bounty_icon : Texture2D

@export var slot_primary : LoadoutSlot
@export var slot_secondary : LoadoutSlot
@export var slot_utility : LoadoutSlot
@export var slot_ammo_primary : LoadoutSlot
@export var slot_ammo_secondary : LoadoutSlot
@export var slot_hat : LoadoutSlot
@export var slot_outfit : LoadoutSlot
@export var slot_weapon_skin_primary : LoadoutSlot
@export var slot_weapon_skin_secondary : LoadoutSlot
@export var slot_accessory : LoadoutSlot
@export var abilities_list_container : VBoxContainer
@export var item_picker : PopupPanel
@export var picker_list_container : VBoxContainer
@export var picker_entry_scene : PackedScene

var _picker_on_pick : Callable

func _ready():
	InventoryManager.updated_inventory.connect(update_inventory_ui)
	create_inventory_ui()
	visible = false
	InventoryManager.is_open = false

	create_bounty_ui()
	GameStateManager.bounty_unlocked.connect(_on_bounty_state_changed)
	GameStateManager.bounty_completed.connect(_on_bounty_state_changed)
	GameStateManager.region_unlocked.connect(_on_bounty_state_changed)

	slot_primary.selected.connect(_open_weapon_picker.bind(InventoryManager.WeaponSlot.PRIMARY))
	slot_secondary.selected.connect(_open_weapon_picker.bind(InventoryManager.WeaponSlot.SECONDARY))
	slot_utility.selected.connect(_open_utility_picker)
	slot_ammo_primary.selected.connect(_open_ammo_picker.bind(InventoryManager.WeaponSlot.PRIMARY))
	slot_ammo_secondary.selected.connect(_open_ammo_picker.bind(InventoryManager.WeaponSlot.SECONDARY))
	slot_hat.selected.connect(_open_cosmetic_picker.bind(CosmeticItemData.CosmeticSlot.HAT))
	slot_outfit.selected.connect(_open_cosmetic_picker.bind(CosmeticItemData.CosmeticSlot.OUTFIT))
	slot_weapon_skin_primary.selected.connect(_open_weapon_skin_picker.bind(InventoryManager.WeaponSlot.PRIMARY))
	slot_weapon_skin_secondary.selected.connect(_open_weapon_skin_picker.bind(InventoryManager.WeaponSlot.SECONDARY))
	slot_accessory.selected.connect(_open_cosmetic_picker.bind(CosmeticItemData.CosmeticSlot.ACCESSORY))

	InventoryManager.equipped_weapon_changed.connect(func(_slot, _weapon): refresh_loadout_ui())
	InventoryManager.equipped_ammo_changed.connect(func(_slot, _ammo): refresh_loadout_ui())
	InventoryManager.equipped_utility_changed.connect(func(_utility): refresh_loadout_ui())
	InventoryManager.equipped_cosmetic_changed.connect(func(_slot, _cosmetic): refresh_loadout_ui())
	InventoryManager.equipped_weapon_skin_changed.connect(func(_slot, _cosmetic): refresh_loadout_ui())
	AbilityManager.ability_unlocked.connect(func(_ability): refresh_abilities_ui())

	refresh_loadout_ui()
	refresh_abilities_ui()

func _process(_delta):
	if GameInputEvents.inventory_input():
		_set_open(!visible)
	elif visible and Input.is_action_just_pressed("ui_cancel"):
		_set_open(false)


func _set_open(is_open : bool) -> void:
	visible = is_open
	InventoryManager.is_open = is_open
	if is_open:
		_grab_default_focus()
	else:
		SaveManager.save_game()


# Only the bounty list is actually interactive right now (item slots are display-only), so
# that's what controller/keyboard focus should land on when the panel opens.
func _grab_default_focus() -> void:
	for child in bounty_list_container.get_children():
		if child is BountyEntry:
			child.grab_focus_button()
			return


func update_inventory_ui():
	create_inventory_ui()


func create_inventory_ui():
	for child in item_grid.get_children():
		child.queue_free()

	for slot_data in InventoryManager.item_slots:
		var slot = item_slot_scene.instantiate()
		item_grid.add_child(slot)
		slot.set_slot_data(slot_data["item"], slot_data["quantity"])


func _on_bounty_state_changed(_data = null):
	create_bounty_ui()


func create_bounty_ui():
	for child in bounty_list_container.get_children():
		child.queue_free()

	bounty_title_label.text = "Select a bounty"
	bounty_status_label.text = ""
	bounty_description_label.text = ""
	bounty_detail_icon.texture = default_bounty_icon
	bounty_detail_icon.self_modulate = Color.WHITE

	for region in GameStateManager.regions:
		var header := Label.new()
		header.text = region.name if region.unlocked else (region.name + " (Locked)")
		header.add_theme_font_override("font", BOUNTY_LIST_FONT)
		header.add_theme_font_size_override("font_size", 28)
		header.modulate = Color(1, 1, 1) if region.unlocked else Color(0.6, 0.6, 0.6)
		bounty_list_container.add_child(header)

		var region_bounties : Array[BountyData] = GameStateManager.get_bounties_for_region(region.id)
		if region_bounties.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No bounties posted yet."
			empty_label.add_theme_font_override("font", BOUNTY_LIST_FONT)
			empty_label.add_theme_font_size_override("font_size", 20)
			empty_label.modulate = Color(0.6, 0.6, 0.6)
			bounty_list_container.add_child(empty_label)
			continue

		for bounty in region_bounties:
			var entry = bounty_entry_scene.instantiate()
			bounty_list_container.add_child(entry)
			entry.set_bounty_data(bounty)
			entry.selected.connect(_on_bounty_entry_selected)


func _on_bounty_entry_selected(bounty : BountyData):
	bounty_title_label.text = bounty.title
	bounty_status_label.text = bounty.get_status_text()
	bounty_description_label.text = bounty.description if bounty.description != "" else "No details available yet."
	bounty_detail_icon.texture = bounty.icon if bounty.icon else default_bounty_icon
	bounty_detail_icon.self_modulate = Color.WHITE if bounty.completed else Color.BLACK


func refresh_loadout_ui():
	slot_primary.set_item(InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.PRIMARY))
	slot_secondary.set_item(InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.SECONDARY))
	slot_utility.set_item(InventoryManager.get_equipped_utility())
	slot_ammo_primary.set_item(InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.PRIMARY))
	slot_ammo_secondary.set_item(InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.SECONDARY))
	slot_hat.set_item(InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.HAT))
	slot_outfit.set_item(InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.OUTFIT))
	slot_weapon_skin_primary.set_item(InventoryManager.get_equipped_weapon_skin(InventoryManager.WeaponSlot.PRIMARY))
	slot_weapon_skin_secondary.set_item(InventoryManager.get_equipped_weapon_skin(InventoryManager.WeaponSlot.SECONDARY))
	slot_accessory.set_item(InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.ACCESSORY))


func refresh_abilities_ui():
	for child in abilities_list_container.get_children():
		child.queue_free()

	for ability in AbilityManager.abilities:
		var unlocked : bool = AbilityManager.is_unlocked(ability.id)
		var row := Label.new()
		row.text = ability.display_name + "  -  " + ("Unlocked" if unlocked else "Locked")
		row.add_theme_font_override("font", BOUNTY_LIST_FONT)
		row.add_theme_font_size_override("font_size", 24)
		row.modulate = Color(0.45, 0.85, 0.45) if unlocked else Color(0.6, 0.6, 0.6)
		abilities_list_container.add_child(row)


func _open_weapon_picker(slot : InventoryManager.WeaponSlot):
	var candidates : Array = InventoryManager.get_owned_items_by_type(WeaponItemData)
	_open_picker(candidates, func(item): InventoryManager.equip_weapon(slot, item))


func _open_utility_picker():
	var candidates : Array = InventoryManager.get_owned_items_by_type(UtilityItemData)
	_open_picker(candidates, func(item): InventoryManager.equip_utility(item))


func _open_ammo_picker(slot : InventoryManager.WeaponSlot):
	var candidates : Array = InventoryManager.get_owned_items_by_type(AmmoItemData)
	_open_picker(candidates, func(item): InventoryManager.equip_ammo(slot, item))


func _open_cosmetic_picker(slot : CosmeticItemData.CosmeticSlot):
	var candidates : Array[CosmeticItemData] = InventoryManager.get_owned_cosmetics_by_slot(slot)
	_open_picker(candidates, func(item):
		if item == null:
			InventoryManager.unequip_cosmetic(slot)
		else:
			InventoryManager.equip_cosmetic(item)
	)


func _open_weapon_skin_picker(slot : InventoryManager.WeaponSlot):
	var candidates : Array[CosmeticItemData] = InventoryManager.get_owned_cosmetics_by_slot(CosmeticItemData.CosmeticSlot.WEAPON_SKIN)
	_open_picker(candidates, func(item):
		if item == null:
			InventoryManager.unequip_weapon_skin(slot)
		else:
			InventoryManager.equip_weapon_skin(slot, item)
	)


func _open_picker(candidates : Array, on_pick : Callable):
	_picker_on_pick = on_pick

	for child in picker_list_container.get_children():
		child.queue_free()

	var none_entry = picker_entry_scene.instantiate()
	picker_list_container.add_child(none_entry)
	none_entry.set_item_data(null)
	none_entry.selected.connect(_on_picker_item_selected)

	for candidate in candidates:
		var entry = picker_entry_scene.instantiate()
		picker_list_container.add_child(entry)
		entry.set_item_data(candidate)
		entry.selected.connect(_on_picker_item_selected)

	item_picker.popup_centered(Vector2i(500, 600))


func _on_picker_item_selected(item : ItemData):
	_picker_on_pick.call(item)
	item_picker.hide()

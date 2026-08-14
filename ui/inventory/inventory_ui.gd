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

func _ready():
	InventoryManager.updated_inventory.connect(update_inventory_ui)
	create_inventory_ui()
	visible = false
	InventoryManager.is_open = false

	create_bounty_ui()
	GameStateManager.bounty_unlocked.connect(_on_bounty_state_changed)
	GameStateManager.bounty_completed.connect(_on_bounty_state_changed)
	GameStateManager.region_unlocked.connect(_on_bounty_state_changed)

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

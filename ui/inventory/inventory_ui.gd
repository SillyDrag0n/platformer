extends CanvasLayer

const BOUNTY_LIST_FONT = preload("res://ui/font/BoldPixels.ttf")

@export var tab_container : TabContainer

@export var item_grid : GridContainer
@export var item_slot_scene : PackedScene
@export var item_name_label : Label
@export var item_description_label : Label
@export var item_information_icon : Sprite2D

@export var bounty_list_container : VBoxContainer
@export var bounty_title_label : Label
@export var bounty_status_label : Label
@export var bounty_description_label : Label
@export var bounty_detail_icon : TextureRect
@export var bounty_entry_scene : PackedScene
@export var default_bounty_icon : Texture2D

@export var quest_list_container : VBoxContainer
@export var quest_entry_scene : PackedScene

@export var slot_primary : LoadoutSlot
@export var slot_secondary : LoadoutSlot
@export var utility_list_container : VBoxContainer
@export var slot_ammo_primary : LoadoutSlot
@export var slot_ammo_secondary : LoadoutSlot
@export var slot_hat : LoadoutSlot
@export var slot_outfit : LoadoutSlot
@export var slot_weapon_skin_primary : LoadoutSlot
@export var slot_weapon_skin_secondary : LoadoutSlot
@export var slot_accessory : LoadoutSlot
@export var abilities_list_container : VBoxContainer
@export var item_picker : PanelContainer
@export var item_picker_backdrop : Button
@export var picker_list_container : VBoxContainer
@export var picker_entry_scene : PackedScene

var _picker_on_pick : Callable

# Whichever control had focus right before the picker opened (that's always the LoadoutSlot
# button the player just pressed/confirmed, since it has to be focused to be the one that fired
# .selected in the first place) - restored in _close_picker() so closing the picker goes back to
# the slot the player was actually on, instead of always snapping to the tab's first control.
var _picker_opener : Control

# Built once by _create_item_slots() - InventoryManager.size (and so item_slots.size()) never
# changes at runtime, so the grid's node count is stable; update_inventory_ui() just refreshes
# these in place by index instead of rebuilding.
var _item_slot_nodes : Array = []

# Whether each quest tab section is expanded, keyed by the section keys used in
# _add_quest_section() below - persists across refreshes since create_quests_ui() rebuilds the
# section headers (and their toggle state) from scratch every time.
var _quest_section_expanded : Dictionary = {
	"in_progress": true,
	"completed": true,
}

# section key -> its header Button, rebuilt every create_quests_ui() call - lets a header's own
# press handler re-focus itself afterward instead of losing focus to the rebuild it triggered.
var _quest_section_headers : Dictionary = {}

func _ready():
	InventoryManager.updated_inventory.connect(update_inventory_ui)
	_create_item_slots()
	visible = false
	InventoryManager.is_open = false

	create_bounty_ui()
	GameStateManager.bounty_unlocked.connect(_on_bounty_state_changed)
	GameStateManager.bounty_completed.connect(_on_bounty_state_changed)
	GameStateManager.bounty_objective_completed.connect(_on_bounty_objective_changed)
	GameStateManager.bounty_stage_completed.connect(_on_bounty_objective_changed)
	GameStateManager.region_unlocked.connect(_on_bounty_state_changed)

	create_quests_ui()
	QuestManager.quest_received.connect(_on_quest_state_changed)
	QuestManager.quest_completed.connect(_on_quest_state_changed)

	slot_primary.selected.connect(_open_weapon_picker.bind(InventoryManager.WeaponSlot.PRIMARY))
	slot_secondary.selected.connect(_open_weapon_picker.bind(InventoryManager.WeaponSlot.SECONDARY))
	slot_ammo_primary.selected.connect(_open_ammo_picker.bind(InventoryManager.WeaponSlot.PRIMARY))
	slot_ammo_secondary.selected.connect(_open_ammo_picker.bind(InventoryManager.WeaponSlot.SECONDARY))
	slot_hat.selected.connect(_open_cosmetic_picker.bind(CosmeticItemData.CosmeticSlot.HAT))
	slot_outfit.selected.connect(_open_cosmetic_picker.bind(CosmeticItemData.CosmeticSlot.OUTFIT))
	slot_weapon_skin_primary.selected.connect(_open_weapon_skin_picker.bind(InventoryManager.WeaponSlot.PRIMARY))
	slot_weapon_skin_secondary.selected.connect(_open_weapon_skin_picker.bind(InventoryManager.WeaponSlot.SECONDARY))
	slot_accessory.selected.connect(_open_cosmetic_picker.bind(CosmeticItemData.CosmeticSlot.ACCESSORY))

	InventoryManager.equipped_weapon_changed.connect(func(_slot, _weapon): refresh_loadout_ui())
	InventoryManager.equipped_ammo_changed.connect(func(_slot, _ammo): refresh_loadout_ui())
	InventoryManager.equipped_utility_changed.connect(func(_utility): refresh_utility_ui())
	InventoryManager.equipped_cosmetic_changed.connect(func(_slot, _cosmetic): refresh_loadout_ui())
	InventoryManager.equipped_weapon_skin_changed.connect(func(_slot, _cosmetic): refresh_loadout_ui())
	AbilityManager.ability_unlocked.connect(func(_ability): refresh_abilities_ui())

	item_picker_backdrop.pressed.connect(_close_picker)

	_wire_loadout_focus_neighbors()

	refresh_loadout_ui()
	refresh_utility_ui()
	refresh_abilities_ui()

func _process(_delta):
	@warning_ignore("static_called_on_instance")
	if GameInputEvents.inventory_input():
		_set_open(!visible)
	elif visible and Input.is_action_just_pressed("ui_cancel"):
		# A cancel press backs out one level at a time: close the picker first if it's open,
		# only close the whole inventory once nothing else is on top of it.
		if item_picker.visible:
			_close_picker()
		else:
			_set_open(false)
	elif visible and Input.is_action_just_pressed("tab_left"):
		_cycle_tab(-1)
	elif visible and Input.is_action_just_pressed("tab_right"):
		_cycle_tab(1)


# TabContainer's built-in tab bar only takes keyboard/gamepad focus if the player navigates to
# it directly, which never happens here since default focus lands on the tab's content (see
# _grab_default_focus() below) - so tab switching needs its own dedicated input instead.
func _cycle_tab(direction : int) -> void:
	var tab_count := tab_container.get_tab_count()
	if tab_count == 0:
		return
	tab_container.current_tab = wrapi(tab_container.current_tab + direction, 0, tab_count)
	_grab_default_focus.call_deferred()


func _set_open(is_open : bool) -> void:
	visible = is_open
	InventoryManager.is_open = is_open
	if is_open:
		_grab_default_focus.call_deferred()
	else:
		# Closing the whole inventory should also drop the picker if it was left open -
		# otherwise it stays visible over whatever level is behind the now-hidden inventory.
		item_picker.visible = false
		item_picker_backdrop.visible = false
		SaveManager.save_game()


# Focuses the first focusable control inside whichever tab is currently showing - called on
# open and on every tab switch, since the previously-focused control is very likely to be
# invisible (inside a now-hidden tab) otherwise, leaving gamepad/keyboard navigation stuck.
func _grab_default_focus() -> void:
	var current_tab_control := tab_container.get_current_tab_control()
	if current_tab_control == null:
		return
	var focusable := _find_first_focusable(current_tab_control)
	if focusable:
		focusable.grab_focus()


func _find_first_focusable(node : Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_first_focusable(child)
		if found:
			return found
	return null


# Just refreshes each existing slot's data in place - the grid itself is built once by
# _create_item_slots() below, since the slot count never changes at runtime. Rebuilding from
# scratch on every inventory change used to free and reinstantiate every slot's Button, silently
# dropping controller focus mid-session the moment anything in the inventory changed (picking an
# item up, equipping something, anything that fires InventoryManager.updated_inventory).
func update_inventory_ui():
	for i in range(_item_slot_nodes.size()):
		var slot_data = InventoryManager.item_slots[i]
		_item_slot_nodes[i].set_slot_data(slot_data["item"], slot_data["quantity"])
	# Owned utility quantities (and which utility items exist at all) can change on any inventory
	# update, not just when the equipped one changes - covered separately by its own
	# equipped_utility_changed connection in _ready().
	refresh_utility_ui()


# Utility is a list of everything owned rather than a single equipped slot, since the game already
# lets the player cycle through every owned utility item during play (see cycle_utility() on
# InventoryManager) - a single-slot picker like the weapon/cosmetic slots would have implied only
# one could ever be carried at a time. The currently active one (equip_utility()'s target - which
# item cycling actually lands on) is just highlighted in the list, not a separate concept.
func refresh_utility_ui():
	for child in utility_list_container.get_children():
		child.queue_free()

	var owned_utility_items : Array = InventoryManager.get_owned_items_by_type(UtilityItemData)
	var equipped : ItemData = InventoryManager.get_equipped_utility()

	if owned_utility_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("No utility items owned yet.")
		empty_label.add_theme_font_override("font", BOUNTY_LIST_FONT)
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		utility_list_container.add_child(empty_label)
		return

	for item in owned_utility_items:
		var row := Label.new()
		row.text = "%s x%d" % [tr(item.display_name), InventoryManager.get_owned_quantity(item)]
		row.add_theme_font_override("font", BOUNTY_LIST_FONT)
		row.add_theme_font_size_override("font_size", 24)
		if item == equipped:
			# Same accent used for a focused slot elsewhere in this UI, so "currently active for
			# use" reads consistently with the rest of the screen.
			row.modulate = Color(0.960784, 0.615686, 0.156863)
		utility_list_container.add_child(row)


func _create_item_slots() -> void:
	for slot_data in InventoryManager.item_slots:
		var slot = item_slot_scene.instantiate()
		item_grid.add_child(slot)
		slot.set_slot_data(slot_data["item"], slot_data["quantity"])
		slot.selected.connect(_on_item_slot_selected)
		_item_slot_nodes.append(slot)

	_wire_item_grid_focus_neighbors(_item_slot_nodes)


# Shows whichever item was just focused/pressed - including null, for an empty slot, which blanks
# the panel out entirely rather than leaving stale info from whatever was selected before it.
func _on_item_slot_selected(item : ItemData) -> void:
	if item == null:
		item_name_label.text = ""
		item_description_label.text = ""
		item_information_icon.texture = null
		return

	item_name_label.text = tr(item.display_name)
	item_description_label.text = tr(item.description)
	item_information_icon.texture = item.icon


# Same reasoning as _wire_loadout_focus_neighbors() below - Godot's automatic focus-neighbor
# search is geometric and unreliable across a wide (10-column) grid, so up/down/left/right gets
# wired explicitly from each slot's known row/column instead. Only needs to run once, here, since
# the grid is no longer torn down and rebuilt on every inventory change.
func _wire_item_grid_focus_neighbors(slots : Array) -> void:
	var columns : int = item_grid.columns
	if slots.is_empty() or columns <= 0:
		return

	var row : Array = []
	for i in range(slots.size()):
		row.append(slots[i].get_node("Button"))
		if (i + 1) % columns == 0 or i == slots.size() - 1:
			_link_row(row)
			row = []

	for col in range(columns):
		var column : Array = []
		var i := col
		while i < slots.size():
			column.append(slots[i].get_node("Button"))
			i += columns
		_link_column(column)


func _on_bounty_state_changed(_data = null):
	create_bounty_ui()


# Objective/stage progress keeps whichever bounty is open on screen rather than resetting the
# panel to "Select a bounty" - the player is most likely reading the page it just changed.
func _on_bounty_objective_changed(bounty : BountyData, _detail = null):
	create_bounty_ui()
	if bounty != null:
		_on_bounty_entry_selected(bounty)


func create_bounty_ui():
	for child in bounty_list_container.get_children():
		child.queue_free()

	bounty_title_label.text = tr("Select a bounty")
	bounty_status_label.text = ""
	bounty_description_label.text = ""
	bounty_detail_icon.texture = default_bounty_icon
	bounty_detail_icon.self_modulate = Color.WHITE

	for region in GameStateManager.regions:
		var header := Label.new()
		header.text = tr(region.name) if region.unlocked else (tr(region.name) + " (" + tr("Locked") + ")")
		header.add_theme_font_override("font", BOUNTY_LIST_FONT)
		header.add_theme_font_size_override("font_size", 28)
		header.modulate = Color(1, 1, 1) if region.unlocked else Color(0.6, 0.6, 0.6)
		bounty_list_container.add_child(header)

		# Only what has actually been posted to the player. A bounty they haven't been given yet is
		# left off the page entirely rather than listed greyed-out: a name on the journal is how they
		# find out a job exists, so showing the ones still to come gives away what's coming.
		var region_bounties : Array[BountyData] = []
		for bounty in GameStateManager.get_bounties_for_region(region.id):
			if bounty.unlocked:
				region_bounties.append(bounty)

		if region_bounties.is_empty():
			var empty_label := Label.new()
			empty_label.text = tr("No bounties posted yet.")
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
	bounty_title_label.text = tr(bounty.title)
	bounty_status_label.text = tr(bounty.get_status_text())
	bounty_description_label.text = _build_bounty_details(bounty)
	bounty_detail_icon.texture = bounty.icon if bounty.icon else default_bounty_icon
	bounty_detail_icon.self_modulate = Color.WHITE if bounty.completed else Color.BLACK


# The reward, then the description, then the stages with their objectives ticked off. Written into
# the existing description label rather than built out of nodes: it is a checklist of a dozen short
# lines, and text keeps it wrapping and scrolling the way the panel already handles.
func _build_bounty_details(bounty : BountyData) -> String:
	var sections : Array[String] = []

	if bounty.reward_dollars > 0:
		sections.append(tr("Reward: $%d") % bounty.reward_dollars)

	if bounty.description != "":
		sections.append(tr(bounty.description))

	var checklist := _build_stage_checklist(bounty)
	if checklist != "":
		sections.append(checklist)

	if sections.is_empty():
		return tr("No details available yet.")
	return "

".join(sections)


func _build_stage_checklist(bounty : BountyData) -> String:
	if bounty.stages.is_empty():
		return ""

	var current_stage := bounty.get_current_stage()
	var lines : Array[String] = []
	for i in bounty.stages.size():
		var stage : BountyStageData = bounty.stages[i]
		# A stage the player hasn't reached yet is named but not itemised - the objectives of a leg
		# they haven't started would give away beats they should be walking into.
		var reached : bool = stage.is_complete() or stage == current_stage
		lines.append("%s %d. %s" % [_marker(stage.is_complete(), stage == current_stage), i + 1, tr(stage.title)])
		if not reached:
			continue
		for objective in stage.objectives:
			lines.append("     %s %s" % [_marker(objective.completed, false), tr(objective.text)])

	return "
".join(lines)


# Plain text markers rather than icons, since this is one label - done, in hand, not started yet.
func _marker(is_done : bool, is_current : bool) -> String:
	if is_done:
		return "[x]"
	if is_current:
		return "[>]"
	return "[ ]"


func _on_quest_state_changed(_data = null):
	create_quests_ui()


func create_quests_ui():
	for child in quest_list_container.get_children():
		child.queue_free()
	_quest_section_headers.clear()

	var in_progress_quests : Array[QuestData] = []
	var completed_quests : Array[QuestData] = []
	for quest in QuestManager.received_quests:
		if QuestManager.is_completed(quest):
			completed_quests.append(quest)
		else:
			in_progress_quests.append(quest)

	_add_quest_section("in_progress", tr("In Progress"), in_progress_quests)
	_add_quest_section("completed", tr("Completed"), completed_quests)


func _add_quest_section(section_key : String, section_title : String, quests : Array[QuestData]) -> void:
	var expanded : bool = _quest_section_expanded.get(section_key, true)

	var header := Button.new()
	header.text = ("▼  " if expanded else "▶  ") + section_title + " (%d)" % quests.size()
	header.add_theme_font_override("font", BOUNTY_LIST_FONT)
	header.add_theme_font_size_override("font_size", 24)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.pressed.connect(func():
		_quest_section_expanded[section_key] = !expanded
		create_quests_ui()
		_quest_section_headers[section_key].grab_focus()
	)
	quest_list_container.add_child(header)
	_quest_section_headers[section_key] = header

	if !expanded:
		return

	if quests.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("None yet.")
		empty_label.add_theme_font_override("font", BOUNTY_LIST_FONT)
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		quest_list_container.add_child(empty_label)
		return

	for quest in quests:
		var entry = quest_entry_scene.instantiate()
		quest_list_container.add_child(entry)
		entry.set_quest_data(quest)


func refresh_loadout_ui():
	slot_primary.set_item(InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.PRIMARY))
	slot_secondary.set_item(InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.SECONDARY))
	slot_ammo_primary.set_item(InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.PRIMARY))
	slot_ammo_secondary.set_item(InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.SECONDARY))
	slot_hat.set_item(InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.HAT))
	slot_outfit.set_item(InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.OUTFIT))
	slot_weapon_skin_primary.set_item(InventoryManager.get_equipped_weapon_skin(InventoryManager.WeaponSlot.PRIMARY))
	slot_weapon_skin_secondary.set_item(InventoryManager.get_equipped_weapon_skin(InventoryManager.WeaponSlot.SECONDARY))
	slot_accessory.set_item(InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.ACCESSORY))


# Godot's automatic focus-neighbor search (used everywhere else in this UI) is a geometric
# heuristic and doesn't reliably cover this tab's 2-column grid, leaving some slots unreachable
# by keyboard/gamepad - so the Loadout tab gets its neighbors wired explicitly instead.
func _wire_loadout_focus_neighbors() -> void:
	var b_primary := slot_primary.button
	var b_secondary := slot_secondary.button
	var b_ammo_primary := slot_ammo_primary.button
	var b_ammo_secondary := slot_ammo_secondary.button
	var b_weapon_skin_primary := slot_weapon_skin_primary.button
	var b_weapon_skin_secondary := slot_weapon_skin_secondary.button
	var b_hat := slot_hat.button
	var b_outfit := slot_outfit.button
	var b_accessory := slot_accessory.button

	_link_row([b_primary, b_secondary])
	_link_row([b_ammo_primary, b_ammo_secondary])
	_link_row([b_weapon_skin_primary, b_weapon_skin_secondary])
	_link_row([b_hat, b_outfit, b_accessory])

	_link_column([b_primary, b_ammo_primary, b_weapon_skin_primary, b_hat])
	_link_column([b_secondary, b_ammo_secondary, b_weapon_skin_secondary, b_outfit])


func _link_row(buttons : Array) -> void:
	for i in range(buttons.size()):
		if i > 0:
			buttons[i].focus_neighbor_left = buttons[i].get_path_to(buttons[i - 1])
		if i < buttons.size() - 1:
			buttons[i].focus_neighbor_right = buttons[i].get_path_to(buttons[i + 1])


func _link_column(buttons : Array) -> void:
	for i in range(buttons.size()):
		if i > 0:
			buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[i - 1])
		if i < buttons.size() - 1:
			buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[i + 1])


func refresh_abilities_ui():
	for child in abilities_list_container.get_children():
		child.queue_free()

	var unlocked_abilities : Array[AbilityData] = []
	for ability in AbilityManager.abilities:
		if AbilityManager.is_unlocked(ability.id):
			unlocked_abilities.append(ability)

	if unlocked_abilities.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("No abilities unlocked yet.")
		empty_label.add_theme_font_override("font", BOUNTY_LIST_FONT)
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		abilities_list_container.add_child(empty_label)
		return

	for ability in unlocked_abilities:
		var row := Label.new()
		row.text = ability.display_name
		row.add_theme_font_override("font", BOUNTY_LIST_FONT)
		row.add_theme_font_size_override("font_size", 24)
		row.modulate = Color(0.45, 0.85, 0.45)
		abilities_list_container.add_child(row)


func _open_weapon_picker(slot : InventoryManager.WeaponSlot):
	var candidates : Array = InventoryManager.get_owned_items_by_type(WeaponItemData)
	# The primary weapon always has to be something - Gun.gd guarantees a default is equipped,
	# so going without one isn't a state the player can choose here.
	var allow_unequip := slot != InventoryManager.WeaponSlot.PRIMARY
	_open_picker(candidates, InventoryManager.get_equipped_weapon(slot), func(item): InventoryManager.equip_weapon(slot, item), allow_unequip)


func _open_ammo_picker(slot : InventoryManager.WeaponSlot):
	var candidates : Array = InventoryManager.get_owned_items_by_type(AmmoItemData)
	var allow_unequip := slot != InventoryManager.WeaponSlot.PRIMARY
	_open_picker(candidates, InventoryManager.get_equipped_ammo(slot), func(item): InventoryManager.equip_ammo(slot, item), allow_unequip)


func _open_cosmetic_picker(slot : CosmeticItemData.CosmeticSlot):
	var candidates : Array[CosmeticItemData] = InventoryManager.get_owned_cosmetics_by_slot(slot)
	# The outfit slot always has a default outfit granted and equipped (see InventoryManager) -
	# every other cosmetic slot (hat, accessory) is fine going bare.
	var allow_unequip := slot != CosmeticItemData.CosmeticSlot.OUTFIT
	_open_picker(candidates, InventoryManager.get_equipped_cosmetic(slot), func(item):
		if item == null:
			InventoryManager.unequip_cosmetic(slot)
		else:
			InventoryManager.equip_cosmetic(item)
	, allow_unequip)


func _open_weapon_skin_picker(slot : InventoryManager.WeaponSlot):
	var candidates : Array[CosmeticItemData] = InventoryManager.get_owned_cosmetics_by_slot(CosmeticItemData.CosmeticSlot.WEAPON_SKIN)
	# A weapon always has some look even with no skin equipped, so that option reads as
	# "Default" rather than "None (unequip)".
	_open_picker(candidates, InventoryManager.get_equipped_weapon_skin(slot), func(item):
		if item == null:
			InventoryManager.unequip_weapon_skin(slot)
		else:
			InventoryManager.equip_weapon_skin(slot, item)
	, true, "Default")


func _open_picker(candidates : Array, current_item : ItemData, on_pick : Callable, allow_unequip : bool = true, none_label : String = "None (unequip)") -> void:
	_picker_on_pick = on_pick
	_picker_opener = get_viewport().gui_get_focus_owner()

	for child in picker_list_container.get_children():
		child.queue_free()

	var button_to_focus : Button = null

	if allow_unequip:
		var none_entry = picker_entry_scene.instantiate()
		picker_list_container.add_child(none_entry)
		none_entry.set_item_data(null, none_label)
		none_entry.selected.connect(_on_picker_item_selected)
		button_to_focus = none_entry.button

	# Focuses whichever entry matches the item currently equipped in this slot, so reopening a
	# dropdown highlights the current choice; falls back to the first entry when unequipping
	# isn't an option here (so there's no "None" entry to default to instead).
	for candidate in candidates:
		var entry = picker_entry_scene.instantiate()
		picker_list_container.add_child(entry)
		entry.set_item_data(candidate)
		entry.selected.connect(_on_picker_item_selected)
		if candidate == current_item or button_to_focus == null:
			button_to_focus = entry.button

	item_picker.visible = true
	item_picker_backdrop.visible = true
	if button_to_focus:
		button_to_focus.grab_focus()


func _on_picker_item_selected(item : ItemData):
	_picker_on_pick.call(item)
	_close_picker()


# item_picker used to be a PopupPanel (a native Window), which meant gamepad input never
# reliably reached it - it's a plain embedded Control now, toggled the same way as every other
# part of this UI, with item_picker_backdrop standing in for the modal dimming/click-outside-
# to-close behavior a real popup would normally provide for free.
func _close_picker() -> void:
	item_picker.visible = false
	item_picker_backdrop.visible = false
	if _picker_opener and is_instance_valid(_picker_opener):
		_picker_opener.grab_focus()
	else:
		_grab_default_focus()
	_picker_opener = null

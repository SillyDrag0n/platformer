extends CanvasLayer

# The cheat panel behind the pause menu's DEBUG MODE button: hand yourself money, unlock an
# ability, open the map up - so a shop shelf or a later level can be tested without playing all
# the way up to it first.
#
# Every button goes through the ordinary manager API (CollectibleManager.give_pickup_award(),
# AbilityManager.unlock_ability(), InventoryManager.add_item(), ...) rather than writing manager
# state directly, so a debug grant fires exactly the signals a real one does and the HUD, the
# journal and the save file all react the way they normally would.
#
# Deliberately not localized, and deliberately built in code rather than out of authored nodes:
# it never reaches a player (pause_menu_screen.gd only shows the button that opens it in a debug
# build), and the ability list is read off AbilityManager so a newly authored ability turns up
# here on its own instead of this file going quietly stale.

# What the money buttons hand over. 50 is the small top-up for testing a single shop shelf, 500
# is "buy anything in town".
const MONEY_STEPS : Array[int] = [50, 500]

# Worth having in hand while testing, rather than the whole catalogue - both utility items, the
# second weapon, and the revolver upgrade that changes how reloading plays.
const GRANT_ITEMS := [
	preload("res://items/utility/dynamite.tres"),
	preload("res://items/utility/spirit.tres"),
	preload("res://items/weapons/shotgun.tres"),
	preload("res://items/weapons/attachements/speed_loader.tres"),
]

const SECTION_COLOR := Color(0.85, 0.7, 0.4)

@onready var state_label : Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/StateLabel
@onready var scroll_container : ScrollContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer
@onready var button_list : VBoxContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ButtonList
@onready var back_button : Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

# The buttons whose label depends on state this panel can itself change - an ability already
# unlocked, an item already at a full stack. Kept so refresh() can grey them out rather than
# leaving a button that looks live and quietly does nothing.
var _ability_buttons : Dictionary = {} # Button -> AbilityData
var _item_buttons : Dictionary = {} # Button -> ItemData


func _ready() -> void:
	_build_buttons()
	SettingsManager.apply_ui_scale(self)
	# Money and inventory can move while this is open (an "unlock all" press, a grant that fills a
	# stack), and the button that caused it isn't always the one whose label has to change.
	CollectibleManager.on_collectible_award_received.connect(_on_dollars_changed)
	InventoryManager.updated_inventory.connect(refresh)
	AbilityManager.ability_unlocked.connect(_on_ability_unlocked)
	refresh()
	_grab_default_focus()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()


# --- Building the list ---

func _build_buttons() -> void:
	_add_section("MONEY")
	for amount in MONEY_STEPS:
		_add_button("+ $%d" % amount, _give_dollars.bind(amount))

	_add_section("ABILITIES")
	for ability in AbilityManager.abilities:
		_ability_buttons[_add_button("", AbilityManager.unlock_ability.bind(ability))] = ability
	_add_button("Unlock All Abilities", _unlock_all_abilities)

	_add_section("ITEMS")
	for item in GRANT_ITEMS:
		_item_buttons[_add_button("", _give_item.bind(item))] = item

	_add_section("WORLD")
	_add_button("Unlock All Bounties", _unlock_all_bounties)
	_add_button("Unlock All Regions", _unlock_all_regions)

	_add_section("PLAYER")
	_add_button("Heal to Full", _heal_to_full)
	_add_button("Save Now", SaveManager.save_game)


func _add_section(title : String) -> void:
	if button_list.get_child_count() > 0:
		button_list.add_child(HSeparator.new())
	var label := Label.new()
	label.text = title
	label.modulate = SECTION_COLOR
	button_list.add_child(label)


func _add_button(text : String, action : Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	# Refreshed after the action rather than by each action itself, so no button can leave the
	# panel showing a stale count or an "Unlock" for something that has already happened.
	button.pressed.connect(refresh)
	# A ScrollContainer doesn't follow a focused child on its own - same fix as the settings
	# screen's control list (see settings_menu_screen.gd's _connect_scroll_follow()).
	button.focus_entered.connect(scroll_container.ensure_control_visible.bind(button))
	button_list.add_child(button)
	return button


# --- State ---

func refresh() -> void:
	state_label.text = "Dollars: %d    Health: %d/%d" % [CollectibleManager.total_award_amount, \
		HealthManager.current_health, HealthManager.max_health]

	for button in _ability_buttons:
		var ability : AbilityData = _ability_buttons[button]
		var unlocked : bool = AbilityManager.is_unlocked(ability.id)
		button.text = "%s (unlocked)" % ability.display_name if unlocked \
			else "Unlock %s" % ability.display_name
		button.disabled = unlocked

	for button in _item_buttons:
		var item : ItemData = _item_buttons[button]
		var owned : int = InventoryManager.get_owned_quantity(item)
		button.text = "Give %s (%d/%d)" % [item.display_name, owned, item.max_stack_size]
		button.disabled = owned >= item.max_stack_size


func _on_dollars_changed(_total : int) -> void:
	refresh()


func _on_ability_unlocked(_ability : AbilityData) -> void:
	refresh()


func _grab_default_focus() -> void:
	for child in button_list.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return
	back_button.grab_focus()


# --- What the buttons do ---

func _give_dollars(amount : int) -> void:
	CollectibleManager.give_pickup_award(amount)


func _give_item(item : ItemData) -> void:
	InventoryManager.add_item(item)


func _unlock_all_abilities() -> void:
	for ability in AbilityManager.abilities:
		AbilityManager.unlock_ability(ability)


func _unlock_all_bounties() -> void:
	for bounty in GameStateManager.bounties:
		GameStateManager.unlock_bounty(bounty.id)


func _unlock_all_regions() -> void:
	for region in GameStateManager.regions:
		GameStateManager.unlock_region(region.id)


func _heal_to_full() -> void:
	# Through increase_health() rather than set_health_max(): only this one emits on_health_changed,
	# so it is what actually moves the HUD's hearts.
	HealthManager.increase_health(HealthManager.max_health)


func _on_back_button_pressed() -> void:
	queue_free()

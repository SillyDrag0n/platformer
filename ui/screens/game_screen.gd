extends CanvasLayer

@onready var collectible_label = $MarginContainer/VBoxContainer/HBoxContainer/CollectibleLabel
@onready var swap_weapon_hint_label = $MarginContainer/VBoxContainer/SwapWeaponHintLabel

@onready var quest_popup = $QuestPopup
@onready var quest_popup_title_label = $QuestPopup/MarginContainer/VBoxContainer/TitleLabel
@onready var quest_popup_description_label = $QuestPopup/MarginContainer/VBoxContainer/DescriptionLabel
@onready var quest_popup_timer = $QuestPopup/Timer

@onready var utility_display = $UtilityDisplay
@onready var utility_icon = $UtilityDisplay/Icon
@onready var utility_quantity_label = $UtilityDisplay/QuantityLabel


func _ready():
	CollectibleManager.on_collectible_award_received.connect(on_collectible_award_received)
	InventoryManager.equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	InventoryManager.equipped_utility_changed.connect(_on_equipped_utility_changed)
	InventoryManager.updated_inventory.connect(_update_utility_display)
	QuestManager.quest_received.connect(_on_quest_received)
	_update_swap_weapon_hint()
	_update_utility_display()


func _on_quest_received(quest : QuestData) -> void:
	quest_popup_title_label.text = "Quest received: " + quest.title
	quest_popup_description_label.text = quest.description
	quest_popup.visible = true
	quest_popup_timer.start()


func _on_quest_popup_timer_timeout() -> void:
	quest_popup.visible = false


func on_collectible_award_received(total_award : int):
	collectible_label.text = str(total_award)


func _on_equipped_weapon_changed(_slot, _weapon):
	_update_swap_weapon_hint()


func _update_swap_weapon_hint():
	swap_weapon_hint_label.visible = InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.SECONDARY) != null


func _on_equipped_utility_changed(_utility : UtilityItemData):
	_update_utility_display()


func _update_utility_display():
	var item = InventoryManager.get_equipped_utility()
	utility_display.visible = item != null
	if item == null:
		return

	var quantity := InventoryManager.get_owned_quantity(item)
	utility_icon.texture = item.empty_icon if quantity <= 0 and item.empty_icon != null else item.icon
	utility_quantity_label.text = str(quantity)
	utility_quantity_label.visible = quantity > 1


func _on_pause_texture_button_pressed():
	GameManager.pause_game()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.pause_game()
		get_viewport().set_input_as_handled()

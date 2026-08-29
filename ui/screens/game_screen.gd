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

@onready var snake_grab_hint = $SnakeGrabHint
@onready var snake_grab_progress_bar = $SnakeGrabHint/MarginContainer/VBoxContainer/ProgressBar

@onready var action_hint : PanelContainer = $ActionHint
@onready var action_hint_label : Label = $ActionHint/MarginContainer/VBoxContainer/Label

var _hint_watch_action : StringName = &""
var _hint_showing := false


func _ready():
	CollectibleManager.on_collectible_award_received.connect(on_collectible_award_received)
	InventoryManager.equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	InventoryManager.equipped_utility_changed.connect(_on_equipped_utility_changed)
	InventoryManager.updated_inventory.connect(_update_utility_display)
	QuestManager.quest_received.connect(_on_quest_received)
	PlayerManager.snake_grab_started.connect(_on_snake_grab_started)
	PlayerManager.snake_grab_progress.connect(_on_snake_grab_progress)
	PlayerManager.snake_grab_ended.connect(_on_snake_grab_ended)
	_update_swap_weapon_hint()
	_update_utility_display()


func _on_snake_grab_started(jump_presses_required : int) -> void:
	snake_grab_progress_bar.max_value = jump_presses_required
	snake_grab_progress_bar.value = 0
	snake_grab_hint.modulate.a = 0.0
	snake_grab_hint.visible = true
	create_tween().tween_property(snake_grab_hint, "modulate:a", 1.0, 0.15)


func _on_snake_grab_progress(press_count : int, _jump_presses_required : int) -> void:
	snake_grab_progress_bar.value = press_count


func _on_snake_grab_ended() -> void:
	var tween := create_tween()
	tween.tween_property(snake_grab_hint, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): snake_grab_hint.visible = false)


func _on_quest_received(quest : QuestData) -> void:
	quest_popup_title_label.text = tr("Quest received: %s") % tr(quest.title)
	quest_popup_description_label.text = tr(quest.description)
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


func show_hint(watch_action : StringName, hint_text_format : String) -> void:
	if _hint_showing:
		return
	_hint_showing = true
	_hint_watch_action = watch_action
	var key_label := SettingsManager.get_joypad_binding_display_text(watch_action) \
		if GameInputEvents.controller_active else SettingsManager.get_binding_display_text(watch_action)
	action_hint_label.text = hint_text_format % key_label
	action_hint.modulate.a = 0.0
	action_hint.visible = true
	create_tween().tween_property(action_hint, "modulate:a", 1.0, 0.15)


func _dismiss_hint() -> void:
	_hint_showing = false
	var tween := create_tween()
	tween.tween_property(action_hint, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): action_hint.visible = false)


func _process(_delta : float) -> void:
	if _hint_showing and Input.is_action_just_pressed(_hint_watch_action):
		_dismiss_hint()


func _on_pause_texture_button_pressed():
	GameManager.pause_game()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.pause_game()
		get_viewport().set_input_as_handled()

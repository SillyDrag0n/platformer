extends CanvasLayer

@onready var continue_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var reset_save_confirm_dialog = $ResetSaveConfirmDialog


func _ready():
	SettingsManager.apply_ui_scale(self)
	continue_button.grab_focus()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_continue_button_pressed()
		get_viewport().set_input_as_handled()


func _on_continue_button_pressed():
	GameManager.continue_game()
	queue_free()


func _on_main_menu_button_pressed():
	GameManager.main_menu()
	queue_free()


func _on_reset_save_button_pressed():
	reset_save_confirm_dialog.popup_centered()


func _on_reset_save_confirm_dialog_confirmed():
	SaveManager.reset_save()


# Debug-only shortcut for testing the grapple without playing through the level(s) that normally
# grant it - unlock() is idempotent, so pressing this after it's already unlocked is a no-op.
func _on_unlock_grapple_button_pressed():
	AbilityManager.unlock("grapple_hook")
	_on_continue_button_pressed()

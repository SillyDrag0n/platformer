extends CanvasLayer

var settings_menu_screen = preload("res://ui/screens/settings_menu_screen.tscn")

@onready var play_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton
@onready var reset_save_confirm_dialog = $ResetSaveConfirmDialog


func _ready():
	SettingsManager.apply_ui_scale(self)
	play_button.grab_focus()


func _on_play_button_pressed():
	GameManager.start_game()
	queue_free()


func _on_exit_button_pressed():
	GameManager.exit_game()


func _on_settings_button_pressed():
	var settings_menu_screen_instance = settings_menu_screen.instantiate()
	get_tree().get_root().add_child(settings_menu_screen_instance)
	settings_menu_screen_instance.tree_exited.connect(play_button.grab_focus)


func _on_reset_save_button_pressed():
	reset_save_confirm_dialog.popup_centered()


func _on_reset_save_confirm_dialog_confirmed():
	SaveManager.reset_save()

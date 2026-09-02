extends CanvasLayer

@onready var respawn_button = $CenterContainer/PanelContainer/Margin/VBoxContainer/RespawnButton


func _ready():
	SettingsManager.apply_ui_scale(self)
	PlayerManager.player_died.connect(show_death_screen)


func show_death_screen():
	visible = true
	respawn_button.grab_focus()


func return_to_hub():
	visible = false
	SceneManager.transition_to_scene("Hub")


func exit_game():
	GameManager.exit_game()


func _on_respawn_button_pressed() -> void:
	visible = false
	RespawnManager.respawn()


func _on_hub_button_pressed() -> void:
	return_to_hub()


func _on_exit_button_pressed() -> void:
	exit_game()

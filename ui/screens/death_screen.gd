extends CanvasLayer

func _ready():
	PlayerManager.player_died.connect(show_death_screen)


func show_death_screen():
	visible = true


func return_to_hub():
	return


func exit_game():
	return


func _on_respawn_button_pressed() -> void:
	visible = false
	RespawnManager.respawn()


func _on_hub_button_pressed() -> void:
	return_to_hub()


func _on_exit_button_pressed() -> void:
	exit_game()

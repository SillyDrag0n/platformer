extends CanvasLayer

func _ready():
	for player in get_tree().get_nodes_in_group("Player"):
		player.PlayerDeath.connect(ShowDeathScreen)
		print("Death Screen connected")


func ShowDeathScreen():
	visible = true


func ReturnToHub():
	return


func ExitGame():
	return


func _on_respawn_button_pressed() -> void:
	visible = false
	RespawnManager.Respawn()


func _on_hub_button_pressed() -> void:
	ReturnToHub()


func _on_exit_button_pressed() -> void:
	ExitGame()

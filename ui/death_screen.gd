extends CanvasLayer

var player_scene = preload("res://player/player.tscn")

func _ready():
	for player in get_tree().get_nodes_in_group("Player"):
		player.PlayerDeath.connect(ShowDeathScreen)


func ShowDeathScreen():
	get_tree().paused = false

func Respawn():
	return

func ReturnToHub():
	return

func ExitGame():
	return
extends Node2D

func _ready():
	HealthManager.on_health_changed.connect(on_player_health_changed)


func on_player_health_changed(player_current_health : int):
	pass
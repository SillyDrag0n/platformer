extends Node2D
@onready var HealthBar = $HealthBar

func _ready():
	HealthManager.on_health_changed.connect(on_player_health_changed)
	PlayerManager.player_spawned.connect(ResetResourceUiOnRespawn)


func on_player_health_changed(player_current_health : float):
	var max_health = HealthManager.get_health_max()
	print((player_current_health / max_health) * 100)
	HealthBar.value = (player_current_health / max_health) * 100


func ResetResourceUiOnRespawn(_player):
	on_player_health_changed(HealthManager.current_health)

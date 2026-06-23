extends Node2D
@onready var health_bar = $HealthBar

func _ready():
	HealthManager.on_health_changed.connect(on_player_health_changed)
	PlayerManager.player_spawned.connect(reset_resource_ui_on_respawn)


func on_player_health_changed(player_current_health : float):
	var max_health = HealthManager.get_health_max()
	health_bar.value = (player_current_health / max_health) * 100


func reset_resource_ui_on_respawn(_player):
	on_player_health_changed(HealthManager.current_health)

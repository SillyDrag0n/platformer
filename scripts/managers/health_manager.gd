extends Node

var max_health : float = 3
var current_health : float
var invulnerable : bool
var damage_timer : Timer

signal on_health_changed
signal on_health_decreased


func _ready():
	current_health = max_health

	damage_timer = Timer.new()
	add_child(damage_timer)
	damage_timer.timeout.connect(_on_timer_timeout)
	damage_timer.one_shot = true
	damage_timer.wait_time = 1

	PlayerManager.player_spawned.connect(reset_health_manager)


func decrease_health(health_amount : float):
	if invulnerable:
		return

	invulnerable = true
	damage_timer.start()
	current_health -= health_amount

	if current_health < 0:
		current_health = 0

	on_health_changed.emit(current_health)
	on_health_decreased.emit()


func increase_health(health_amount : float):
	current_health += health_amount
	
	if current_health > max_health:
		current_health = max_health

	on_health_changed.emit(current_health)


func _on_timer_timeout():
	invulnerable = false


func set_health_max():
	current_health = max_health


func get_health_max():
	return max_health

func reset_health_manager(_player):
	set_health_max()
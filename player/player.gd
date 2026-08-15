extends CharacterBody2D

const DEADEYE_TIME_SCALE := 0.35

var player_death_effect = preload("res://player/player_death_effect/player_death_effect.tscn")

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var muzzle : Marker2D = $Muzzle

var is_invulnerable : bool = false

func _ready() -> void:
	PlayerManager.player = self
	PlayerManager.player_spawned.emit(self)


func _process(_delta) -> void:
	if AbilityManager.is_unlocked("deadeye") and GameInputEvents.deadeye_input():
		Engine.time_scale = DEADEYE_TIME_SCALE
	elif Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


func set_invulnerable(value : bool) -> void:
	is_invulnerable = value


func player_death():
	Engine.time_scale = 1.0
	var player_death_effect_instance = player_death_effect.instantiate() as Node2D
	player_death_effect_instance.global_position = global_position
	get_parent().add_child(player_death_effect_instance)
	PlayerManager.player_died.emit()
	queue_free()


func _on_hurtbox_body_entered(body : Node2D):
	if body.is_in_group("Enemy"):
		take_hit(body.damage_amount)


func _on_hurtbox_area_entered(area : Area2D) -> void:
	var source := area.get_parent()
	if source != null and source.has_method("get_damage_amount"):
		take_hit(source.get_damage_amount())


func take_hit(damage : int):
	if is_invulnerable:
		return
	flash_hit()
	HealthManager.decrease_health(damage)
	check_player_health()


func flash_hit():
	var tween = get_tree().create_tween()
	tween.tween_property(animated_sprite_2d, "material:shader_parameter/enabled", true, 0)
	tween.tween_property(animated_sprite_2d, "material:shader_parameter/enabled", false, 0.2)


func check_player_health():
	if HealthManager.current_health == 0:
		player_death()


func _exit_tree():
	Engine.time_scale = 1.0
	if PlayerManager.player == self:
		PlayerManager.player = null
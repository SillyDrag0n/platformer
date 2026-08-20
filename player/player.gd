extends CharacterBody2D

const DEADEYE_TIME_SCALE := 0.35

var player_death_effect = preload("res://player/player_death_effect/player_death_effect.tscn")

@onready var legs : AnimatedSprite2D = $Body/Legs
@onready var upper_body : AnimatedSprite2D = $Body/UpperBody
@onready var state_machine : NodeFiniteStateMachine = $StateMachine

var is_invulnerable : bool = false
var is_shooting : bool = false

func _ready() -> void:
	PlayerManager.player = self
	PlayerManager.player_spawned.emit(self)


func _process(_delta) -> void:
	if AbilityManager.is_unlocked("deadeye") and GameInputEvents.deadeye_input():
		Engine.time_scale = DEADEYE_TIME_SCALE
	elif Engine.time_scale != 1.0:
		Engine.time_scale = 1.0

	# Shooting is a plain state-independent flag now rather than living inside ground-only shoot
	# states - gated to Normal so Dash/Grapple/Hurt/Dead still can't fire, matching what those
	# states already never allowed.
	is_shooting = GameInputEvents.shoot_input() and state_machine.current_node_state.name.to_lower() == "normal"


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
	if HealthManager.current_health == 0:
		state_machine.transition_to("Dead")
	else:
		state_machine.transition_to("Hurt")


func flash_hit():
	var tween = get_tree().create_tween()
	tween.tween_property(legs, "material:shader_parameter/enabled", true, 0)
	tween.parallel().tween_property(upper_body, "material:shader_parameter/enabled", true, 0)
	tween.tween_property(legs, "material:shader_parameter/enabled", false, 0.2)
	tween.parallel().tween_property(upper_body, "material:shader_parameter/enabled", false, 0.2)


func _exit_tree():
	Engine.time_scale = 1.0
	if PlayerManager.player == self:
		PlayerManager.player = null
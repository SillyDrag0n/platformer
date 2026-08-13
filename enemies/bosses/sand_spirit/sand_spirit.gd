class_name BossStateController
extends CharacterBody2D

signal defeated

@export var finite_state_machine : NodeFiniteStateMachine
@export var animated_sprite : AnimatedSprite2D
@export var max_health : int = 9
@export var hover_speed := 200

@export var arena_left := 100
@export var arena_right := 900
@export var arena_top := 100
@export var arena_bottom := 350

const HIT_FLASH_SHADER: Shader = preload("res://player/player_hit_flash_shader.tres")

var enemy_death_effect = preload("res://enemies/_common/enemy_death_effect.tscn")
var health : int
var phase : int = 1
var rng := RandomNumberGenerator.new()
var hover_target: Vector2

enum Animations { AmbushAttack, Death, DustDevilAttack, Hidden, Hide, Idle, Intro, Move, PhaseTransition, ProjectileAttack }
var current_animation: Animations = Animations.Idle

var animation_map := {
	Animations.AmbushAttack: "ambushAttack",
	Animations.Death: "death",
	Animations.DustDevilAttack: "dustDevilAttack",
	Animations.Hidden: "hidden",
	Animations.Hide: "hide",
	Animations.Idle: "idle",
	Animations.Intro: "intro",
	Animations.Move: "move",
	Animations.PhaseTransition: "phaseTransition",
	Animations.ProjectileAttack: "projectileAttack",
}


func _ready():
	health = max_health
	rng.randomize()


func _physics_process(delta):
	move_and_slide()


func start_boss_fight():
	if finite_state_machine.current_node_state.name.to_lower() != "idle":
		return
	finite_state_machine.transition_to("intro")


func die():
	var enemy_death_effect_instance = enemy_death_effect.instantiate() as Node2D
	enemy_death_effect_instance.global_position = global_position
	get_parent().add_child(enemy_death_effect_instance)
	defeated.emit()
	queue_free()
	GameStateManager.complete_active_bounty()
	GameStateManager.give_bounty_reward()
	UiManager.open_bounty_completed_screen()


func _on_hurtbox_area_entered(area : Area2D):
	if area.get_parent().has_method("get_damage_amount"):
		var node = area.get_parent() as Node
		health -= node.damage_amount
		flash_hit()

		if health <= 0:
			finite_state_machine.transition_to("death")

		check_phase_change()


func flash_hit() -> void:
	if animated_sprite.material == null:
		var flash_material := ShaderMaterial.new()
		flash_material.shader = HIT_FLASH_SHADER
		animated_sprite.material = flash_material
	var tween = create_tween()
	tween.tween_property(animated_sprite, "material:shader_parameter/enabled", true, 0)
	tween.tween_property(animated_sprite, "material:shader_parameter/enabled", false, 0.2)


func check_phase_change():
	if health <= 0:
		return
	var previous_phase = phase

	if health < max_health * 0.66 and phase == 1:
		phase = 2

	elif health < max_health * 0.33 and phase == 2:
		phase = 3

	if phase != previous_phase and finite_state_machine != null:
		finite_state_machine.transition_to("PhaseTransition")


func play_animation(anim: Animations):
	if anim == current_animation:
		return
		
	if not animation_map.has(anim):
		push_error("Unknown animation: " + str(anim))
		return

	current_animation = anim
	var anim_name: String = animation_map[anim]
	animated_sprite.play(anim_name)

class_name BossStateController
extends CharacterBody2D

@export var finite_state_machine : NodeFiniteStateMachine
@export var animated_sprite : AnimatedSprite2D
@export var max_health : int = 60
@export var hover_speed := 200

@export var arena_left := 100
@export var arena_right := 900
@export var arena_top := 100
@export var arena_bottom := 350

var enemy_death_effect = preload("res://enemies/_common/enemy_death_effect.tscn")
var health : int
var phase : int = 1
var phase_started : bool = true
var rng := RandomNumberGenerator.new()
var hover_target: Vector2
var current_state: NodeState
var ready_to_attack: bool = true

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


#func _on_boss_arena_entered(body:Node2D) -> void:
#	if body.is_in_group("Player"):
#		start_boss_fight()


# func start_boss_fight():
# 	finite_state_machine.transition_to("intro")


func die():
	GameStateManager.complete_active_bounty()
	var enemy_death_effect_instance = enemy_death_effect.instantiate() as Node2D
	enemy_death_effect_instance.global_position = global_position
	get_parent().add_child(enemy_death_effect_instance)
	queue_free()


func _on_hurtbox_area_entered(area : Area2D):
	if area.get_parent().has_method("get_damage_amount"):
		var node = area.get_parent() as Node
		health -= node.damage_amount
		print(health)
		
		if health <= 0:
			finite_state_machine.transition_to("death")
			pass

		check_phase_change()


func check_phase_change():
	if health <= 0:
		pass

	if health < max_health * 0.66 and phase == 1:
		phase = 2
		phase_started = true
		print("Phase 2")

	elif health < max_health * 0.33 and phase == 2:
		phase = 3
		phase_started = true
		print("Phase 3")


func play_animation(anim: Animations):
	if anim == current_animation:
		return
		
	if not animation_map.has(anim):
		push_error("Unknown animation: " + str(anim))
		return

	current_animation = anim
	var anim_name: String = animation_map[anim]
	animated_sprite.play(anim_name)

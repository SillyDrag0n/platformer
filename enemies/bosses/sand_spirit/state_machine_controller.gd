extends Node

@export var node_finite_state_machine : NodeFiniteStateMachine
@export var boss : CharacterBody2D
@export var move_state : NodeState
@export var projectile_attack_state : NodeState
@export var dust_devil_attack_state : NodeState
@export var ambush_attack_state : NodeState
@export var cooldown_state : NodeState

var last_attack = ""

func _ready():
	# HOVER → ATTACK
	move_state.attack_requested.connect(_on_attack_requested)

	# ATTACK → COOLDOWN
	projectile_attack_state.finished.connect(_on_attack_finished)
	dust_devil_attack_state.finished.connect(_on_attack_finished)

	# COOLDOWN → HOVER
	cooldown_state.finished.connect(func(): node_finite_state_machine.transition_to("Move"))

	# AMBUSH → COOLDOWN
	ambush_attack_state.finished.connect(func(): node_finite_state_machine.transition_to("Cooldown"))


func _on_attack_requested():

	var next = choose_attack()
	node_finite_state_machine.transition_to(next)


func _on_attack_finished():
	node_finite_state_machine.transition_to("Cooldown")


func choose_attack():

	var attacks = []

	if boss.phase == 1:
		attacks = ["ProjectileAttack"]
	else:
		attacks = ["ProjectileAttack", "DustDevilAttack"]

	var choice = attacks.pick_random()

	while choice == last_attack and attacks.size() > 1:
		choice = attacks.pick_random()

	last_attack = choice
	return choice

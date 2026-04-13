extends NodeState

@export var boss: CharacterBody2D

var last_attack = ""

func enter():
	pass

func physics_update(_delta):

	var attacks = []

	if boss.phase == 1:
		attacks = ["AttackShoot"]
	else:
		attacks = ["AttackShoot", "AttackDust"]

	var choice = pick_attack(attacks)
	return choice

func pick_attack(attacks):

	var choice = attacks.pick_random()

	while choice == last_attack and attacks.size() > 1:
		choice = attacks.pick_random()

	last_attack = choice
	return choice
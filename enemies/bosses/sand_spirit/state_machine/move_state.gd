extends NodeState

@export var Boss: CharacterBody2D

signal attack_requested

var attack_timer

func enter():
	pick_new_target()
	attack_timer = randf_range(2.0, 4.0) / Boss.phase

func on_physics_process(delta):

	# Movement
	var direction = (Boss.hover_target - Boss.global_position).normalized()
	Boss.velocity = direction * Boss.hover_speed

	if Boss.global_position.distance_to(Boss.hover_target) < 20:
		pick_new_target()

	# Attack trigger
	attack_timer -= delta
	if attack_timer <= 0:
		attack_requested.emit()   # ← ONLY SIGNAL

func pick_new_target():
	Boss.hover_target = Vector2(
		randf_range(Boss.arena_left, Boss.arena_right),
		randf_range(Boss.arena_top, Boss.arena_bottom)
	)
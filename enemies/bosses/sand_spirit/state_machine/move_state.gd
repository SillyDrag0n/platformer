extends NodeState

@export var boss: BossStateController

signal attack_requested

var attack_timer

func enter():
	pick_new_target()
	attack_timer = randf_range(2.0, 4.0) / boss.phase
	boss.play_animation(boss.Animations.Move)

func on_physics_process(delta):

	# Movement
	var direction = (boss.hover_target - boss.global_position).normalized()
	boss.velocity = direction * boss.hover_speed

	if boss.global_position.distance_to(boss.hover_target) < 20:
		pick_new_target()

	# Attack trigger
	attack_timer -= delta
	if attack_timer <= 0:
		attack_requested.emit()   # ← ONLY SIGNAL

func pick_new_target():
	boss.hover_target = Vector2(
		randf_range(boss.arena_left, boss.arena_right),
		randf_range(boss.arena_top, boss.arena_bottom)
	)

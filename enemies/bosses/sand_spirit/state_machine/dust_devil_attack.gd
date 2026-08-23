extends NodeState

@export var boss: BossStateController

signal finished

const WARNING_DURATION := 0.7

var dust_devil_scene = preload("res://enemies/bosses/sand_spirit/dust_devil.tscn")
var dust_devil_warning_scene = preload("res://enemies/bosses/sand_spirit/dust_devil_warning.tscn")

func enter():
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.DustDevilAttack)
	spawn_dust_devils(boss.phase)

func spawn_dust_devils(count):
	if count < 2:
		count = 2

	# Spawn dust devils at the arena edges on the ground and have them move inward
	var left_x = boss.arena_left
	var right_x = boss.arena_right
	var ground_y = boss.arena_bottom
	var center_x = (left_x + right_x) * 0.5

	var spawns := []
	for i in range(count):
		var side = boss.rng.randi_range(0, 1) # 0 = left, 1 = right
		var spawn_x = left_x if side == 0 else right_x
		# place slightly above the ground so the dust devil appears visibly in the arena
		var spawn_pos = Vector2(spawn_x + (10 if side == 0 else -10), ground_y - 32)
		var direction_x = signf(center_x - spawn_pos.x)
		spawns.append([spawn_pos, direction_x])

		var warning = dust_devil_warning_scene.instantiate() as Node2D
		warning.global_position = spawn_pos
		ProjectileLayer.spawn(warning)

	await get_tree().create_timer(WARNING_DURATION).timeout

	for spawn in spawns:
		var dust_devil = dust_devil_scene.instantiate() as Node2D
		dust_devil.global_position = spawn[0]
		dust_devil.direction = Vector2(spawn[1], 0)
		dust_devil.damage_amount = 1
		dust_devil.speed = 120 + boss.phase * 20
		dust_devil.life_time = 3.0 + boss.phase * 1.5
		ProjectileLayer.spawn(dust_devil)

	finished.emit()

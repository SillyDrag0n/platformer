extends NodeState

@export var boss: BossStateController

signal finished

var dust_devil_scene = preload("res://enemies/bosses/sand_spirit/dust_devil.tscn")

func enter():
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.DustDevilAttack)
	spawn_dust_devils(boss.phase)
	finish_next_frame()

func finish_next_frame():
	await get_tree().process_frame
	finished.emit()

func spawn_dust_devils(count):
	if count < 2:
		count = 2

	var target_position = boss.global_position + Vector2(0, 150)
	if PlayerManager.player != null:
		target_position = PlayerManager.player.global_position

	for i in range(count):
		var dust_devil = dust_devil_scene.instantiate() as Node2D
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		dust_devil.global_position = boss.global_position + offset
		var aim_position = target_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		dust_devil.direction = (aim_position - dust_devil.global_position).normalized()
		dust_devil.damage_amount = 1
		dust_devil.speed = 160 + (count - 2) * 40
		dust_devil.life_time = 4.5 + count * 0.5
		boss.get_parent().add_child(dust_devil)

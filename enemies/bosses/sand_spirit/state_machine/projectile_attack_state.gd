extends NodeState

@export var boss: BossStateController

signal finished

var projectile_scene = preload("res://enemies/bosses/sand_spirit/sand_spirit_projectile.tscn")

func enter():
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.ProjectileAttack)
	shoot()
	finish_next_frame()
	
func shoot():
	var shots = [Vector2(-28, 24), Vector2(0, 32), Vector2(28, 24)]
	for offset in shots:
		var projectile = projectile_scene.instantiate() as Node2D
		projectile.global_position = boss.global_position + offset
		projectile.direction = (PlayerManager.player.global_position - projectile.global_position).normalized()
		projectile.damage_amount = 1
		projectile.speed = 320
		boss.get_parent().add_child(projectile)

func finish_next_frame():
	await get_tree().process_frame
	finished.emit()

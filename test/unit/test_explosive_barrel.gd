extends GutTest

# The explosive barrel (levels/_common/explosive_barrel/) and the blast it shares with the player's
# dynamite (scripts/explosion.gd). The chain reaction is the part worth pinning down: two barrels
# inside each other's radius set each other off, and the fuse guard is the only thing stopping that
# from recursing forever the first time someone places a pair of them close together.

const BarrelScene = preload("res://levels/_common/explosive_barrel/explosive_barrel.tscn")
const Explosion = preload("res://scripts/explosion.gd")


func _make_barrel(position : Vector2 = Vector2.ZERO) -> StaticBody2D:
	var barrel := BarrelScene.instantiate() as StaticBody2D
	barrel.global_position = position
	add_child_autofree(barrel)
	return barrel


func test_a_barrel_is_solid_and_explosive():
	var barrel := _make_barrel()
	await wait_frames(1)

	assert_true(barrel.is_in_group(Explosion.EXPLOSIVE_GROUP), \
		"a barrel has to be in the Explosive group or nothing else's blast can find it to chain")
	assert_eq(barrel.collision_layer, 1, \
		"the barrel body sits on Ground so it blocks the player and stops bullets")
	assert_true(barrel.has_method("take_damage"), \
		"Explosion's chain step damages whatever it finds, so the barrel has to accept damage")


func test_shooting_a_barrel_lights_its_fuse_rather_than_going_off_on_the_spot():
	var barrel := _make_barrel()
	await wait_frames(1)

	barrel.take_damage(barrel.health_amount)

	assert_true(is_instance_valid(barrel), \
		"the barrel survives the hit that kills it - the fuse is what gives the player a beat " + \
		"to get clear of one they shot from too close")


func test_a_barrel_goes_off_once_its_fuse_burns_down():
	var barrel := _make_barrel()
	barrel.fuse_time = 0.05
	await wait_frames(1)

	barrel.take_damage(barrel.health_amount)
	await wait_seconds(0.4)

	assert_false(is_instance_valid(barrel), "the fuse has to actually end in an explosion")


func test_a_barrel_in_range_is_set_off_by_another_blast():
	var lit := _make_barrel(Vector2.ZERO)
	var neighbour := _make_barrel(Vector2(40, 0))
	neighbour.fuse_time = 0.05
	await wait_frames(1)

	Explosion.detonate(lit, 4, 88.0)
	await wait_seconds(0.4)

	assert_false(is_instance_valid(neighbour), \
		"a barrel 40px from an 88px blast is well inside it and has to go off in turn")


func test_a_barrel_out_of_range_is_left_alone():
	var lit := _make_barrel(Vector2.ZERO)
	var far_away := _make_barrel(Vector2(400, 0))
	await wait_frames(1)

	Explosion.detonate(lit, 4, 88.0)
	await wait_seconds(0.4)

	assert_true(is_instance_valid(far_away), \
		"a barrel in the next room over is not part of the chain")


# The regression this whole design exists to avoid: A sets off B, B's blast reaches back to A.
# Without the guard in take_damage()/light_fuse() that is unbounded recursion, and the test
# process dies rather than failing an assertion.
func test_two_barrels_in_range_of_each_other_do_not_chain_forever():
	var first := _make_barrel(Vector2.ZERO)
	var second := _make_barrel(Vector2(30, 0))
	first.fuse_time = 0.05
	second.fuse_time = 0.05
	await wait_frames(1)

	first.take_damage(first.health_amount)
	await wait_seconds(0.6)

	assert_false(is_instance_valid(first), "the barrel that was shot goes off")
	assert_false(is_instance_valid(second), "and takes its neighbour with it, exactly once each")


# A bandit is deliberately the enemy under test here rather than a cactus: bandits are not in the
# "Enemy" group (that group is player.gd's contact-damage check, and a bandit does its damage by
# shooting), so a blast that went looking for the group instead of the Enemy physics layer used to
# miss them entirely. Given plenty of health so this measures the hit landing, not lethality.
func test_the_blast_damages_enemies_it_reaches():
	var barrel := _make_barrel(Vector2.ZERO)
	var enemy := preload("res://enemies/bandit/bandit.tscn").instantiate()
	enemy.global_position = Vector2(30, 0)
	add_child_autofree(enemy)
	enemy.health_amount = 20
	await wait_physics_frames(2)

	Explosion.detonate(barrel, 4, 88.0)
	await wait_physics_frames(1)

	assert_eq(enemy.health_amount, 16, \
		"an enemy standing next to a barrel that goes off has to actually take the hit")

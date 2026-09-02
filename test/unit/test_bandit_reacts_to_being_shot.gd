extends GutTest

# The bandit's state machine is driven entirely off his AggroRange and AttackRange areas, so
# nothing about taking a bullet ever reached it. A player shooting from beyond that range could
# empty a cylinder into a bandit who went on idling.
#
# AggroRange is a 800x250 box, so he notices nobody past 400px to either side - nor anyone more
# than 125px above or below him, which a player on a ledge clears easily. The tests below stand
# the player at 700px, well outside it.

const BanditScene = preload("res://enemies/bandit/bandit.tscn")
const PlayerScene = preload("res://player/player.tscn")


func _make_bandit() -> Enemy:
	var bandit = BanditScene.instantiate()
	add_child_autofree(bandit)
	await wait_physics_frames(2)
	return bandit


func _state_of(bandit) -> String:
	return bandit.state_machine.current_node_state.name.to_lower()


func test_he_starts_out_idle():
	var bandit = await _make_bandit()
	assert_eq(_state_of(bandit), "idle", "sanity: nothing has disturbed him yet")


func test_a_hit_sets_him_after_the_player_he_can_see():
	var bandit = await _make_bandit()
	var player = PlayerScene.instantiate()
	player.position = bandit.global_position + Vector2(700, 0)
	add_child_autofree(player)
	await wait_physics_frames(2)

	bandit.take_damage(1)
	await wait_physics_frames(1)

	assert_eq(_state_of(bandit), "chase", \
		"shot from beyond his aggro range, with a clear line to the player, he comes after them")
	assert_true(bandit.is_chasing, "and chasing is what actually walks him over")


func test_he_does_not_learn_where_the_player_is_through_a_wall():
	var bandit = await _make_bandit()
	var player = PlayerScene.instantiate()
	player.position = bandit.global_position + Vector2(700, 0)
	add_child_autofree(player)

	# A slab of Ground straight between the two of them.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = bandit.global_position + Vector2(350, 0)
	add_child_autofree(wall)
	await wait_physics_frames(2)

	assert_false(bandit.can_see_player(), "sanity: the wall is between them")

	bandit.take_damage(1)
	await wait_physics_frames(1)

	assert_eq(_state_of(bandit), "idle", \
		"shot from behind cover he has nothing to walk towards, and should not magically know")


func test_being_shot_mid_fight_does_not_interrupt_him():
	var bandit = await _make_bandit()
	var player = PlayerScene.instantiate()
	player.position = bandit.global_position + Vector2(700, 0)
	add_child_autofree(player)
	await wait_physics_frames(2)
	bandit.state_machine.transition_to("Attack")
	await wait_physics_frames(1)

	bandit.take_damage(1)
	await wait_physics_frames(1)

	assert_eq(_state_of(bandit), "attack", \
		"a bandit already shooting back is busy - a hit should not drop him into a walk")


func test_the_killing_blow_does_not_wake_a_dead_man():
	var bandit = await _make_bandit()
	var player = PlayerScene.instantiate()
	player.position = bandit.global_position + Vector2(700, 0)
	add_child_autofree(player)
	await wait_physics_frames(2)

	bandit.take_damage(bandit.health_amount)

	assert_true(bandit.is_queued_for_deletion(), "that hit killed him")

extends GutTest

# The bandit ducks into cover while reloading (enemies/bandit/state_machine/reload_state.gd). Both
# of its capsules have to duck with the pose: the hurtbox, so it can't be shot as if standing tall,
# and the body, so it doesn't keep taking up standing room the player then can't jump over. Both
# shrink from the top with the bottom edge left alone - a body that dropped instead would put his
# feet through the floor.

const BanditScene = preload("res://enemies/bandit/bandit.tscn")


func _make_bandit() -> CharacterBody2D:
	var bandit = BanditScene.instantiate()
	add_child_autofree(bandit)
	return bandit


func _bottom_edge(shape : CollisionShape2D) -> float:
	return shape.position.y + shape.shape.height * 0.5


func test_ducking_shrinks_the_body_collision_and_leaves_his_feet_where_they_were():
	var bandit := _make_bandit()
	await wait_physics_frames(1)

	var body : CollisionShape2D = bandit.get_node("CollisionShape2D")
	var standing_height : float = body.shape.height
	var standing_bottom : float = _bottom_edge(body)

	bandit.get_node("StateMachine").transition_to("Reload")
	await wait_physics_frames(1)

	assert_lt(body.shape.height, standing_height, \
		"the body capsule ducks with the pose, so a bandit in cover really is shorter")
	assert_almost_eq(_bottom_edge(body), standing_bottom, 0.5, \
		"and it shrinks from the top - dropping the whole capsule would push his feet into " + \
		"the floor")


func test_the_hurtbox_ducks_with_him_too():
	var bandit := _make_bandit()
	await wait_physics_frames(1)

	var hurtbox : CollisionShape2D = bandit.get_node("Hurtbox/CollisionShape2D")
	var standing_height : float = hurtbox.shape.height

	bandit.get_node("StateMachine").transition_to("Reload")
	await wait_physics_frames(1)

	assert_lt(hurtbox.shape.height, standing_height, \
		"he shouldn't still be hittable as if standing while he's visibly behind cover")


func test_standing_back_up_restores_both_capsules():
	var bandit := _make_bandit()
	await wait_physics_frames(1)

	var body : CollisionShape2D = bandit.get_node("CollisionShape2D")
	var hurtbox : CollisionShape2D = bandit.get_node("Hurtbox/CollisionShape2D")
	var standing_body_height : float = body.shape.height
	var standing_body_position : Vector2 = body.position
	var standing_hurtbox_height : float = hurtbox.shape.height

	bandit.get_node("StateMachine").transition_to("Reload")
	await wait_physics_frames(1)
	bandit.get_node("StateMachine").transition_to("Attack")
	await wait_physics_frames(1)

	assert_eq(body.shape.height, standing_body_height, "the body comes back up with him")
	assert_eq(body.position, standing_body_position)
	assert_eq(hurtbox.shape.height, standing_hurtbox_height)


func test_one_bandit_ducking_does_not_duck_every_other_bandit():
	var ducking := _make_bandit()
	var standing := _make_bandit()
	await wait_physics_frames(1)

	var standing_body : CollisionShape2D = standing.get_node("CollisionShape2D")
	var full_height : float = standing_body.shape.height

	ducking.get_node("StateMachine").transition_to("Reload")
	await wait_physics_frames(1)

	assert_eq(standing_body.shape.height, full_height, \
		"the capsules are inline sub-resources shared by every instance of the scene, so each " + \
		"bandit has to duck its own duplicate rather than the one they all point at")

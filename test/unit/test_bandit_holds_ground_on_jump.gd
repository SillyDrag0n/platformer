extends GutTest

# A player who jumps has not gone anywhere the bandit needs to walk to - they are still right in
# front of him. He used to close on that, shuffling a step nearer on every jump until he was
# walking in under their feet.

const BanditScene = preload("res://enemies/bandit/bandit.tscn")
const PlayerScene = preload("res://player/player.tscn")

var bandit
var player


func before_each():
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 60)
	add_child_autofree(floor_body)

	bandit = BanditScene.instantiate()
	add_child_autofree(bandit)
	player = PlayerScene.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(4)


func _chase_for_a_moment() -> void:
	bandit.set_chase(true)
	await wait_physics_frames(2)


func test_he_does_not_close_on_a_player_who_is_merely_airborne():
	player.global_position = bandit.global_position + Vector2(120, -90)
	player.velocity.y = -200
	await wait_physics_frames(1)
	assert_false(player.is_on_floor(), "sanity: the player is off the ground")

	await _chase_for_a_moment()

	assert_eq(bandit.velocity.x, 0.0, \
		"a jump is not distance - he should hold the spot rather than walk in under them")


func test_he_still_goes_after_a_player_who_actually_leaves():
	# Airborne, but well beyond his attack reach - they are getting away, not jumping on the spot.
	player.global_position = bandit.global_position + Vector2(bandit.attack_reach() + 200, -90)
	player.velocity.y = -200
	await wait_physics_frames(1)

	await _chase_for_a_moment()

	assert_ne(bandit.velocity.x, 0.0, \
		"distance is distance, whether or not their feet are on the ground")


func test_a_player_on_the_ground_is_chased_as_before():
	player.global_position = bandit.global_position + Vector2(150, 0)
	await wait_physics_frames(4)
	assert_true(player.is_on_floor(), "sanity: the player has landed")

	await _chase_for_a_moment()

	assert_ne(bandit.velocity.x, 0.0, "the ordinary chase is untouched")


func test_the_hold_distance_comes_off_the_attack_range():
	assert_almost_eq(bandit.attack_reach(), 250.0, 0.01, \
		"half of the 500-wide attack box, read off the shape rather than written down twice")

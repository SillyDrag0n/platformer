extends GutTest

# The ladder (levels/_common/ladder/) and the Climb state that goes with it. What is worth pinning
# is the two ends - a climb that can be pushed off the top or the bottom of the rungs is the whole
# failure mode - and that walking past a ladder does not grab it.

const LadderScene = preload("res://levels/_common/ladder/ladder.tscn")
const PlayerScene = preload("res://player/player.tscn")

# Layer 14, "Climbable" - the layer the ladder announces itself on, and deliberately not Ground.
const CLIMBABLE_LAYER := 8192

var ladder : Ladder
var player : CharacterBody2D
var climb : Node


func before_each():
	ladder = LadderScene.instantiate()
	ladder.height = 120.0
	add_child_autofree(ladder)
	ladder.global_position = Vector2.ZERO

	player = PlayerScene.instantiate()
	add_child_autofree(player)
	climb = player.get_node("StateMachine/Climb")
	await wait_physics_frames(2)


func test_a_ladder_is_something_to_stand_inside_rather_than_bump_into():
	assert_eq(ladder.collision_layer, CLIMBABLE_LAYER, \
		"a ladder announces itself on Climbable and nothing else - on Ground it would stop the " + \
		"player walking past it, and being stood inside is the entire point")
	assert_true(ladder is Area2D, "and it is an area, never a body")
	assert_true(ladder.is_in_group(Ladder.GROUP), "Ladder.at_body() finds ladders by group")


func test_the_grab_box_covers_the_rungs_and_reaches_a_little_past_the_top():
	var box : Rect2 = _grab_box()

	assert_almost_eq(box.end.y, ladder.bottom_y(), 1.0, "it reaches the bottom rung")
	assert_almost_eq(box.position.y, ladder.top_y() - Ladder.TOP_REACH, 1.0, \
		"and past the top one, so a player stood on the floor the ladder serves is inside it " + \
		"and can press down to climb back down")


# The ladder is drawn and shaped from an exported height, so a level can drag one to any length.
func test_its_height_is_the_height_it_was_given():
	ladder.height = 300.0
	await wait_physics_frames(1)

	assert_almost_eq(ladder.bottom_y() - ladder.top_y(), 300.0, 0.1)
	assert_almost_eq(_grab_box().size.y, 300.0 + Ladder.TOP_REACH, 1.0, \
		"and the grab box is rebuilt with it rather than staying whatever the scene shipped")


func test_a_player_walking_past_is_not_grabbed_by_it():
	player.global_position = Vector2(0, 60)
	await wait_physics_frames(2)

	assert_not_null(Ladder.at_body(player), "the player is inside the ladder")
	assert_eq(_state_name(), "normal", \
		"but standing in one is not climbing one - it takes pressing up or down")


# Climbed for real - the state machine driving Climb with the key actually held - rather than by
# calling the state's own function, which would leave Normal still running underneath and fighting
# it with gravity.
func test_the_climb_stops_at_the_top_rung():
	await _start_climbing(Vector2(0, 20))
	Input.action_press("climb_up")
	# Long enough to climb well past the top of a 120px ladder if nothing stopped it.
	await wait_physics_frames(60)
	Input.action_release("climb_up")

	var feet : float = player.global_position.y + climb.FEET_OFFSET
	assert_almost_eq(feet, ladder.top_y(), 2.0, \
		"feet finish level with the top rung, which is the floor line the ladder was placed " + \
		"against - any higher and the player is climbing thin air above it")


func test_the_climb_stops_at_the_bottom_rung():
	await _start_climbing(Vector2(0, 40))
	Input.action_press("force_fall")
	await wait_physics_frames(60)
	Input.action_release("force_fall")

	var feet : float = player.global_position.y + climb.FEET_OFFSET
	assert_almost_eq(feet, ladder.bottom_y(), 2.0, "and cannot be pushed off the bottom of them")


func test_letting_go_hands_the_one_way_platform_mask_back():
	await _start_climbing(Vector2(0, 60))
	assert_false(player.get_collision_mask_value(climb.ONE_WAY_PLATFORM_LAYER), \
		"a climb passes both ways through the platform the ladder is threaded through")

	player.get_node("StateMachine").transition_to("Normal")
	await wait_physics_frames(1)

	assert_true(player.get_collision_mask_value(climb.ONE_WAY_PLATFORM_LAYER), \
		"and the player must not walk away from the ladder able to fall through floors")


func _grab_box() -> Rect2:
	var shape_node : CollisionShape2D = ladder.get_node("CollisionShape2D")
	var size : Vector2 = shape_node.shape.size
	return Rect2(ladder.global_position + shape_node.position - size * 0.5, size)


func _state_name() -> String:
	return player.get_node("StateMachine").current_node_state.name.to_lower()


# Puts the player in the ladder, waits for the overlap to register (Ladder tracks it from the
# body_entered signal, so it is not known on the frame the position is set), then hands the state
# machine over to Climb the way pressing up does.
func _start_climbing(at : Vector2) -> void:
	player.global_position = at
	await wait_physics_frames(2)
	player.get_node("StateMachine").transition_to("Climb")
	await wait_physics_frames(1)


func after_each():
	Input.action_release("climb_up")
	Input.action_release("force_fall")
	if is_instance_valid(player):
		player.set_collision_mask_value(climb.ONE_WAY_PLATFORM_LAYER, true)

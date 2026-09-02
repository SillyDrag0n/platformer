extends GutTest

# The bandit pops up, aims for half a second and then fires (attack_state.gd). Leaving his attack
# range used to transition him straight out of that pose, so a player who kept moving was shot at
# by nobody at all - the bandit simply fell in behind them and walked. A shot he has started is
# committed now: it goes off, and then he comes after them.

const BanditScene = preload("res://enemies/bandit/bandit.tscn")
const PlayerScene = preload("res://player/player.tscn")

var bandit
var player


func before_each():
	# Both of them fall in an empty scene, and the attack range is only 250px tall - without
	# something to stand on the player drops out of it on their own and the test stops being
	# about what it means to.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 60)
	add_child_autofree(floor_body)

	bandit = BanditScene.instantiate()
	add_child_autofree(bandit)
	player = PlayerScene.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(4)


func _attack_state():
	return bandit.state_machine.node_states["attack"]


func _state_name() -> String:
	return bandit.state_machine.current_node_state.name.to_lower()


# The exit signal the controller actually listens to, raised directly so the test does not depend
# on shoving bodies through an Area2D.
func _player_leaves_attack_range() -> void:
	bandit.get_node("StateMachineController")._on_attack_range_body_exited(player)


func test_leaving_mid_aim_does_not_cancel_the_shot():
	bandit.state_machine.transition_to("Attack")
	await wait_physics_frames(1)
	assert_eq(_state_name(), "attack", "sanity: he is lining one up")

	_player_leaves_attack_range()

	assert_eq(_state_name(), "attack", "the shot is already committed, so he holds the pose")
	assert_true(_attack_state().chase_after_firing, "and he knows to follow once it has gone off")


func test_the_shot_goes_off_and_then_he_follows():
	bandit.state_machine.transition_to("Attack")
	await wait_physics_frames(1)
	_player_leaves_attack_range()

	# Past the half-second aim.
	await wait_seconds(0.7)

	assert_true(_attack_state().has_fired, "he fired rather than being walked out of it")
	assert_eq(_state_name(), "chase", "and then goes after the player")
	assert_true(bandit.is_chasing, "which is what actually moves him")


func test_a_player_who_stays_put_still_gets_the_reload_beat():
	bandit.state_machine.transition_to("Attack")
	await wait_seconds(0.7)

	assert_true(_attack_state().has_fired)
	assert_eq(_state_name(), "reload", \
		"nobody left, so the usual duck-and-reload window the player is owed still happens")


func test_leaving_after_the_shot_is_not_deferred():
	bandit.state_machine.transition_to("Attack")
	await wait_seconds(0.7)
	assert_eq(_state_name(), "reload", "sanity: the shot is spent")

	_player_leaves_attack_range()

	assert_eq(_state_name(), "aggro", \
		"with nothing committed there is nothing to wait for, so he breaks off as he always did")

extends GutTest

# Coverage for the tutorial's closing encounter (enemies/cactus_coyote/cactus_coyote.gd). The
# fight's actual feel - whether the pounce is dodgeable, whether 8 health is the right length -
# isn't unit-testable and needs a playtest. What's worth pinning here is the shape the encounter
# depends on: it waits at the carcass until it's noticed, it alternates its two attacks, and
# running out of health makes it flee rather than die.

const CoyoteScene = preload("res://enemies/cactus_coyote/cactus_coyote.tscn")


func _make_coyote() -> CactusCoyote:
	var coyote = CoyoteScene.instantiate()
	add_child_autofree(coyote)
	return coyote


func test_it_starts_feeding_and_stays_put():
	var coyote := _make_coyote()
	var placed_at_x : float = coyote.global_position.x

	await wait_physics_frames(3)

	assert_eq(coyote.current_state, CactusCoyote.State.Feeding, \
		"the player is meant to walk in on it eating, not on it already hunting them")
	assert_eq(coyote.global_position.x, placed_at_x, \
		"so it holds the spot the level put it in until something sets it off")


func test_spotting_the_player_starts_the_fight():
	var coyote := _make_coyote()

	coyote.spot_player()

	assert_eq(coyote.current_state, CactusCoyote.State.Alerted, \
		"there's a beat where it looks up before anything comes at the player")


func test_spotting_the_player_is_idempotent():
	var coyote := _make_coyote()
	coyote.spot_player()
	coyote.current_state = CactusCoyote.State.Pounce

	coyote.spot_player()

	assert_eq(coyote.current_state, CactusCoyote.State.Pounce, \
		"a second trigger (walking back into the zone, another bullet) must not reset the fight")


func test_shooting_it_while_it_feeds_both_wakes_it_and_hurts_it():
	var coyote := _make_coyote()
	var starting_health : int = coyote.health_amount

	coyote.take_damage(1)

	assert_eq(coyote.current_state, CactusCoyote.State.Alerted, \
		"opening fire before walking into the zone is a fair first move, so a hit wakes it too")
	assert_eq(coyote.health_amount, starting_health - 1, \
		"and it still counts - the fight can be opened from range")


func test_it_alternates_between_pouncing_and_spitting_spikes():
	var coyote := _make_coyote()

	coyote._choose_next_attack()
	assert_eq(coyote.current_state, CactusCoyote.State.PounceWindup, \
		"the first attack is the pounce - the loudest, most readable telegraph of the two")

	coyote._choose_next_attack()
	assert_eq(coyote.current_state, CactusCoyote.State.SpikeVolley, \
		"alternating rather than picking by range keeps both attacks in play whatever the " + \
		"player does with the distance")


func test_the_pounce_is_a_committed_leap():
	var coyote := _make_coyote()

	coyote._start_pounce()

	assert_lt(coyote.velocity.y, 0.0, "it leaves the ground, so the player can duck under it")
	assert_ne(coyote.velocity.x, 0.0, "and carries across, so standing still is what gets punished")


func test_a_pounce_that_never_lands_still_ends():
	var coyote := _make_coyote()
	coyote._start_pounce()
	coyote._state_timer = 0.0

	coyote._run_pounce(0.1)

	assert_eq(coyote.current_state, CactusCoyote.State.Recover, \
		"the max_pounce_duration safety net keeps a leap with no floor under it from " + \
		"stranding the whole fight mid-air")


func test_a_volley_fans_several_spikes_out_at_once():
	var coyote := _make_coyote()
	var before : int = ProjectileLayer.get_child_count()

	coyote.fire_spikes()

	var spawned : int = ProjectileLayer.get_child_count() - before
	assert_eq(spawned, coyote.spike_count, "the whole volley goes out on one beat")

	var spikes : Array = ProjectileLayer.get_children().slice(before)
	assert_ne(spikes.front().direction, spikes.back().direction, \
		"fanned rather than fired flat, so one sidestep or jump clears the spread")

	for spike in spikes:
		spike.free()


func test_running_out_of_health_makes_it_flee_instead_of_die():
	var coyote := _make_coyote()
	watch_signals(coyote)

	coyote.take_damage(coyote.health_amount)

	assert_eq(coyote.current_state, CactusCoyote.State.Flee, \
		"beating it drives it off - Enemy.die()'s kill credit, loot drop and death effect are " + \
		"deliberately never reached")
	assert_false(coyote.is_queued_for_deletion(), \
		"it leaves under its own power rather than blinking out where it stood")
	assert_lt(coyote.velocity.y, 0.0, "and jumps off as it goes")


func test_a_fleeing_coyote_can_neither_be_hit_nor_hit_back():
	var coyote := _make_coyote()
	coyote.take_damage(coyote.health_amount)
	var health_on_the_way_out : int = coyote.health_amount

	coyote.take_damage(5)
	await wait_physics_frames(1)

	assert_eq(coyote.health_amount, health_on_the_way_out, \
		"the fight is over the moment it turns tail")
	assert_eq(coyote.collision_layer, 0, \
		"and it shouldn't be able to clip the player on its way out")
	assert_false(coyote.hurtbox.monitoring, "nor be shot at any more, one deferred frame later")


func test_finishing_the_flee_emits_fled_and_cleans_up():
	var coyote := _make_coyote()
	watch_signals(coyote)
	coyote.flee_duration = 0.0
	coyote.take_damage(coyote.health_amount)

	# One physics frame past a zero-length flee is enough to run out the timer.
	coyote._run_flee(0.1)

	assert_signal_emitted(coyote, "fled", \
		"the encounter waits on this to drop the arena walls and play the closing line")
	assert_true(coyote.is_queued_for_deletion())


func test_a_reset_puts_it_back_over_the_carcass_whole():
	var coyote := _make_coyote()
	var home : Vector2 = coyote.global_position
	var full_health : int = coyote.health_amount
	coyote.spot_player()
	coyote.take_damage(3)
	coyote.global_position += Vector2(150.0, -40.0)

	coyote.reset_to_feeding()

	assert_eq(coyote.current_state, CactusCoyote.State.Feeding, \
		"a retry opens on the scene the player walked in on")
	assert_eq(coyote.health_amount, full_health, "not on a coyote their last attempt half-beat")
	assert_eq(coyote.global_position, home, "and not on one stood wherever the lost fight ended")


func test_a_reset_makes_a_coyote_that_already_fled_whole_again():
	var coyote := _make_coyote()
	coyote.take_damage(coyote.health_amount)

	coyote.reset_to_feeding()
	await wait_physics_frames(1)

	assert_ne(coyote.collision_layer, 0, \
		"fleeing strips its collision on the way out, so a reset has to hand it back")
	assert_true(coyote.hurtbox.monitoring, "hurtbox included, or the retry couldn't be won")

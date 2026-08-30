extends GutTest

# Coverage for the tutorial's closing beat (levels/farm_house_backyard/coyote_encounter.gd): walk
# in on the coyote -> the controls come off and the player is marched to their mark -> the way back
# seals and the coyote looks up -> the fight starts and the controls come back -> beating it drops
# the wall and plays the closing line. The dialogue itself is DialogueBox's job (already covered by
# its own NPC tests), so what's worth pinning here is the wiring, the staged approach, the seal, and
# the one-shot guard - staging the whole fight again on every re-entry to the backyard would be the
# obvious regression.

const BackyardScene = preload("res://levels/farm_house_backyard/farm_house_backyard.tscn")

var _original_flag : bool


func before_each():
	_original_flag = GameStateManager.has_driven_off_coyote
	GameStateManager.has_driven_off_coyote = false
	InventoryManager.is_open = false
	# The scripted-control lock is static state on an autoload, so a test that leaves it set would
	# silently freeze the player in every test script that runs after this one.
	GameInputEvents.release_scripted_control()


func after_each():
	GameStateManager.has_driven_off_coyote = _original_flag
	InventoryManager.is_open = false
	GameInputEvents.release_scripted_control()


# Asks the physics world, not the wall's `disabled` flag. Assigning that flag from inside a physics
# callback leaves it reading as sealed while the physics server has rejected the change ("Can't
# change this state while flushing queries"), so a flag-only check passes against an arena the
# player strolls straight out of. Probes with a bare body wearing the player's own layer, mask and
# capsule, since the real player's controller would fight a test move.
func _player_can_leave(backyard : Node2D, encounter : Node) -> bool:
	var player : CharacterBody2D = backyard.get_node("Player")
	var left : StaticBody2D = encounter.get_node("Left")

	var probe := CharacterBody2D.new()
	probe.collision_layer = player.collision_layer
	probe.collision_mask = player.collision_mask
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0
	capsule.height = 66.0
	shape.shape = capsule
	probe.add_child(shape)
	backyard.add_child(probe)
	await wait_physics_frames(1)

	# Level with the wall's own centre, which is clear of the terrain, so the only thing that can
	# stop the probe is the wall itself.
	probe.global_position = left.global_position + Vector2(60.0, 0.0)
	var blocked : bool = probe.move_and_collide(Vector2(-200.0, 0.0), true) != null
	backyard.remove_child(probe)
	probe.free()
	return not blocked


func _make_backyard() -> Node2D:
	var backyard = BackyardScene.instantiate()
	add_child_autofree(backyard)
	return backyard


func _walls_are_sealed(encounter : Node) -> bool:
	for wall in encounter._wall_bodies():
		for shape in wall.get_children():
			if shape is CollisionShape2D and shape.disabled:
				return false
	return true


# Crossing the trigger for real rather than calling _on_body_entered() by hand: the seal it leads to
# has to survive a genuine physics callback, which is the only place the server's mid-query-flush
# rejection bites.
func _walk_into_the_zone(backyard : Node2D) -> void:
	var encounter = backyard.get_node("CoyoteEncounter")
	var trigger : CollisionShape2D = encounter.get_node("CollisionShape2D")
	backyard.get_node("Player").global_position = trigger.global_position
	await wait_physics_frames(2)
	await wait_frames(2)


# The forced walk itself is the player's own run - covered on its own below - so the rest of the
# tests skip the 450px of it and put the player on their mark directly.
func _stand_on_the_mark(backyard : Node2D) -> void:
	var encounter = backyard.get_node("CoyoteEncounter")
	var player : CharacterBody2D = backyard.get_node("Player")
	player.global_position.x = encounter.get_node("Marker2D").global_position.x
	await wait_physics_frames(2)
	await wait_frames(2)


func test_the_backyard_stages_the_encounter():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	assert_true(backyard.has_node("CactusCoyote"), \
		"farm_house_backyard.tscn should have the coyote placed in it")
	assert_true(backyard.has_node("CoyoteEncounter"), \
		"farm_house_backyard.tscn should have the zone that walls the fight in")


func test_the_encounter_is_wired_to_the_coyote_a_dialogue_box_and_a_mark():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	assert_not_null(encounter.coyote, "the encounter needs the coyote it is going to set off")
	assert_not_null(encounter.dialogue_box, "and a DialogueBox for the closing line")
	assert_not_null(encounter.mark, "and the mark it walks the player up to")
	assert_true(encounter.coyote.fled.is_connected(encounter._on_coyote_fled), \
		"_ready() should wait on the coyote fleeing to know when the fight is won")


func test_the_arena_is_open_until_the_player_walks_in():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	assert_false(_walls_are_sealed(encounter), \
		"the wall stays off until it's needed, so the approach doesn't read as a dead end")
	assert_false(GameInputEvents.is_input_locked(), "and the player has their own controls")


func test_walking_in_takes_the_controls_and_marches_the_player_to_the_mark():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	var player : CharacterBody2D = backyard.get_node("Player")
	await _walk_into_the_zone(backyard)
	var start_x : float = player.global_position.x

	assert_true(GameInputEvents.is_input_locked(), \
		"crossing the trigger takes the player's own controls off them")
	assert_gt(GameInputEvents.movement_input(), 0.0, \
		"and steers them toward the mark, which is off to the right of the trigger")
	assert_false(_walls_are_sealed(encounter), \
		"the wall holds off until they're on their mark - raising it here would slam it shut in " + \
		"front of a player still on the wrong side of it")
	assert_eq(encounter.coyote.current_state, CactusCoyote.State.Feeding, \
		"and the coyote is still eating, back turned")

	await wait_physics_frames(30)
	assert_gt(player.global_position.x, start_x + 20.0, \
		"the walk drives the player's own controller, so they really do walk it")


func test_reaching_the_mark_seals_the_way_back_and_holds_on_the_coyote_feeding():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)

	assert_true(_walls_are_sealed(encounter), "the way back closes once they're on their mark")
	assert_false(await _player_can_leave(backyard, encounter), \
		"and the wall has to actually stop them, not merely read as sealed")
	assert_eq(encounter.coyote.current_state, CactusCoyote.State.Feeding, \
		"the beat they're being held there for is the coyote over the carcass, so it keeps " + \
		"eating rather than turning on them the instant they arrive")
	assert_true(GameInputEvents.is_input_locked(), "and the controls stay off through it")
	assert_eq(GameInputEvents.movement_input(), 0.0, "with the walk stopped on the mark")
	assert_false(GameStateManager.has_driven_off_coyote, \
		"nothing is spent yet - this fight can be lost, and a player who dies partway through " + \
		"should find it waiting for them rather than already over")


func test_the_feeding_beat_ends_with_the_coyote_turning_on_the_player():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	encounter.feeding_beat = 0.0
	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)

	assert_eq(encounter.coyote.current_state, CactusCoyote.State.Alerted, \
		"the coyote looks up from the carcass once its beat is up")
	assert_true(GameInputEvents.is_input_locked(), \
		"and the controls are still held through the telegraph - letting the player leave " + \
		"mid-alert would skip the one read the whole approach exists to give them")


func test_the_controls_come_back_when_the_fight_really_starts():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	encounter.feeding_beat = 0.0
	encounter.coyote.alert_duration = 0.0
	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)
	await wait_physics_frames(2)

	assert_ne(encounter.coyote.current_state, CactusCoyote.State.Alerted, \
		"the coyote is done looking up and is coming at them")
	assert_false(GameInputEvents.is_input_locked(), \
		"so the player gets their movement and everything else back for the fight itself")
	assert_true(_walls_are_sealed(encounter), "with the way back still shut behind them")


func test_shooting_it_first_skips_the_walk_in():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	# Opening fire from outside the zone is a fair opening move, and it sets the coyote off itself.
	encounter.coyote.take_damage(1)
	await _walk_into_the_zone(backyard)

	assert_true(_walls_are_sealed(encounter), \
		"crossing the trigger still shuts the way back behind them")
	assert_false(GameInputEvents.is_input_locked(), \
		"but a fight already under way has no use for a staged walk-in - marching the player to " + \
		"a mark while the coyote is mid-pounce would be worse than not staging it at all")


func test_a_non_player_body_does_not_start_the_fight():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	var bystander := Node2D.new()
	add_child_autofree(bystander)

	encounter._on_body_entered(bystander)

	assert_false(_walls_are_sealed(encounter))
	assert_false(GameInputEvents.is_input_locked())
	assert_eq(encounter.coyote.current_state, CactusCoyote.State.Feeding)


func test_driving_the_coyote_off_opens_the_arena_and_plays_the_closing_line():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	encounter._on_body_entered(backyard.get_node("Player"))
	encounter._on_coyote_fled()
	await wait_frames(2)

	assert_false(_walls_are_sealed(encounter), \
		"the wall comes back down, so the player isn't left boxed in with nothing to fight")
	assert_true(await _player_can_leave(backyard, encounter), \
		"and it really is gone from the physics world, not just flagged off")
	# The dialogue box holds input itself while it's up (via InventoryManager.is_open), so this
	# asks specifically that the encounter's own scripted-control lock was let go.
	assert_false(GameInputEvents.scripted_control, \
		"and the encounter isn't still steering the player when the fight ends")
	assert_true(encounter.dialogue_box.visible, "the player says his piece before the level ends")
	assert_true(GameStateManager.has_driven_off_coyote, \
		"and the encounter is spent for good once the coyote is actually run off")


func test_the_encounter_is_not_staged_again_on_a_later_visit():
	GameStateManager.has_driven_off_coyote = true
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	assert_false(backyard.has_node("CoyoteEncounter"), \
		"the spent encounter should remove itself so the fight can't be re-staged")
	assert_false(backyard.has_node("CactusCoyote"), \
		"and take the coyote with it, rather than leaving it stood over the carcass with " + \
		"nothing left to set it off")


func test_a_campfire_checkpoint_waits_just_outside_the_arena():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var campfire = backyard.get_node_or_null("Campfire")
	assert_not_null(campfire, \
		"losing the first real fight shouldn't cost the player the whole walk back out")
	assert_not_null(campfire.respawn_marker, "it moves the level's respawn marker onto itself")

	var left_wall = backyard.get_node("CoyoteEncounter/Left")
	assert_lt(campfire.global_position.x, left_wall.global_position.x, \
		"and it sits outside the arena, so respawning doesn't drop the player straight back " + \
		"into a fight already under way")


func test_dying_hands_the_encounter_back_the_way_it_was_found():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	var full_health : int = encounter.coyote.health_amount
	encounter.feeding_beat = 0.0
	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)
	encounter.coyote.take_damage(3)

	assert_true(PlayerManager.player_died.is_connected(encounter._on_player_died), \
		"_ready() should be listening for the player dying")

	encounter._on_player_died()
	await wait_frames(2)

	assert_false(_walls_are_sealed(encounter), \
		"the wall drops, so a player respawning at the campfire can get back in at all")
	assert_true(encounter.monitoring, \
		"and the zone re-arms, so walking back in starts the whole approach over")
	assert_false(GameInputEvents.is_input_locked(), \
		"and dying mid-approach can't respawn a player who still doesn't hold their controls")
	assert_eq(encounter.coyote.current_state, CactusCoyote.State.Feeding)
	assert_eq(encounter.coyote.health_amount, full_health, \
		"a retry is a fresh fight, not a run at a coyote the last attempt already softened")


func test_the_encounter_leaving_the_scene_hands_the_controls_back():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	await _walk_into_the_zone(backyard)
	assert_true(GameInputEvents.is_input_locked(), "mid-approach, the controls are held")

	encounter.queue_free()
	await wait_frames(2)

	assert_false(GameInputEvents.is_input_locked(), \
		"the lock is static state on an autoload, so an encounter torn down mid-approach - the " + \
		"exit transition, a level reload - has to hand the controls back or the player wakes " + \
		"up frozen in the next scene")


# The arena is walled on one side now, so the clamp stops the camera at that wall and leaves the
# other side on whatever the level itself was authored with.
func test_the_fight_pens_the_camera_in_at_the_wall():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var camera : Camera2D = backyard.get_node("PlayerCamera")
	var open_left : int = camera.limit_left
	var open_right : int = camera.limit_right
	var encounter = backyard.get_node("CoyoteEncounter")
	var left_wall : StaticBody2D = encounter.get_node("Left")
	var wall_shape : CollisionShape2D = left_wall.get_node("CollisionShape2D")
	var inner_face : float = left_wall.global_position.x + wall_shape.shape.size.x * 0.5

	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)

	assert_ne(camera.limit_left, open_left, \
		"the camera stops where the player does once the wall is up")
	assert_almost_eq(float(camera.limit_left), inner_face, 1.0, \
		"and it stops at the wall's own face, rather than trailing off over ground that's been " + \
		"walled off")
	assert_eq(camera.limit_right, open_right, \
		"the open side keeps the level's own limit - there's no wall there to stop at")


func test_the_camera_is_handed_back_when_the_coyote_is_driven_off():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var camera : Camera2D = backyard.get_node("PlayerCamera")
	var open_left : int = camera.limit_left
	var open_right : int = camera.limit_right
	var encounter = backyard.get_node("CoyoteEncounter")

	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)
	encounter._on_coyote_fled()
	await wait_frames(2)

	assert_eq(camera.limit_left, open_left, \
		"the level gets its own framing back once the fight is over")
	assert_eq(camera.limit_right, open_right)


func test_dying_hands_the_camera_back_too():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var camera : Camera2D = backyard.get_node("PlayerCamera")
	var open_left : int = camera.limit_left
	var open_right : int = camera.limit_right
	var encounter = backyard.get_node("CoyoteEncounter")

	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)
	encounter._on_player_died()
	await wait_frames(2)

	assert_eq(camera.limit_left, open_left, \
		"respawning at the campfire shouldn't leave the camera still boxed into an arena the " + \
		"player is stood well outside of")
	assert_eq(camera.limit_right, open_right)

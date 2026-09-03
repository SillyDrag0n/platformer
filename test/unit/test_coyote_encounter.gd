extends GutTest

# Coverage for the tutorial's closing beat
# (levels/regions/plains/farm_house_backyard/coyote_encounter.gd): walk in on the coyote ->
# the controls come off and the player is marched to their mark -> the way back seals and
# the coyote looks up -> the fight starts and the controls come back -> beating it drops the
# wall and plays the closing line. The dialogue itself is DialogueBox's job (already covered
# by its own NPC tests), so what's worth pinning here is the wiring, the staged approach,
# the seal, and the one-shot guard - staging the whole fight again on every re-entry to the
# backyard would be the obvious regression.

const BackyardScene = preload("res://levels/regions/plains/farm_house_backyard/farm_house_backyard.tscn")

var _original_flag : bool
var _original_dollars : int
# The Missing Cattle contract is a shared resource GameStateManager ticks off in place, so its
# checklist is wound back to where each test found it - otherwise the first test to drive the
# encounter leaves every later one starting mid-job.
var _original_objectives : Dictionary
var _original_bounty_completed : bool
var _real_save_path : String
var _real_slot : int


func before_each():
	_original_flag = GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF)
	_original_dollars = CollectibleManager.total_award_amount
	_original_objectives = {}
	var bounty := GameStateManager.get_bounty_by_id("missing_cattle")
	_original_bounty_completed = bounty.completed
	bounty.completed = false
	for stage in bounty.stages:
		for objective in stage.objectives:
			_original_objectives[objective.id] = objective.completed
			objective.completed = false
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, false)
	InventoryManager.is_open = false
	# The scripted-control lock is static state on an autoload, so a test that leaves it set would
	# silently freeze the player in every test script that runs after this one.
	GameInputEvents.release_scripted_control()

	# The debrief saves the game when Hutch is done paying up, and SaveManager points at the
	# player's real save file - redirected to scratch so a test run can never touch it. Same guard
	# test_save_manager.gd uses.
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch/"
	SaveManager.active_slot = 1


func after_each():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, _original_flag)
	CollectibleManager.total_award_amount = _original_dollars
	var bounty := GameStateManager.get_bounty_by_id("missing_cattle")
	bounty.completed = _original_bounty_completed
	for stage in bounty.stages:
		for objective in stage.objectives:
			objective.completed = _original_objectives.get(objective.id, false)
	InventoryManager.is_open = false
	GameInputEvents.release_scripted_control()

	var scratch_save := SaveManager.slot_path(1)
	if FileAccess.file_exists(scratch_save):
		DirAccess.remove_absolute(scratch_save)
	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot


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
	assert_false(GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), \
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
	assert_eq(encounter.dialogue_box.speaker_label.text, PlayerManager.get_display_name(), \
		"and he says it under the name the player entered at the start of the game, since the " + \
		"closing line is the player character talking")
	assert_true(GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), \
		"and the encounter is spent for good once the coyote is actually run off")


func test_the_encounter_is_not_staged_again_on_a_later_visit():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, true)
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


# The tutorial doesn't end on the player's closing line any more: the screen fades, and he comes to
# stood next to Hutch for the debrief that hands out the pay and points at the next job.
func test_the_closing_line_fades_the_player_over_to_the_farmer():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	var player : CharacterBody2D = backyard.get_node("Player")
	var mark : Marker2D = backyard.get_node("DebriefMark")

	encounter._on_body_entered(player)
	encounter._on_coyote_fled()
	await wait_frames(2)
	# The player clicking through the last of his own lines is what starts the debrief.
	encounter.dialogue_box.close()
	# Long enough for the fade out, the hold on black and the fade back in.
	await wait_seconds(1.8)

	assert_almost_eq(player.global_position.x, mark.global_position.x, 8.0, \
		"he comes to stood next to Hutch - the walk back across the backyard is time this beat " + \
		"has no use for")
	assert_true(GameInputEvents.scripted_control, \
		"and the controls are still off him: there's nothing to do here but talk")
	assert_true(encounter.farmer.dialogue_box.visible, \
		"Hutch starts talking on his own rather than waiting to be interacted with")
	assert_eq(encounter.farmer.dialogue_box.speaker_label.text, "Hutch", \
		"and it's the farmer talking, through his own dialogue box")


# The gap the recalled spike volley closes from the other end (see test_cactus_coyote.gd). The
# debrief holds scripted control for the whole fade-and-talk, and GameInputEvents.scripted_control
# is a static that outlives the scene - so a death in that window used to strand the player with no
# controls whether they respawned here or went back to town. _on_player_died() returns early once
# the coyote is logged as driven off, so the release has to come before that return, not after.
func test_dying_after_the_coyote_is_already_gone_still_hands_the_controls_back():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	var player : CharacterBody2D = backyard.get_node("Player")

	encounter._on_body_entered(player)
	encounter._on_coyote_fled()
	await wait_frames(2)
	encounter.dialogue_box.close()
	await wait_seconds(1.8)

	assert_true(GameInputEvents.scripted_control, \
		"the debrief has the controls off him at this point - that is the whole danger window")
	assert_true(GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), \
		"and the encounter already counts itself won, so its death handler stands down")

	encounter._on_player_died()
	await wait_frames(2)

	assert_false(GameInputEvents.scripted_control, \
		"dying here must not leave him unable to move - Respawn is the default button on the " + \
		"death screen, and it puts him straight back in this level")


func test_the_farmer_pays_up_for_the_trouble():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	# Nowhere to go on the way out: a real scene key would swap the whole test scene out from
	# under the runner when the debrief ends.
	encounter.exit_scene_key = ""
	var before_dollars : int = CollectibleManager.total_award_amount

	encounter._on_farmer_finished()
	await wait_frames(2)

	assert_eq(CollectibleManager.total_award_amount, before_dollars + encounter.reward_dollars, \
		"Hutch presses fifteen dollars on him for his trouble - separate from what the contract " + \
		"itself pays when the whole job is done")
	assert_false(GameInputEvents.scripted_control, \
		"the player gets his controls back once the conversation is over")


# The tutorial is the first leg of the one Missing Cattle contract, so its beats tick that
# contract's checklist off rather than opening a second bounty.
func test_the_encounter_ticks_off_the_first_stage_of_the_contract():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	var bounty := GameStateManager.get_bounty_by_id("missing_cattle")
	encounter.feeding_beat = 0.0

	assert_eq(bounty.get_current_stage().id, "investigate", \
		"the job starts on its first leg")

	await _walk_into_the_zone(backyard)
	assert_true(GameStateManager.is_objective_completed("missing_cattle", "reach_attack_site"), \
		"reaching the carcass is the first line on the contract")

	await _stand_on_the_mark(backyard)
	assert_true(GameStateManager.is_objective_completed("missing_cattle", "encounter_creature"), \
		"and the coyote turning on them is the second")

	encounter._on_coyote_fled()
	await wait_frames(2)

	assert_true(GameStateManager.is_objective_completed("missing_cattle", "creature_escapes"), \
		"the fight ends with it running, which is the third")
	assert_eq(bounty.get_current_stage().id, "seek_the_shaman", \
		"so the job moves on to the ride out to the shaman")
	assert_false(bounty.completed, \
		"but the contract itself is a long way from done - the coyote is still out there")


# The one way this beat could strand the player: MenuPopup.open() silently refuses while another
# menu holds InventoryManager.is_open, and opening the inventory is deliberately never gated - so
# the player can open it during the fade. A farmer's box that never opened never closes either,
# which is what would end the beat.
func test_the_debrief_finishes_even_if_the_farmer_cannot_get_a_word_in():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	encounter.exit_scene_key = ""
	var before_dollars : int = CollectibleManager.total_award_amount

	encounter._on_body_entered(backyard.get_node("Player"))
	encounter._on_coyote_fled()
	await wait_frames(2)
	encounter.dialogue_box.close()

	# Whatever the player did with the fade covering it, something else holds the menu flag by the
	# time Hutch tries to speak.
	InventoryManager.is_open = true
	await wait_seconds(1.8)

	assert_false(encounter.farmer.dialogue_box.visible, "his box never got to open")
	assert_eq(CollectibleManager.total_award_amount, before_dollars + encounter.reward_dollars, \
		"but the beat still pays out")
	assert_false(GameInputEvents.scripted_control, \
		"and still hands the controls back, rather than leaving the player stood there with " + \
		"nothing to press")


func test_the_encounter_knows_which_leg_of_the_contract_it_finished():
	var backyard := _make_backyard()
	await wait_physics_frames(1)

	var encounter = backyard.get_node("CoyoteEncounter")
	assert_null(encounter.completed_stage(), \
		"nothing to summarise while the coyote is still on the carcass")

	encounter._on_body_entered(backyard.get_node("Player"))
	encounter.feeding_beat = 0.0
	await _walk_into_the_zone(backyard)
	await _stand_on_the_mark(backyard)
	encounter._on_coyote_fled()
	await wait_frames(2)

	var stage = encounter.completed_stage()
	assert_not_null(stage, "with the coyote run off, the investigation is done")
	assert_eq(stage.id, "investigate", \
		"and that's the leg the summary screen on the way out reports on")

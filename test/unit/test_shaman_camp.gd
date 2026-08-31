extends GutTest

# The level the Missing Cattle contract's second leg is played in (levels/shaman_camp/). It's the
# first level in the project that was laid out from a script rather than by hand, so what's worth
# pinning is that it actually loads with everything a level needs, that its ground is solid, and
# that talking to the shaman is what finishes the leg.

const ShamanCampScene = preload("res://levels/shaman_camp/shaman_camp.tscn")
const BOUNTY_ID := "missing_cattle"
const STAGE_OBJECTIVES := ["find_shaman", "learn_about_creature", "learn_to_track"]

var _original_objectives : Dictionary
var _original_completed : bool
var _real_save_path : String
var _real_slot : int


func before_each():
	var bounty := GameStateManager.get_bounty_by_id(BOUNTY_ID)
	_original_objectives = {}
	_original_completed = bounty.completed
	bounty.completed = false
	for stage in bounty.stages:
		for objective in stage.objectives:
			_original_objectives[objective.id] = objective.completed
			objective.completed = false
	InventoryManager.is_open = false

	# The shaman saves once she's had her say - redirected off the player's real save file.
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch/"
	SaveManager.active_slot = 1


func after_each():
	var bounty := GameStateManager.get_bounty_by_id(BOUNTY_ID)
	bounty.completed = _original_completed
	for stage in bounty.stages:
		for objective in stage.objectives:
			objective.completed = _original_objectives.get(objective.id, false)
	InventoryManager.is_open = false

	var scratch_save := SaveManager.slot_path(1)
	if FileAccess.file_exists(scratch_save):
		DirAccess.remove_absolute(scratch_save)
	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot


func _make_camp() -> Node2D:
	var camp = ShamanCampScene.instantiate()
	add_child_autofree(camp)
	return camp


func test_the_level_has_what_a_level_needs():
	var camp := _make_camp()
	await wait_physics_frames(1)

	assert_true(camp.has_node("Player"), "a player")
	assert_true(camp.has_node("PlayerCamera"), "a camera")
	assert_true(camp.has_node("RespawnPosition"), "somewhere to respawn")
	assert_true(camp.has_node("GameScreen"), "the HUD")
	assert_true(camp.has_node("Shaman"), "and the shaman the whole ride is for")
	assert_eq(RespawnManager.respawn_marker, camp.get_node("RespawnPosition"), \
		"_ready() has to claim the respawn wiring, or dying here would respawn the player " + \
		"against whatever level was loaded before this one")


func test_the_player_lands_on_solid_ground_rather_than_falling_through_it():
	var camp := _make_camp()
	var player : CharacterBody2D = camp.get_node("Player")
	var start_y : float = player.global_position.y
	# Long enough to fall the short drop onto the ground and settle.
	await wait_physics_frames(30)

	assert_true(player.is_on_floor(), "the terrain the level was generated with has real collision")
	assert_lt(player.global_position.y, start_y + 200.0, \
		"and the player stops on it rather than falling out of the world")


func test_the_shaman_waits_at_the_far_end_of_the_ride():
	var camp := _make_camp()
	await wait_physics_frames(1)

	var player : Node2D = camp.get_node("Player")
	var shaman : Node2D = camp.get_node("Shaman")
	assert_gt(shaman.global_position.x - player.global_position.x, 2000.0, \
		"she lives a good ways out - the level is the ride, so she can't be stood at the door")
	assert_true(camp.has_node("Campfire"), \
		"with a campfire on the way, so losing a fight out here doesn't cost the whole ride back")


func test_talking_to_the_shaman_finishes_that_leg_of_the_contract():
	var camp := _make_camp()
	await wait_physics_frames(1)

	var shaman = camp.get_node("Shaman")
	var bounty := GameStateManager.get_bounty_by_id(BOUNTY_ID)
	# Stage one is behind them by the time they ride out here.
	for objective in bounty.stages[0].objectives:
		GameStateManager.complete_objective(BOUNTY_ID, objective.id)

	shaman._on_interact()
	await wait_frames(1)
	assert_true(shaman.dialogue_box.visible, "she has her say first")

	shaman.dialogue_box.close()
	await wait_frames(1)

	for objective_id in STAGE_OBJECTIVES:
		assert_true(GameStateManager.is_objective_completed(BOUNTY_ID, objective_id), \
			"%s should be ticked off by the conversation - it is the whole of this leg" % objective_id)
	assert_eq(bounty.get_current_stage().id, "hunt", \
		"and the contract moves on to hunting the thing down")
	assert_false(bounty.completed, "which is still ahead of the player, so the job isn't done")

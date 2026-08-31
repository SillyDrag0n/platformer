extends GutTest

# Coverage for the farm house: the building in town, the room inside it, and the tutorial level
# out behind it. The three are easy to confuse, and used to be wired as two - walking into the
# house in town took the player straight out to the backyard.
#
# They are separate routes now:
#   the house in town  -> FarmHouseInterior, like every other building on the street
#   the Missing Cattle contract -> the backyard, loaded from the bounty's own stage

const FarmHouseScene = preload("res://tileset/structures/farm_house/farm_house.tscn")
const BackyardScene = preload("res://levels/farm_house_backyard/farm_house_backyard.tscn")


func test_scene_manager_knows_about_the_backyard():
	assert_true(SceneManager.scenes.has("FarmHouseBackyard"), \
		"SceneManager.scenes should have an entry for the backyard")
	assert_true(ResourceLoader.exists(SceneManager.scenes["FarmHouseBackyard"]), \
		"the registered backyard scene path should actually exist")


func test_walking_into_the_house_in_town_leads_inside_it_rather_than_out_to_the_tutorial():
	var farm_house = FarmHouseScene.instantiate()
	add_child_autofree(farm_house)
	await wait_physics_frames(1)

	assert_eq(farm_house.destination_scene_key, "FarmHouseInterior", \
		"the door of a house in town should open into the house")
	assert_ne(farm_house.destination_scene_key, "FarmHouseBackyard", \
		"the backyard is where the contract sends the player, not where the front door goes")


func test_the_backyard_is_still_reachable_through_the_contract_that_uses_it():
	var stage : BountyStageData = GameStateManager.get_bounty_by_id("missing_cattle").stages[0]

	assert_not_null(stage.level_scene, \
		"the tutorial leg still needs its level - it is no longer reachable from the hub")
	assert_eq(stage.level_scene.resource_path, "res://levels/farm_house_backyard/farm_house_backyard.tscn", \
		"and that level is the backyard")


func test_farm_house_wires_its_interactable():
	var farm_house = FarmHouseScene.instantiate()
	add_child_autofree(farm_house)
	await wait_physics_frames(1)

	assert_true(farm_house.interactable.interact.is_valid(), \
		"farm_house.gd should have wired interactable.interact in _ready()")


func test_hub_level_has_a_farm_house_structure():
	var hub = load("res://levels/hub_level.tscn").instantiate()
	add_child_autofree(hub)
	await wait_physics_frames(1)

	var structures = hub.get_node("Structures")
	assert_true(structures.has_node("FarmHouse"), \
		"hub_level.tscn should have a FarmHouse instance under Structures")


func test_hub_level_has_a_welcome_npc():
	# He is only in town for a first-time player - hub_level.gd retires him once the coyote has
	# been run off (see test_hub_tutorial_cleanup.gd), so this has to say which of the two it is
	# testing rather than depend on whatever the suite left the flag on.
	var original := GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF)
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, false)

	var hub = load("res://levels/hub_level.tscn").instantiate()
	add_child_autofree(hub)
	await wait_physics_frames(1)

	assert_true(hub.has_node("WelcomeNPC"), \
		"hub_level.tscn should have a WelcomeNPC instance so first-time players get greeted")

	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, original)


func test_backyard_wires_its_respawn_nodes():
	var backyard = BackyardScene.instantiate()
	add_child_autofree(backyard)
	await wait_physics_frames(1)

	assert_true(backyard.has_node("RespawnPosition"), \
		"farm_house_backyard.tscn should have a RespawnPosition marker")
	assert_eq(RespawnManager.current_level, backyard, \
		"farm_house_backyard.gd should wire RespawnManager.set_respawn_nodes() in _ready()")


func test_backyard_has_a_hint_zone_and_a_turn_in_npc():
	var backyard = BackyardScene.instantiate()
	add_child_autofree(backyard)
	await wait_physics_frames(1)

	assert_true(backyard.has_node("HintZoneJump"), \
		"farm_house_backyard.tscn should have at least one HintZone teaching a control")
	assert_true(backyard.has_node("Hutch"), \
		"farm_house_backyard.tscn should have Hutch, a dialogue-only NPC (no bounty completion/reward)")

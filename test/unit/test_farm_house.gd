extends GutTest

# Coverage for the new farmhouse structure + backyard interior added to the hub: registers a
# scene transition ("FarmHouseBackyard") the same way every other shop/building does, so this
# mostly guards against the usual copy-paste mistakes (wrong path, unwired Interactable, etc.)
# rather than testing new logic.

const FarmHouseScene = preload("res://tileset/structures/farm_house/farm_house.tscn")
const BackyardScene = preload("res://levels/farm_house_backyard/farm_house_backyard.tscn")


func test_scene_manager_knows_about_the_backyard():
	assert_true(SceneManager.scenes.has("FarmHouseBackyard"), \
		"SceneManager.scenes should have an entry for the backyard")
	assert_true(ResourceLoader.exists(SceneManager.scenes["FarmHouseBackyard"]), \
		"the registered backyard scene path should actually exist")


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
	var hub = load("res://levels/hub_level.tscn").instantiate()
	add_child_autofree(hub)
	await wait_physics_frames(1)

	assert_true(hub.has_node("WelcomeNPC"), \
		"hub_level.tscn should have a WelcomeNPC instance so first-time players get greeted")


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

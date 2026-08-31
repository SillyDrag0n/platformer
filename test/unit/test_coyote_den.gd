extends GutTest

# The level the Missing Cattle contract's third leg - "Hunt the Creature" - is played in
# (levels/coyote_den/). It is deliberately an empty shell for now: a spawn and the tileset layers,
# with the terrain still to be painted. What is worth pinning at this stage is that it loads with
# everything a level needs, that its layers are actually wired to the desert tilesets rather than
# left blank, and that the hunt stage points at it - without that last one, accepting the bounty
# after the shaman leaves the player on the board with nothing loading.

const CoyoteDenScene = preload("res://levels/coyote_den/coyote_den.tscn")
const BOUNTY_ID := "missing_cattle"

const EXPECTED_LAYERS := {
	"TileMapTerrain": "res://tileset/desert_terrain_tileset.tres",
	"TileMapOWP": "res://tileset/desert_owp_tileset.tres",
	"TileMapDecorations": "res://tileset/desert_decorations_tileset.tres",
	"TileMapBreakables": "res://tileset/desert_breakables_tileset.tres",
	"TileMapForeground": "res://tileset/desert_foreground_tileset.tres",
}


func _make_den() -> Node2D:
	var den = CoyoteDenScene.instantiate()
	add_child_autofree(den)
	return den


func test_the_level_has_what_a_level_needs():
	var den := _make_den()
	await wait_physics_frames(1)

	assert_true(den.has_node("Player"), "a player")
	assert_true(den.has_node("PlayerCamera"), "a camera")
	assert_true(den.has_node("RespawnPosition"), "somewhere to respawn")
	assert_true(den.has_node("GameScreen"), "the HUD")
	assert_true(den.has_node("DeathScreen"), "and something to show when the hunt goes badly")
	assert_eq(RespawnManager.respawn_marker, den.get_node("RespawnPosition"), \
		"_ready() has to claim the respawn wiring, or dying here would respawn the player " + \
		"against whatever level was loaded before this one")


func test_the_camera_follows_this_levels_player():
	var den := _make_den()
	await wait_physics_frames(1)

	assert_eq(den.get_node("PlayerCamera").player, den.get_node("Player"), \
		"the camera has to be pointed at the player node in this scene, not left unassigned")


func test_the_player_spawns_where_the_respawn_marker_is():
	# Checked on the scene as authored rather than after a frame of physics: there is no ground
	# painted yet, so a player left running in an empty level is already falling by the time the
	# first physics frame is over.
	var den = CoyoteDenScene.instantiate()
	autofree(den)

	assert_eq(den.get_node("Player").position, den.get_node("RespawnPosition").position, \
		"the start spot and the respawn spot are the same place while the level is still empty - " + \
		"dying should not put the player somewhere the level was never built around")


func test_every_tileset_layer_is_wired_and_still_unpainted():
	var den := _make_den()
	await wait_physics_frames(1)

	var tile_map : Node = den.get_node("TileMap")
	for layer_name in EXPECTED_LAYERS:
		assert_true(tile_map.has_node(layer_name), "%s is there to paint into" % layer_name)
		if not tile_map.has_node(layer_name):
			continue
		var layer : TileMapLayer = tile_map.get_node(layer_name)
		assert_not_null(layer.tile_set, "%s has a tileset assigned" % layer_name)
		if layer.tile_set != null:
			assert_eq(layer.tile_set.resource_path, EXPECTED_LAYERS[layer_name], \
				"%s points at the right tileset" % layer_name)
		assert_eq(layer.get_used_cells().size(), 0, \
			"%s is still empty - this level is a shell waiting to be built" % layer_name)


func test_the_layers_stack_in_the_same_order_as_every_other_level():
	var den := _make_den()
	await wait_physics_frames(1)

	var tile_map : Node = den.get_node("TileMap")
	# Same z ordering farm_house_backyard and hub_level use, so art painted here reads the way it
	# does everywhere else: ground behind, foreground over the player.
	assert_eq(tile_map.get_node("TileMapOWP").z_index, 10, "one-way platforms sit over the terrain")
	assert_eq(tile_map.get_node("TileMapDecorations").z_index, 30, "decorations over those")
	assert_eq(tile_map.get_node("TileMapBreakables").z_index, 40, "breakables over those")
	assert_eq(tile_map.get_node("TileMapForeground").z_index, 70, "and the foreground over the player")


func test_the_hunt_stage_loads_this_level():
	var bounty := GameStateManager.get_bounty_by_id(BOUNTY_ID)
	var hunt : BountyStageData = null
	for stage in bounty.stages:
		if stage.id == "hunt":
			hunt = stage

	assert_not_null(hunt, "the contract still has a hunt leg")
	if hunt == null:
		return
	assert_not_null(hunt.level_scene, \
		"the hunt stage needs a level to load - without one, accepting the bounty off the board " + \
		"tears the poster off and then nothing happens")
	if hunt.level_scene != null:
		assert_eq(hunt.level_scene.resource_path, "res://levels/coyote_den/coyote_den.tscn", \
			"and it is this one")

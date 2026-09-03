extends GutTest

# The occlusion polygons tools/lighting/tile_occluder_gen.gd writes into the desert tilesets. They
# are what every 2D shadow in the game is cast from, and they are generated rather than authored -
# so what this guards is that the generated state is actually in the checked-in .tres files, and
# that it still matches the collision it was derived from. A tile that stops the player but casts no
# shadow is a hole the sun shines through the middle of a mesa.

const TERRAIN : TileSet = preload("res://tileset/desert_terrain_tileset.tres")
const BREAKABLES : TileSet = preload("res://tileset/desert_breakables_tileset.tres")

# Bit 1: what every Light2D masks for by default. An occluder on any other bit is invisible to the
# sun, which looks exactly like no occluder at all.
const LIGHT_MASK : int = 1


# Every tile in the set as [atlas coords, its TileData]. Flattened out rather than iterated with a
# callback because a lambda captures the counters it would have to add up by value.
func _all_tiles(tile_set : TileSet) -> Array:
	var tiles : Array = []
	for source_index in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(source_index)) as TileSetAtlasSource
		if source == null:
			continue
		for tile_index in source.get_tiles_count():
			var coords : Vector2i = source.get_tile_id(tile_index)
			tiles.append([coords, source.get_tile_data(coords, 0)])
	return tiles


func test_both_tilesets_have_an_occlusion_layer_the_lights_can_see():
	assert_eq(TERRAIN.get_occlusion_layers_count(), 1, "terrain casts shadows")
	assert_eq(TERRAIN.get_occlusion_layer_light_mask(0), LIGHT_MASK)
	assert_eq(BREAKABLES.get_occlusion_layers_count(), 1, "so does breakable rock")
	assert_eq(BREAKABLES.get_occlusion_layer_light_mask(0), LIGHT_MASK)


func test_every_terrain_tile_that_stops_the_player_also_stops_the_light():
	var solid : int = 0
	var missing : Array = []

	for tile in _all_tiles(TERRAIN):
		var data : TileData = tile[1]
		if data == null or data.get_collision_polygons_count(0) == 0:
			continue
		solid += 1
		var occluder : OccluderPolygon2D = data.get_occluder(0)
		if occluder == null or occluder.polygon != data.get_collision_polygon_points(0, 0):
			missing.append(tile[0])

	assert_gt(solid, 100, "the terrain tileset really does have collision on it to derive from")
	assert_eq(missing.size(), 0, \
		"every solid tile casts a shadow shaped like the surface the player stands on - " + \
		"re-run tools/lighting/tile_occluder_gen.gd after painting collision onto new tiles " + \
		"(first few missing: %s)" % [missing.slice(0, 5)])


# Scenery painted on the terrain layer - a tuft of grass, a rut - has no collision, and light goes
# through it. Giving those occluders would have every blade of grass throwing a hard shadow.
func test_terrain_tiles_without_collision_are_left_transparent_to_light():
	var wrongly_occluding : Array = []

	for tile in _all_tiles(TERRAIN):
		var data : TileData = tile[1]
		if data == null or data.get_collision_polygons_count(0) > 0:
			continue
		if data.get_occluder(0) != null:
			wrongly_occluding.append(tile[0])

	assert_eq(wrongly_occluding.size(), 0, "only what stops the player stops the sun")


func test_breakable_rock_occludes_the_whole_cell():
	var half := Vector2(BREAKABLES.tile_size) * 0.5
	var expected := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	var tiles : Array = _all_tiles(BREAKABLES)
	var wrong : Array = []

	for tile in tiles:
		var data : TileData = tile[1]
		var occluder : OccluderPolygon2D = data.get_occluder(0) if data != null else null
		if occluder == null or occluder.polygon != expected:
			wrong.append(tile[0])

	assert_gt(tiles.size(), 0, "there are breakable tiles to check")
	assert_eq(wrong.size(), 0, \
		"a boarded-up mine mouth is solid rock to light, so the cave behind it stays dark " + \
		"until it is blown open (first few wrong: %s)" % [wrong.slice(0, 5)])

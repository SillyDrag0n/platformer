extends GutTest

# What a blown-open wall leaves behind. The erase itself is all-or-nothing (see
# test_breakable_terrain.gd); this is the other half of it - a patch that vanishes silently reads
# as having been deleted, so every cell the blast takes has to put dust and falling rock where it
# stood, right out to the far end of a wall the blast never touched directly.

const Explosion = preload("res://scripts/explosion.gd")
const RubbleBurst = preload("res://levels/_common/breakable_rubble/rubble_burst.gd")
const BREAKABLES : TileSet = preload("res://tileset/desert_breakables_tileset.tres")

const SOURCE_ID : int = 1
const ATLAS_COORDS := Vector2i(16, 14)

const RADIUS : float = 88.0

# Past the longest delay a burst staggers a puff by, so waiting this out means every puff that is
# ever coming has arrived.
const WAVE_OVER : float = RubbleBurst.MAX_DELAY + 0.1

var terrain : TileMapLayer


func before_each():
	# ProjectileLayer is an autoload, so anything a previous test spawned into it is still there.
	for child in ProjectileLayer.get_children():
		child.free()

	terrain = TileMapLayer.new()
	terrain.tile_set = BREAKABLES
	terrain.add_to_group("BreakableTerrain")
	add_child_autofree(terrain)


func after_each():
	for child in ProjectileLayer.get_children():
		child.free()


func _paint(from_x : int, to_x : int, y : int = 0) -> void:
	for x in range(from_x, to_x + 1):
		terrain.set_cell(Vector2i(x, y), SOURCE_ID, ATLAS_COORDS)


func _detonate_at(cell : Vector2i) -> void:
	var source := Node2D.new()
	add_child_autofree(source)
	source.global_position = terrain.map_to_local(cell)
	Explosion.detonate(source, 1, RADIUS)
	await wait_physics_frames(1)


func _bursts() -> Array:
	var found : Array = []
	for child in ProjectileLayer.get_children():
		if child.get_script() == RubbleBurst:
			found.append(child)
	return found


func _puff_positions() -> Array:
	var positions : Array = []
	for burst in _bursts():
		for puff in burst.get_children():
			if puff is Node2D:
				positions.append(puff.global_position)
	return positions


func test_a_broken_wall_leaves_rubble_where_it_stood():
	_paint(0, 5)

	await _detonate_at(Vector2i(0, 0))
	await wait_seconds(WAVE_OVER)

	var positions := _puff_positions()
	assert_eq(positions.size(), 6, "one puff of rubble for each tile that came down")

	for x in range(0, 6):
		var expected : Vector2 = terrain.to_global(terrain.map_to_local(Vector2i(x, 0)))
		var matched := false
		for position in positions:
			if position.distance_to(expected) < 1.0:
				matched = true
				break
		assert_true(matched, "the cell at x=%d got rubble on the tile it occupied" % x)


# The flood fill takes a wall far past the blast radius, and the dust has to follow it out there -
# rubble only around the fireball would leave most of the wall disappearing untouched.
func test_rubble_follows_the_wall_past_the_blast_radius():
	_paint(0, 19)

	await _detonate_at(Vector2i(0, 0))
	await wait_seconds(WAVE_OVER)

	var furthest : float = 0.0
	for position in _puff_positions():
		furthest = maxf(furthest, position.distance_to(terrain.to_global(terrain.map_to_local(Vector2i(0, 0)))))

	assert_gt(furthest, RADIUS, "the far end of the wall crumbles too, not just what the blast covered")


func test_a_blast_that_breaks_nothing_leaves_no_rubble():
	_paint(0, 9)

	await _detonate_at(Vector2i(40, 0))
	await wait_physics_frames(2)

	assert_eq(_bursts().size(), 0, "nothing came down, so there is nothing to raise dust")


# A cave-sized patch would otherwise cost a puff per cell for dust that has already overlapped into
# one sheet - the burst thins it instead, and what matters is that the thinning still spans the
# whole patch rather than clustering at the blast.
func test_a_very_large_patch_is_thinned_rather_than_puffed_cell_by_cell():
	for y in range(0, 20):
		_paint(0, 19, y)

	await _detonate_at(Vector2i(0, 0))
	await wait_seconds(WAVE_OVER)

	var positions := _puff_positions()
	assert_eq(positions.size(), RubbleBurst.MAX_PUFFS, "400 cells are thinned down to the cap")

	var furthest : float = 0.0
	for position in positions:
		furthest = maxf(furthest, position.distance_to(terrain.to_global(terrain.map_to_local(Vector2i(0, 0)))))
	assert_gt(furthest, RADIUS, "and the puffs kept still reach the far side of the patch")

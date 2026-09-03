extends GutTest

# What a blast does to BreakableTerrain. The rule is all-or-nothing per patch: whatever the blast
# reaches, it takes the whole connected run of. It used to stop one tile past the radius, which left
# a circular bite out of a wall and read as the explosion having failed.

const Explosion = preload("res://scripts/explosion.gd")
const BREAKABLES : TileSet = preload("res://tileset/desert_breakables_tileset.tres")

# A source and an atlas coordinate that exist in that tileset - which tile it is does not matter
# here, only that the cell is filled.
const SOURCE_ID : int = 1
const ATLAS_COORDS := Vector2i(16, 14)

const TILE : int = 16
const RADIUS : float = 88.0

var terrain : TileMapLayer


func before_each():
	terrain = TileMapLayer.new()
	terrain.tile_set = BREAKABLES
	terrain.add_to_group("BreakableTerrain")
	add_child_autofree(terrain)


func _paint(from_x : int, to_x : int, y : int = 0) -> void:
	for x in range(from_x, to_x + 1):
		terrain.set_cell(Vector2i(x, y), SOURCE_ID, ATLAS_COORDS)


func _detonate_at(cell : Vector2i) -> void:
	var source := Node2D.new()
	add_child_autofree(source)
	source.global_position = terrain.map_to_local(cell)
	Explosion.detonate(source, 1, RADIUS)
	await wait_physics_frames(1)


# The wall runs far past anything an 88-unit blast covers - about five cells - so every cell beyond
# that is only reachable by following the patch.
func test_a_blast_takes_the_whole_connected_wall_not_just_the_part_it_touches():
	_paint(0, 19)
	assert_eq(terrain.get_used_cells().size(), 20, "the wall is painted before the blast")

	await _detonate_at(Vector2i(0, 0))

	assert_eq(terrain.get_used_cells().size(), 0, \
		"one end of a breakable wall going up has to take the rest of it with it, however far " + \
		"past the radius it runs")


func test_a_patch_the_blast_never_touches_is_left_standing():
	_paint(0, 9)
	_paint(20, 29)

	await _detonate_at(Vector2i(0, 0))

	var left : Array = terrain.get_used_cells()
	assert_eq(left.size(), 10, "the far patch is a separate structure and stays up")
	for cell in left:
		assert_gte(cell.x, 20, "and it is the far one that survived, not a fringe of the near one")


# The flood only ever steps onto cells that are already breakable, so an empty column stops it dead.
# This is what lets a level keep a bigger cave hidden behind the entrance the player just opened.
func test_a_gap_of_one_empty_cell_is_enough_to_stop_it():
	_paint(0, 4)
	_paint(6, 10)

	await _detonate_at(Vector2i(0, 0))

	assert_eq(terrain.get_used_cells().size(), 5, \
		"a single unpainted cell separates two structures - they do not have to be far apart")


func test_a_blast_nowhere_near_the_wall_leaves_it_alone():
	_paint(0, 9)

	await _detonate_at(Vector2i(40, 0))

	assert_eq(terrain.get_used_cells().size(), 10, \
		"the flood starts from cells the blast actually covers, so out of range is untouched")

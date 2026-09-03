extends RefCounted

# One blast, shared by everything in the game that goes off: the player's thrown dynamite and the
# explosive barrels left standing around a level. Both need the same four things to happen at the
# same moment - enemies hurt, the player hurt if they're too close, breakable terrain opened up,
# and anything else explosive nearby set off in turn - so the rules live here rather than being
# kept in step by hand in two places.
#
# Deliberately not a class_name: adding one needs an editor --import pass before headless tests
# can see it (see PROJECT.md), and a preloaded script with static methods needs no such thing.

const EFFECT_SCENE : PackedScene = preload("res://player/dynamite/dynamite_explosion_effect.tscn")
const RUBBLE_BURST = preload("res://levels/_common/breakable_rubble/rubble_burst.gd")

const ENEMY_COLLISION_MASK : int = 4

# Anything that can be set off by another blast. Barrels join it; thrown dynamite deliberately does
# not, since a lit stick already has its own fuse running and chaining those would take the timing
# out of the player's hands.
const EXPLOSIVE_GROUP := "Explosive"


# `source` is the node going off - it supplies the position, the scene tree and the physics world,
# and is skipped when the blast looks for other explosives so it can't re-detonate itself.
static func detonate(source : Node2D, damage : int, radius : float) -> void:
	var origin : Vector2 = source.global_position

	_damage_enemies_in_radius(source, origin, damage, radius)
	_damage_player_in_radius(origin, damage, radius)
	_destroy_breakable_tiles_in_radius(source, origin, radius)
	_chain_other_explosives(source, origin, damage, radius)

	var effect := EFFECT_SCENE.instantiate() as Node2D
	effect.global_position = origin
	effect.set_radius(radius)
	ProjectileLayer.spawn(effect)


static func _damage_enemies_in_radius(source : Node2D, origin : Vector2, damage : int, radius : float) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = ENEMY_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# The Enemy physics layer this query masks for is the real "is an enemy" signal. This used to
	# also require the "Enemy" *group*, which quietly meant explosions did nothing at all to
	# bandits or skeletons: that group is what player.gd checks to decide whether touching a body
	# hurts, so only the enemies with contact damage (the cactus and the cactus coyote) are in it,
	# and the ones you would most want to throw dynamite at were never in the blast.
	var space_state := source.get_world_2d().direct_space_state
	for result in space_state.intersect_shape(query):
		var collider = result["collider"]
		if collider.has_method("take_damage"):
			collider.take_damage(damage)


# Poorly timed throws - lighting the fuse and holding too long, or standing too close when it
# goes off - should hurt just as much as catching an enemy in the blast. take_hit() already
# handles the player's own invulnerability window, so this doesn't need to check that itself.
static func _damage_player_in_radius(origin : Vector2, damage : int, radius : float) -> void:
	var player = PlayerManager.player
	if player == null:
		return
	if origin.distance_to(player.global_position) <= radius:
		player.take_hit(damage)


# A barrel two rooms over shouldn't care, so this is a plain distance check against the blast, the
# same test the player gets. Whatever is hit takes ordinary damage rather than being told to
# explode outright - a barrel tough enough to survive one blast is then a tuning decision on the
# barrel, and each one still runs its own fuse, so a row of them goes off in a staggered chain
# instead of all at once.
static func _chain_other_explosives(source : Node2D, origin : Vector2, damage : int, radius : float) -> void:
	for other in source.get_tree().get_nodes_in_group(EXPLOSIVE_GROUP):
		if other == source or not other is Node2D:
			continue
		if not other.has_method("take_damage"):
			continue
		if origin.distance_to(other.global_position) <= radius:
			other.take_damage(damage)


static func _destroy_breakable_tiles_in_radius(source : Node2D, origin : Vector2, radius : float) -> void:
	for terrain in source.get_tree().get_nodes_in_group("BreakableTerrain"):
		_erase_breakable_cells(terrain, origin, radius)


static func _erase_breakable_cells(terrain : TileMapLayer, origin : Vector2, radius : float) -> void:
	var tile_size : Vector2i = terrain.tile_set.tile_size
	var local_center : Vector2 = terrain.to_local(origin)
	var center_cell : Vector2i = terrain.local_to_map(local_center)
	var cell_radius : int = int(ceil(radius / min(tile_size.x, tile_size.y)))

	var frontier : Array[Vector2i] = []
	for x in range(-cell_radius, cell_radius + 1):
		for y in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(x, y)
			var cell_local_center : Vector2 = terrain.map_to_local(cell)
			if local_center.distance_to(cell_local_center) > radius:
				continue

			if terrain.get_cell_source_id(cell) != -1:
				frontier.append(cell)

	# Whatever the blast reaches, it takes the whole of. A breakable patch is one object as far
	# as the player is concerned - a boarded-up mine mouth, a cracked wall - so opening part of
	# it and leaving a ragged fringe standing reads as the blast having failed rather than as a
	# deliberate edge. This used to stop one tile past whatever the radius covered, which left
	# exactly that: a circular bite out of a wall.
	#
	# The flood is bounded by the patch itself - it only ever steps onto cells that are already
	# breakable, so it stops dead at the first empty cell or ordinary terrain. What that costs is
	# that two structures meant to be separate have to be painted apart: touching at a corner
	# counts as connected, since a diagonal join reads as one wall to look at.
	var doomed : Dictionary = {}
	while not frontier.is_empty():
		var cell : Vector2i = frontier.pop_back()
		if doomed.has(cell):
			continue
		doomed[cell] = true
		for neighbor in _get_adjacent_cells(cell):
			if not doomed.has(neighbor) and terrain.get_cell_source_id(neighbor) != -1:
				frontier.append(neighbor)

	# The rubble is built off the same list the erase walks, so the dust and falling rock land
	# exactly where the wall stood however ragged the patch is. Without it the tiles simply stop
	# being drawn a frame after the fireball, which reads as the wall having been deleted rather
	# than blown open.
	var rubble_positions := PackedVector2Array()
	for cell in doomed:
		rubble_positions.append(terrain.to_global(terrain.map_to_local(cell)))
		terrain.erase_cell(cell)

	if rubble_positions.is_empty():
		return

	var rubble : Node2D = RUBBLE_BURST.new()
	rubble.setup(rubble_positions, origin)
	ProjectileLayer.spawn(rubble)


static func _get_adjacent_cells(cell : Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1),
		cell + Vector2i(1, 1), cell + Vector2i(-1, 1),
		cell + Vector2i(1, -1), cell + Vector2i(-1, -1),
	]

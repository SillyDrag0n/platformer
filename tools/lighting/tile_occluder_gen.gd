extends SceneTree

# Gives the desert tilesets the occlusion polygons 2D shadows are cast from, and writes them back
# into the .tres files. The tilesets are the checked-in artefact; this script is how they get
# regenerated:
#
#   godot --headless -s res://tools/lighting/tile_occluder_gen.gd
#
# Re-run it after painting collision onto new terrain tiles - a tile with no occluder is a hole the
# sun shines through, which on a solid mesa reads as a graphical fault rather than as lighting.
#
# Deliberately not a @tool script, so it cannot run itself inside the editor and quietly rewrite a
# tileset someone is in the middle of editing (same reasoning as tools/sfx/pickup_gen.gd).
#
# The shapes are not authored a second time here. Terrain takes its occluder from the collision
# polygon the tile already has, so a shadow is cast by exactly the surface the player stands on and
# the two can never drift apart. Breakables have no collision polygons at all, so they take the
# whole cell - a boarded-up mine mouth is a solid slab of rock as far as light is concerned.

const FROM_COLLISION := "collision"
const FULL_CELL := "full_cell"

const TILESETS := {
	"res://tileset/desert_terrain_tileset.tres": FROM_COLLISION,
	"res://tileset/desert_breakables_tileset.tres": FULL_CELL,
}

# Bit 1, which is every Light2D's default. Occluders and lights have to agree on a mask before a
# shadow happens at all, and there is no second lighting channel in this game to keep them apart.
const OCCLUDER_LIGHT_MASK : int = 1


func _init() -> void:
	for path in TILESETS:
		_add_occluders(path, TILESETS[path])
	quit()


func _add_occluders(path : String, shape_source : String) -> void:
	var tile_set : TileSet = load(path)
	if tile_set == null:
		push_error("no tileset at %s" % path)
		return

	if tile_set.get_occlusion_layers_count() == 0:
		tile_set.add_occlusion_layer()
	tile_set.set_occlusion_layer_light_mask(0, OCCLUDER_LIGHT_MASK)

	# Tiles that want the same shape are handed the same OccluderPolygon2D rather than one each:
	# the terrain's 194 collision tiles are cut from about twenty distinct shapes, and the
	# breakables are all one square. Saved, that is twenty sub-resources in the .tres instead of
	# almost fifteen hundred.
	var by_shape : Dictionary = {}
	var given : int = 0
	var skipped : int = 0

	for source_index in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(source_index)) as TileSetAtlasSource
		if source == null:
			continue

		for tile_index in source.get_tiles_count():
			var coords : Vector2i = source.get_tile_id(tile_index)
			for alternative_index in source.get_alternative_tiles_count(coords):
				var alternative : int = source.get_alternative_tile_id(coords, alternative_index)
				var data : TileData = source.get_tile_data(coords, alternative)
				var points : PackedVector2Array = _shape_for(data, tile_set, shape_source)
				if points.is_empty():
					skipped += 1
					continue

				var key := str(points)
				if not by_shape.has(key):
					var occluder := OccluderPolygon2D.new()
					occluder.polygon = points
					by_shape[key] = occluder
				data.set_occluder(0, by_shape[key])
				given += 1

	var uids := _read_uids(path)
	var error : int = ResourceSaver.save(tile_set, path)
	if error != OK:
		push_error("could not save %s (error %d)" % [path, error])
		return
	_restore_uids(path, uids)

	print("%s: %d tiles given occluders from %d distinct shapes, %d left without" % \
		[path, given, by_shape.size(), skipped])


func _shape_for(data : TileData, tile_set : TileSet, shape_source : String) -> PackedVector2Array:
	if shape_source == FULL_CELL:
		var half := Vector2(tile_set.tile_size) * 0.5
		return PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])

	# A tile with no collision is scenery painted on the terrain layer - a tuft of grass, the lip of
	# a rut - and light goes straight through it. Only what stops the player stops the sun.
	if data.get_collision_polygons_count(0) == 0:
		return PackedVector2Array()
	return data.get_collision_polygon_points(0, 0)


# Saving headlessly writes the resource back without its uid:// line, and without the uids on the
# textures it points at - the id cache the editor keeps is not up in a `--headless -s` run, so the
# saver has nothing to write. Dropping them would leave every scene that loads a tileset by uid
# falling back to its path, so the lines are lifted off the file as it stands and put back on the
# one that replaces it. Keyed by the resource path on each line, which is what does not change.
func _read_uids(path : String) -> Dictionary:
	var uids : Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return uids

	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("[gd_resource") and not line.begins_with("[ext_resource"):
			continue
		var uid := _quoted_value(line, "uid=\"")
		if uid == "":
			continue
		# The tileset's own line carries no path of its own, so it is keyed by the file it is the
		# header of. The textures below it are keyed by the path they point at.
		uids[_quoted_value(line, "path=\"") if line.begins_with("[ext_resource") else path] = uid
	return uids


func _restore_uids(path : String, uids : Dictionary) -> void:
	if uids.is_empty():
		return

	var lines : PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i]
		if not line.begins_with("[gd_resource") and not line.begins_with("[ext_resource"):
			continue
		if "uid=\"" in line:
			continue
		var key := _quoted_value(line, "path=\"") if line.begins_with("[ext_resource") else path
		if not uids.has(key):
			continue

		# Back where the saver puts it when it does have one, so a regenerated file diffs against
		# the old one as added lines and nothing else: last on the header line, and in front of the
		# path on the resources it points at.
		if line.begins_with("[gd_resource"):
			lines[i] = line.trim_suffix("]") + " uid=\"%s\"]" % uids[key]
		else:
			lines[i] = line.replace(" path=\"", " uid=\"%s\" path=\"" % uids[key])

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not reopen %s to restore its uids" % path)
		return
	file.store_string("\n".join(lines))


func _quoted_value(line : String, prefix : String) -> String:
	var start : int = line.find(prefix)
	if start == -1:
		return ""
	start += prefix.length()
	var end : int = line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)

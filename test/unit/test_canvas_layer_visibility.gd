extends GutTest

# Hiding a CanvasLayer has to actually hide it.
#
# CanvasLayer.set_visible() only walks the layer's *direct* children and only those that are
# CanvasItems. Anything nested under a plain Node in between is never told, and keeps drawing. The
# main menu hit this: its desert backdrop is TileMapLayers grouped under a node called "TileMap",
# so hiding the menu hid the panel and left the scenery over the loading screen. Nothing reads as
# wrong from the outside either - the layer says visible == false, and the orphaned CanvasItems say
# is_visible_in_tree() == true, because a CanvasItem's visibility chain stops at a CanvasLayer.
#
# The fix is structural: a grouping node inside a CanvasLayer has to be a CanvasItem itself
# (Node2D/Control), not a bare Node. This sweeps every CanvasLayer scene in the project for that
# shape rather than testing the one that broke, since the next one would fail the same way.

const UI_DIRS := ["res://ui/", "res://scripts/managers/"]


func _canvas_layer_scenes() -> Array[String]:
	var found : Array[String] = []
	for dir in UI_DIRS:
		_collect(dir, found)
	return found


func _collect(dir_path : String, into : Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full : String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full, into)
		elif entry.ends_with(".tscn"):
			into.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _bare_node_children(node : Node) -> Array[Node]:
	var offenders : Array[Node] = []
	for child in node.get_children():
		# A bare Node that carries CanvasItems under it is the trap. A bare Node holding only
		# non-visual things (timers, state machines, audio) is fine - there is nothing to hide.
		if child.get_class() == "Node" and _has_canvas_item_descendant(child):
			offenders.append(child)
	return offenders


func _has_canvas_item_descendant(node : Node) -> bool:
	for child in node.get_children():
		if child is CanvasItem or _has_canvas_item_descendant(child):
			return true
	return false


func test_no_canvas_layer_hides_its_visuals_behind_a_bare_node():
	var checked := 0
	for path in _canvas_layer_scenes():
		var packed = load(path)
		if packed == null or not packed.can_instantiate():
			continue
		var root = packed.instantiate()
		if not (root is CanvasLayer):
			root.free()
			continue

		checked += 1
		var offenders := _bare_node_children(root)
		var names : Array[String] = []
		for offender in offenders:
			names.append(offender.name)
		assert_eq(names, [] as Array[String], \
			"%s groups visuals under a bare Node (%s) - hiding the layer would leave them drawing" \
				% [path, ", ".join(names)])
		root.free()

	assert_gt(checked, 0, "the sweep found some CanvasLayer scenes to check")


# The scene that actually broke, pinned directly so the regression has a name.
func test_hiding_the_main_menu_hides_its_backdrop():
	var menu = load("res://ui/screens/main_menu_screen.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(1)
	var backdrop : Node = menu.get_node("TileMap").get_child(0)

	menu.visible = false

	assert_false(backdrop.is_visible_in_tree(), \
		"the desert backdrop has to go with the menu, not carry on over the loading screen")

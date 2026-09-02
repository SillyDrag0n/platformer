extends SceneTree

# Renders a 2D scene's artwork to a PNG without opening the game, so interior/room art can be
# authored and checked from the command line:
#
#   godot --headless -s tools/interior_preview.gd -- <scene.tscn> <out.png> [x0 y0 x1 y1]
#
# It walks the packed scene and rasterises Sprite2D / Polygon2D / ColorRect / Line2D by hand -
# --headless has no renderer, so nothing can be screenshotted the usual way. Text, the player rig
# and the UI CanvasLayers are stand-ins or skipped; this is a layout and colour check, not a
# pixel-accurate capture.

# Everything below one of these is drawn as a placeholder box (the player) or skipped entirely
# (the HUD, the death screen, the inventory - none of it is part of the room).
const PLACEHOLDER_NODES := ["Player"]
const SKIPPED_NODES := ["GameScreen", "DeathScreen", "InventoryUi", "AmbientSandDust"]

var _canvas : Image
var _view_rect : Rect2
var _draw_calls : Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -s tools/interior_preview.gd -- <scene.tscn> <out.png> [x0 y0 x1 y1]")
		quit(1)
		return

	var scene_path : String = args[0]
	var out_path : String = args[1]
	_view_rect = Rect2(-500, -270, 1000, 540)
	if args.size() >= 6:
		var x0 := float(args[2])
		var y0 := float(args[3])
		_view_rect = Rect2(x0, y0, float(args[4]) - x0, float(args[5]) - y0)

	var packed : PackedScene = load(scene_path)
	if packed == null:
		printerr("could not load ", scene_path)
		quit(1)
		return

	_canvas = Image.create(int(_view_rect.size.x), int(_view_rect.size.y), false, Image.FORMAT_RGBA8)
	_canvas.fill(Color(1, 0, 1, 1))  # magenta = nothing drew here, which is worth seeing

	var root := packed.instantiate()
	_collect(root, Transform2D.IDENTITY, 0)

	# Godot draws by z_index first and tree order second, and so does this.
	var order := range(_draw_calls.size())
	order.sort_custom(func(a, b):
		if _draw_calls[a]["z"] == _draw_calls[b]["z"]:
			return a < b
		return _draw_calls[a]["z"] < _draw_calls[b]["z"])
	for i in order:
		_paint(_draw_calls[i])

	_canvas.save_png(out_path)
	print("wrote ", out_path, " (", _draw_calls.size(), " drawables)")
	root.free()
	quit()


func _collect(node : Node, parent_transform : Transform2D, parent_z : int) -> void:
	if node.name in SKIPPED_NODES or node is CanvasLayer:
		return

	var xform := parent_transform
	if node is Node2D:
		xform = parent_transform * node.transform
	elif node is Control:
		xform = parent_transform.translated_local(node.position)

	var z := parent_z
	if node is CanvasItem:
		z = (parent_z + node.z_index) if node.z_as_relative else node.z_index

	if node.name in PLACEHOLDER_NODES:
		# The player rig is a bone tree, not a sprite - a capsule the size of their collider says
		# everything the layout check needs about how big the room is and where they stand.
		_draw_calls.append({"kind": "rect", "z": z, "color": Color(0.9, 0.3, 0.3, 0.55),
			"rect": Rect2(xform.origin + Vector2(-8, -33), Vector2(16, 66))})
		return

	if node is Sprite2D and node.texture != null:
		_draw_calls.append({"kind": "sprite", "z": z, "node": node, "xform": xform})
	elif node is Polygon2D:
		_draw_calls.append({"kind": "poly", "z": z, "color": node.color, "modulate": node.modulate,
			"points": node.polygon, "xform": xform})
	elif node is ColorRect:
		_draw_calls.append({"kind": "rect", "z": z, "color": node.color,
			"rect": Rect2(xform.origin, node.size)})
	elif node is Line2D:
		_draw_calls.append({"kind": "line", "z": z, "color": node.default_color,
			"points": node.points, "width": node.width, "xform": xform})

	for child in node.get_children():
		_collect(child, xform, z)


func _paint(call : Dictionary) -> void:
	match call["kind"]:
		"sprite":
			_paint_sprite(call["node"], call["xform"])
		"poly":
			var pts : Array[Vector2] = []
			for p in call["points"]:
				pts.append(call["xform"] * p)
			var color : Color = call["color"] * call["modulate"]
			_fill_polygon(pts, color)
		"rect":
			var r : Rect2 = call["rect"]
			_fill_polygon([r.position, r.position + Vector2(r.size.x, 0), r.end,
				r.position + Vector2(0, r.size.y)] as Array[Vector2], call["color"])
		"line":
			var half : float = maxf(call["width"], 1.0) * 0.5
			var pts2 : Array = []
			for p in call["points"]:
				pts2.append(call["xform"] * p)
			for i in range(pts2.size() - 1):
				var a : Vector2 = pts2[i]
				var b : Vector2 = pts2[i + 1]
				var n := (b - a).orthogonal().normalized() * half
				_fill_polygon([a + n, b + n, b - n, a - n] as Array[Vector2], call["color"])


func _paint_sprite(sprite : Sprite2D, xform : Transform2D) -> void:
	var image := _texture_image(sprite.texture)
	if image == null:
		return
	var scale := xform.get_scale()
	var size := Vector2(image.get_width(), image.get_height()) * scale.abs()
	if size.x < 1.0 or size.y < 1.0:
		return
	if not is_equal_approx(scale.x, 1.0) or not is_equal_approx(scale.y, 1.0):
		image.resize(int(round(size.x)), int(round(size.y)), Image.INTERPOLATE_BILINEAR)
	if sprite.flip_h or scale.x < 0.0:
		image.flip_x()
	if sprite.flip_v or scale.y < 0.0:
		image.flip_y()
	if sprite.modulate != Color.WHITE or sprite.self_modulate != Color.WHITE:
		_modulate(image, sprite.modulate * sprite.self_modulate)

	var top_left := xform.origin + sprite.offset * scale
	if sprite.centered:
		top_left -= size * 0.5
	var dst := Vector2i((top_left - _view_rect.position).round())
	_canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), dst)


# SVGs are the project's art format and --headless imports them to a texture it cannot hand back,
# so they are re-rasterised from source here. Everything else goes through the imported texture.
func _texture_image(texture : Texture2D) -> Image:
	var path := texture.resource_path
	if path.get_extension().to_lower() == "svg" and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0) == OK:
			image.convert(Image.FORMAT_RGBA8)
			return image
	var fallback := texture.get_image()
	if fallback == null:
		printerr("no image for ", path)
		return null
	fallback = fallback.duplicate()
	fallback.convert(Image.FORMAT_RGBA8)
	return fallback


func _modulate(image : Image, color : Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(px.r * color.r, px.g * color.g, px.b * color.b,
				px.a * color.a))


# Scanline fill, so rotated and non-rectangular polygons land where Godot would put them.
func _fill_polygon(points : Array, color : Color) -> void:
	if points.size() < 3 or color.a <= 0.0:
		return
	var min_y := INF
	var max_y := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var y_start := int(maxf(min_y - _view_rect.position.y, 0.0))
	var y_end := int(minf(max_y - _view_rect.position.y, _view_rect.size.y - 1))

	for y in range(y_start, y_end + 1):
		var world_y := y + _view_rect.position.y + 0.5
		var crossings : Array[float] = []
		for i in points.size():
			var a : Vector2 = points[i]
			var b : Vector2 = points[(i + 1) % points.size()]
			if (a.y <= world_y and b.y > world_y) or (b.y <= world_y and a.y > world_y):
				crossings.append(a.x + (world_y - a.y) / (b.y - a.y) * (b.x - a.x))
		crossings.sort()
		var i := 0
		while i + 1 < crossings.size():
			var x_start := int(maxf(crossings[i] - _view_rect.position.x, 0.0))
			var x_end := int(minf(crossings[i + 1] - _view_rect.position.x, _view_rect.size.x - 1))
			for x in range(x_start, x_end + 1):
				_blend_pixel(x, y, color)
			i += 2


func _blend_pixel(x : int, y : int, color : Color) -> void:
	if color.a >= 1.0:
		_canvas.set_pixel(x, y, color)
		return
	var under := _canvas.get_pixel(x, y)
	_canvas.set_pixel(x, y, under.lerp(color, color.a))

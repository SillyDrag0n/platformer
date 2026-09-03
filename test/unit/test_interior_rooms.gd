extends GutTest

# The hub's building interiors used to be a 900-wide slab of floor in an otherwise empty scene:
# nothing at either end, so a player who kept walking simply stepped off the edge of the room and
# fell forever, and the camera showed the void past the room while they did it. Each interior is
# now a closed box - full-width floor, a wall at each end, and the camera fenced to the room - and
# that is what is pinned here, because it is invisible in the art and easy to lose in a re-layout.

const INTERIORS := [
	"res://levels/hub/arms_dealer_interior/arms_dealer_interior.tscn",
	"res://levels/hub/farm_house_interior/farm_house_interior.tscn",
	"res://levels/hub/bank_interior/bank_interior.tscn",
	"res://levels/hub/post_office_interior/post_office_interior.tscn",
	"res://levels/hub/saloon_interior/saloon_interior.tscn",
	"res://levels/hub/sheriffs_office_interior/sheriffs_office_interior.tscn",
	"res://levels/hub/chapel_interior/chapel_interior.tscn",
	"res://levels/hub/railway_station_interior/railway_station_interior.tscn",
]

# Where the floor surface is in every interior, and how tall the player is - the wall has to be
# taller than they are or they would simply walk over it.
const FLOOR_SURFACE_Y := 130.0
const PLAYER_HEIGHT := 66.0


func _rect_of(shape_node : CollisionShape2D) -> Rect2:
	var size : Vector2 = shape_node.shape.size
	return Rect2(shape_node.position - size * 0.5, size)


func test_the_floor_reaches_both_walls_in_every_interior():
	for path in INTERIORS:
		var interior = load(path).instantiate()
		var floor_rect := _rect_of(interior.get_node("Floor/CollisionShape2D"))
		var left := _rect_of(interior.get_node("Walls/LeftWall"))
		var right := _rect_of(interior.get_node("Walls/RightWall"))

		assert_lt(floor_rect.position.x, left.end.x, \
			"%s: the floor has to start under the left wall, or there is a hole to fall down" % path)
		assert_gt(floor_rect.end.x, right.position.x, \
			"%s: and run past the right wall for the same reason" % path)
		assert_almost_eq(floor_rect.position.y, FLOOR_SURFACE_Y, 1.0, \
			"%s: the floor surface is where the room art puts it" % path)
		interior.free()


func test_the_walls_stand_on_the_floor_and_are_taller_than_the_player():
	for path in INTERIORS:
		var interior = load(path).instantiate()
		for wall_path in ["Walls/LeftWall", "Walls/RightWall"]:
			var wall := _rect_of(interior.get_node(wall_path))
			assert_gte(wall.end.y, FLOOR_SURFACE_Y, \
				"%s/%s: a wall that stops short of the floor can be walked under" % [path, wall_path])
			assert_lt(wall.position.y, FLOOR_SURFACE_Y - PLAYER_HEIGHT, \
				"%s/%s: and one shorter than the player can be jumped straight over" % [path, wall_path])
		interior.free()


# The camera is limited to the room for the same reason the walls exist: without it, walking to
# either end scrolls past the artwork and shows the empty scene beyond. The limits are the room
# sprite's own edges, so the frame is exactly the painted room and nothing else.
func test_the_camera_is_fenced_to_the_painted_room():
	for path in INTERIORS:
		var interior = load(path).instantiate()
		var camera : Camera2D = interior.get_node("PlayerCamera")
		var room : Sprite2D = interior.get_node("Room")
		var half := room.texture.get_size() * 0.5

		assert_eq(float(camera.limit_left), -half.x, "%s: left limit is the room's left edge" % path)
		assert_eq(float(camera.limit_right), half.x, "%s: and right is its right edge" % path)
		assert_eq(float(camera.limit_top), -half.y, "%s: same for the top" % path)
		assert_eq(float(camera.limit_bottom), half.y, "%s: and the bottom" % path)

		var right_wall := _rect_of(interior.get_node("Walls/RightWall"))
		assert_gte(half.x, right_wall.position.x, \
			"%s: and the painted room has to cover everywhere the player can stand" % path)
		interior.free()


# Everyone in an interior is drawn feet-on-origin (see the 32x64 NPC sprites), so an NPC parked at
# the old y=100 was standing 30px in the air above a floor at 130.
func test_everyone_in_an_interior_is_standing_on_the_floor():
	for path in INTERIORS:
		var interior = load(path).instantiate()
		for child in interior.get_children():
			if child is NPC:
				assert_almost_eq(child.position.y, FLOOR_SURFACE_Y, 1.0, \
					"%s: %s should have their feet on the floor" % [path, child.name])
		interior.free()


# A shop counter is a solid body, so the shopkeeper behind it has to stay inside talking distance
# of wherever it stops the player. The arms dealer is the only one with a counter that blocks.
func test_a_blocking_counter_still_leaves_the_shopkeeper_in_reach():
	var interior = load("res://levels/hub/arms_dealer_interior/arms_dealer_interior.tscn").instantiate()
	var counter := _rect_of(interior.get_node("Counter/CollisionShape2D"))
	var counter_x : float = interior.get_node("Counter").position.x
	var dealer = interior.get_node("ArmsDealer")

	# Where the player ends up when they walk into the counter: its left face, plus their own
	# half-width (the capsule in player.tscn has radius 8).
	var player_stops_at : float = counter_x + counter.position.x - 8.0
	# InteractRange is 100 wide on the player, the NPC's Interactable 72 wide, both centred.
	var reach : float = 50.0 + 36.0

	assert_lt(absf(dealer.position.x - player_stops_at), reach, \
		"the dealer has to be reachable from the near side of his own counter")
	interior.free()


# A .tscn addresses overrides on an instanced child by index, which is exactly the kind of thing
# that silently stops applying when the instanced scene changes. Without them an NPC keeps
# DialogNPC's defaults - the bank teller stood there labelled "Townsfolk" behind a prompt that
# only said "Talk".
func test_every_interior_npc_is_named_on_both_their_nameplate_and_their_prompt():
	for path in INTERIORS:
		var interior = load(path).instantiate()
		for child in interior.get_children():
			if not (child is NPC):
				continue
			var speaker : String = child.speaker_name
			assert_eq(child.get_node("NameLabel").text, speaker, \
				"%s: %s's nameplate should say who they are" % [path, child.name])
			assert_eq(child.get_node("Interactable").interact_name, "Talk to %s" % speaker, \
				"%s: and so should the prompt to talk to them" % path)
		interior.free()

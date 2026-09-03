extends GutTest

# The lamps themselves, and where they were put in the shaman's camp. Two different things worth
# pinning: that a lamp is a flame rather than a bulb, and that a lamp placed in a level is standing
# on the ground rather than hovering over it or buried in a rock - placement is done by typing
# coordinates into a .tscn, which is exactly the kind of thing that goes wrong silently.

const LanternScene : PackedScene = preload("res://levels/_common/lamps/lantern.tscn")
const LampPostScene : PackedScene = preload("res://levels/_common/lamps/lamp_post.tscn")
const FlickeringLight = preload("res://levels/_common/lamps/flickering_light.gd")
const ShamanCampScene : PackedScene = preload("res://levels/regions/plains/shaman_camp/shaman_camp.tscn")

const FALLOFF : Texture2D = preload("res://levels/_common/lighting/light_falloff.tres")


func _light_of(scene : PackedScene) -> PointLight2D:
	var lamp : Node2D = scene.instantiate()
	add_child_autofree(lamp)
	return lamp.get_node("Light")


func test_both_lamps_burn_with_the_same_shared_falloff():
	var lantern := _light_of(LanternScene)
	var post := _light_of(LampPostScene)

	assert_eq(lantern.texture, FALLOFF, "a lantern and a street lamp are the same light at " + \
		"different sizes, not two different shapes of glow")
	assert_eq(post.texture, FALLOFF)
	assert_gt(post.texture_scale, lantern.texture_scale, "the post is the one that lights a street")


func test_a_lamp_casts_shadows_of_its_own():
	var post := _light_of(LampPostScene)

	assert_true(post.shadow_enabled, \
		"a lamp that lights the rock in front of it without shadowing what is behind it reads " + \
		"as a painted-on glow")


# The flame is three sine waves; what matters is that their sum can never double the light or put
# it out, because the depth is measured against it.
func test_the_flame_never_swings_further_than_the_depth_allows():
	var highest : float = 0.0
	for step in 2000:
		var offset : float = FlickeringLight.flicker_offset(step * 0.017)
		highest = maxf(highest, absf(offset))

	assert_lte(highest, 1.0, "past one, a lamp at full depth would gutter out entirely")
	assert_gt(highest, 0.7, "and it has to actually move, or there is no flicker to see")


func test_two_lamps_lit_from_the_same_scene_do_not_pulse_together():
	var phases : Dictionary = {}
	for i in 8:
		var light := _light_of(LanternScene)
		phases[light._phase] = true

	assert_gt(phases.size(), 1, \
		"a row of lamps beating in unison is more obviously fake than no flicker at all")


func test_the_flicker_is_measured_off_whatever_the_scene_set():
	var light := _light_of(LanternScene)
	var resting : float = light._resting_energy

	assert_almost_eq(resting, 0.8, 0.001, "the lantern's resting energy comes from its scene")

	light._process(0.1)

	assert_almost_eq(light.energy, resting, resting * light.flicker_depth + 0.001, \
		"turning a lamp up in the inspector must not also make it twitchier")


# Every lamp in the camp was placed by hand against the tile data. This is the check that they are
# standing on it: solid ground directly under the lamp's foot, and open air where it stands.
func test_every_lamp_in_the_shaman_camp_stands_on_solid_ground():
	var level : Node2D = ShamanCampScene.instantiate()
	add_child_autofree(level)
	await wait_physics_frames(1)

	var terrain : TileMapLayer = level.get_node("TileMap/TileMapTerrain")
	var lamps : Node2D = level.get_node("TileMap/Lanterns")
	assert_gt(lamps.get_child_count(), 0, "the camp has lamps in it at all")

	for lamp in lamps.get_children():
		var foot : Vector2 = lamp.global_position
		var below : Vector2i = terrain.local_to_map(terrain.to_local(foot + Vector2(0, 8)))
		var at : Vector2i = terrain.local_to_map(terrain.to_local(foot - Vector2(0, 8)))

		assert_ne(terrain.get_cell_source_id(below), -1, \
			"%s has ground under it rather than hanging in the air" % lamp.name)
		assert_eq(terrain.get_cell_source_id(at), -1, \
			"%s is standing on the surface rather than buried in it" % lamp.name)


func test_the_shaman_camp_is_lit_at_all():
	var level : Node2D = ShamanCampScene.instantiate()
	add_child_autofree(level)
	await wait_physics_frames(1)

	var rig : Node2D = level.get_node_or_null("LevelLighting")
	assert_not_null(rig, "the level has a lighting rig, without which every lamp in it does nothing")
	assert_true(rig.get_node("Sun").shadow_enabled, "and its sun casts the shadows")

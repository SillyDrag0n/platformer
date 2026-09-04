extends GutTest

# The light that makes a lamp read as a lamp. The art for every lamp is already painted into the
# level's tilemap by hand; lamp_light.tscn is only the glow dropped on top of it, so what's worth
# pinning is the flicker itself and that the shaman's camp actually has some of these lit.

const LampLightScene : PackedScene = preload("res://levels/_common/lamps/lamp_light.tscn")
const FlickeringLight = preload("res://levels/_common/lamps/flickering_light.gd")
const ShamanCampScene : PackedScene = preload("res://levels/regions/plains/shaman_camp/shaman_camp.tscn")

const FALLOFF : Texture2D = preload("res://levels/_common/lighting/light_falloff.tres")


func _light() -> PointLight2D:
	var light : PointLight2D = LampLightScene.instantiate()
	add_child_autofree(light)
	return light


func test_a_lamp_light_uses_the_shared_falloff_and_casts_a_shadow():
	var light := _light()

	assert_eq(light.texture, FALLOFF, "every lamp is the same shape of glow, just resized")
	assert_true(light.shadow_enabled, \
		"a lamp that lights the rock in front of it without shadowing what's behind it reads " + \
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
		var light := _light()
		phases[light._phase] = true

	assert_gt(phases.size(), 1, \
		"a row of lamps beating in unison is more obviously fake than no flicker at all")


func test_the_flicker_is_measured_off_whatever_the_scene_set():
	var light := _light()
	var resting : float = light._resting_energy

	assert_almost_eq(resting, light.energy, 0.001, "resting energy comes from the scene's own energy")

	light._process(0.1)

	assert_almost_eq(light.energy, resting, resting * light.flicker_depth + 0.001, \
		"turning a lamp up in the inspector must not also make it twitchier")


func test_the_shaman_camp_is_lit_at_all():
	var level : Node2D = ShamanCampScene.instantiate()
	add_child_autofree(level)
	await wait_physics_frames(1)

	var rig : Node2D = level.get_node_or_null("LevelLighting")
	assert_not_null(rig, "the level has a lighting rig, without which every lamp in it does nothing")
	assert_true(rig.get_node("Sun").shadow_enabled, "and its sun casts the shadows")

	var lights : Node2D = level.get_node("TileMap/Lights")
	assert_gt(lights.get_child_count(), 0, "the camp has lamp light in it at all")
	for light in lights.get_children():
		assert_true(light is PointLight2D, \
			"%s is a light dropped onto the tilemap's own art, not a prop with a light buried in it" \
			% light.name)

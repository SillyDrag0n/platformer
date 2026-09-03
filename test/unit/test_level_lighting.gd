extends GutTest

# The per-level lighting rig. What is worth pinning is the thing that is easy to break by hand: the
# preset has to actually reach the two child nodes, and it has to keep reaching them when it is
# changed after the level is up, which is how anyone tuning a level uses it.

const LightingScene : PackedScene = preload("res://levels/_common/lighting/level_lighting.tscn")
const LevelLighting = preload("res://levels/_common/lighting/level_lighting.gd")


func _make_rig() -> Node2D:
	var rig : Node2D = LightingScene.instantiate()
	add_child_autofree(rig)
	return rig


func _ambient(rig : Node2D) -> CanvasModulate:
	return rig.get_node("Ambient")


func _sun(rig : Node2D) -> DirectionalLight2D:
	return rig.get_node("Sun")


func test_a_fresh_rig_is_the_golden_hour_it_defaults_to():
	var rig := _make_rig()

	assert_eq(rig.preset, LevelLighting.Preset.GOLDEN_HOUR, "the default a level gets by dropping it in")
	assert_eq(_ambient(rig).color, LevelLighting.PRESETS[LevelLighting.Preset.GOLDEN_HOUR]["ambient"], \
		"the preset's ambient is on the CanvasModulate, not just in the dictionary")
	assert_almost_eq(_sun(rig).energy, 0.85, 0.001, "and its sun is lit")
	assert_true(_sun(rig).shadow_enabled, "a sun that casts nothing is the flat lighting this replaces")


func test_changing_the_preset_after_the_level_is_up_still_lands():
	var rig := _make_rig()

	rig.preset = LevelLighting.Preset.NIGHT

	assert_eq(_ambient(rig).color, LevelLighting.PRESETS[LevelLighting.Preset.NIGHT]["ambient"], \
		"tuning a level means changing this while looking at it - it cannot be read once at load")
	assert_eq(_sun(rig).color, LevelLighting.PRESETS[LevelLighting.Preset.NIGHT]["sun_color"])


# A room has no sun in it, and a DirectionalLight2D turned down to nothing still costs a shadow pass
# over every occluder on screen.
func test_an_interior_switches_the_sun_off_rather_than_down():
	var rig := _make_rig()

	rig.preset = LevelLighting.Preset.INTERIOR

	assert_eq(_sun(rig).energy, 0.0, "no sun indoors")
	assert_false(_sun(rig).visible, "and it is off, not merely dark")
	assert_false(_sun(rig).shadow_enabled, "so it is not shadowing anything either")


func test_the_ambient_knob_dims_the_colour_without_making_the_world_see_through():
	var rig := _make_rig()

	rig.ambient_brightness = 0.5

	var preset_ambient : Color = LevelLighting.PRESETS[LevelLighting.Preset.GOLDEN_HOUR]["ambient"]
	assert_almost_eq(_ambient(rig).color.r, preset_ambient.r * 0.5, 0.001)
	assert_almost_eq(_ambient(rig).color.b, preset_ambient.b * 0.5, 0.001)
	assert_eq(_ambient(rig).color.a, 1.0, \
		"alpha on a CanvasModulate makes the world transparent, not dark - it stays at one")


func test_the_sun_can_be_swung_without_leaving_the_preset():
	var rig := _make_rig()
	var preset_angle : float = LevelLighting.PRESETS[LevelLighting.Preset.GOLDEN_HOUR]["sun_angle"]

	rig.sun_angle_offset = -30.0

	assert_almost_eq(_sun(rig).rotation_degrees, preset_angle - 30.0, 0.01, \
		"shadows swing with the offset, so a level can face its sun the other way")


func test_shadows_can_be_turned_off_for_a_level_with_nothing_to_cast_them():
	var rig := _make_rig()

	rig.sun_shadows = false

	assert_false(_sun(rig).shadow_enabled)
	assert_gt(_sun(rig).energy, 0.0, "the sun still lights the place, it just stops shadowing")

extends GutTest

# The project-wide fallback font (gui/theme/custom_font) is what any Control that is not inside a
# themed subtree draws with. It used to be recorded as "uid://kiwlymd55nc2", a UID that no longer
# resolves to anything - so the setting silently fell back to Godot's built-in font and every
# unthemed label in a pixel-art western was drawn in the engine default.
#
# The reason it broke where two dozen scenes referencing the same dead UID did not is that a scene
# writes a UID *and* a path and can fall back to the path. A project setting is the string on its
# own, with nothing to fall back to - which is why it is a res:// path now.

const CUSTOM_FONT_SETTING := "gui/theme/custom_font"


func test_the_project_has_a_fallback_font_at_all():
	var setting : String = ProjectSettings.get_setting(CUSTOM_FONT_SETTING, "")
	assert_ne(setting, "", "%s should name a font" % CUSTOM_FONT_SETTING)


# The failure this is really guarding: a setting that names something the engine cannot find. It
# costs nothing at load time and shows up only as text in the wrong typeface.
func test_the_font_it_names_actually_loads():
	var setting : String = ProjectSettings.get_setting(CUSTOM_FONT_SETTING, "")
	assert_true(ResourceLoader.exists(setting), \
		"'%s' does not resolve - a project setting has no path to fall back to the way a scene " % setting + \
		"does, so a stale reference here means no custom font at all")

	var font = load(setting)
	assert_true(font is Font, "and what it names has to be a font")

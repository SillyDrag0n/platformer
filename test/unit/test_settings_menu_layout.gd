extends GutTest

# The General tab of the settings screen. It used to be one flat column of full-width controls
# with their labels stacked above them - and the first three, window mode, resolution and max FPS,
# carried no label at all, so the player read "Window", "1920x1080" and "60" in a row with nothing
# saying which was which. It is a list of labelled rows under section headings now.

const SettingsScene = preload("res://ui/screens/settings_menu_screen.tscn")

# Every row that sets something, and the label that has to be standing next to it.
const LABELLED_ROWS := [
	"WindowModeRow", "ResolutionRow", "MaxFpsRow", "VSyncRow",
	"MasterVolumeRow", "MusicVolumeRow", "SFXVolumeRow", "UIVolumeRow",
	"AimSensitivityRow", "UiScaleRow", "LanguageRow",
]

var screen


func before_each():
	screen = SettingsScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(3)


func _general_list() -> Control:
	return screen.general_scroll.get_node("GeneralList")


func test_every_setting_row_says_what_it_sets():
	var list := _general_list()
	for row_name in LABELLED_ROWS:
		var row : Control = list.get_node_or_null(row_name)
		assert_not_null(row, "%s should be a row of its own" % row_name)
		if row == null:
			continue
		var label : Label = row.get_node_or_null("Label")
		assert_not_null(label, "%s needs a label, or the control beside it is unexplained" % row_name)
		if label != null:
			assert_ne(label.text, "", "%s's label should actually say something" % row_name)


func test_the_settings_are_grouped_under_headings():
	var list := _general_list()
	for heading in ["Display", "Audio", "Game"]:
		assert_not_null(list.get_node_or_null(heading), \
			"%s should head its own section rather than the whole tab being one flat column" % heading)


# The list is taller than the tab now, so it scrolls - and it has to start at the top, or the first
# section heading is cut off before the player has touched anything.
func test_the_tab_opens_at_the_top_with_a_real_control_focused():
	assert_eq(screen.general_scroll.scroll_vertical, 0, \
		"opening the tab part-scrolled hides the heading the first rows belong to")

	var focused = screen.get_viewport().gui_get_focus_owner()
	assert_eq(focused, screen.window_mode_option_button, \
		"focus has to land on a setting, not on the scroll container holding them")


func test_a_slider_says_where_it_is_set():
	screen.master_volume_slider.value = 45.0
	await wait_physics_frames(1)

	assert_string_contains(screen.master_volume_value.text, "45", \
		"a slider with no number beside it only ever says 'somewhere around here'")

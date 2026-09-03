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


# The General tab is taller than the card it sits in, and Godot's spatial focus search measures
# distance to controls it cannot see - so from a row near the fold, MainMenuButton (on screen, just
# below the card) won an "up/down" against the next row (off screen, further away). Pressing down
# walked a few rows and then fell out of the list, with no way back to the settings underneath.
func test_moving_down_the_general_tab_walks_every_row():
	var rows : Array = screen._focusable_descendants(screen.general_scroll)
	assert_gt(rows.size(), 1, "the tab needs more than one row for this to mean anything")

	var walked : Array = []
	var here : Control = rows[0]
	# One step per row at most - a chain that loops back on itself would otherwise spin here.
	for _step in rows.size():
		walked.append(here)
		var next := here.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null or next == screen.main_menu_button:
			break
		here = next

	assert_eq(walked.size(), rows.size(), \
		"holding down has to reach every setting rather than dropping out of the list part way")
	assert_eq(walked[-1], rows[-1], "and end on the last one")


func test_the_bottom_of_the_list_hands_focus_to_the_button_below_it():
	var rows : Array = screen._focusable_descendants(screen.general_scroll)

	assert_eq(rows[-1].find_valid_focus_neighbor(SIDE_BOTTOM), screen.main_menu_button, \
		"past the last setting there is nowhere left to go but out")
	assert_eq(screen.main_menu_button.find_valid_focus_neighbor(SIDE_TOP), rows[-1], \
		"and pressing up off the button has to come back to it")


# MainMenuButton is shared by both tabs, so its way back up cannot be wired once and left - it has
# to follow whichever tab is showing, or it points into a hidden one and focus stops moving at all.
func test_the_button_finds_its_way_back_into_whichever_tab_is_showing():
	screen._cycle_tab(1)
	await wait_physics_frames(2)

	var controls_rows : Array = screen._focusable_descendants(screen.controls_scroll_container)
	assert_eq(screen.main_menu_button.find_valid_focus_neighbor(SIDE_TOP), controls_rows[-1], \
		"on the Controls tab, up off the button goes back into the Controls list")

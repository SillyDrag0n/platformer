extends GutTest

# Holding a direction in a menu. The repeat has to come from exactly one place: the engine answers
# a key echo as readily as a real press, and a deflected stick jitters out motion events that read
# as presses too, so a held direction used to be repeated by several things at once at unrelated
# rates - it lurched, skipped rows, and did something different every time.

var _list : VBoxContainer
var _rows : Array = []


func before_each():
	_list = VBoxContainer.new()
	for i in 8:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		_list.add_child(button)
		_rows.append(button)
	add_child_autofree(_list)
	await wait_physics_frames(2)
	# Chained explicitly so a row's neighbour never depends on where it was laid out.
	for i in _rows.size() - 1:
		_rows[i].focus_neighbor_bottom = _rows[i].get_path_to(_rows[i + 1])
		_rows[i + 1].focus_neighbor_top = _rows[i + 1].get_path_to(_rows[i])


func after_each():
	_send_key(false, false)
	await wait_physics_frames(1)
	_rows = []


func _send_key(pressed : bool, echo : bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_DOWN
	event.physical_keycode = KEY_DOWN
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _focused_row() -> int:
	return _rows.find(get_viewport().gui_get_focus_owner())


func test_the_first_press_moves_straight_away():
	_rows[0].grab_focus()
	await wait_physics_frames(1)

	_send_key(true, false)
	await wait_physics_frames(2)

	assert_eq(_focused_row(), 1, "a tap has to answer at once rather than wait out the hold delay")


# The OS repeats a held key by itself and the engine navigates on those echoes, so this used to
# run alongside the repeater's own cadence - two streams at unrelated rates.
func test_the_operating_systems_own_key_repeat_does_not_move_the_focus_as_well():
	_rows[0].grab_focus()
	await wait_physics_frames(1)
	_send_key(true, false)
	await wait_physics_frames(2)
	var after_the_press := _focused_row()
	assert_eq(after_the_press, 1, "the press itself moved one row, as it should")

	for _echo in 5:
		_send_key(true, true)
	await wait_physics_frames(1)

	assert_eq(_focused_row(), after_the_press, \
		"the echoes belong to the repeater's cadence, not to a second one running alongside it")


func test_holding_it_walks_the_list_at_the_advertised_rate():
	_rows[0].grab_focus()
	await wait_physics_frames(1)
	_send_key(true, false)

	# The initial delay plus room for four intervals. Bounded rather than exact - the point is that
	# it moves steadily and in step with the constants, not that it lands on a particular row.
	var repeater = UiNavigationRepeater
	await wait_seconds(repeater.INITIAL_DELAY + repeater.REPEAT_INTERVAL * 4.0 + 0.03)

	var reached := _focused_row()
	assert_between(reached, 4, 7, \
		"a held direction has to keep moving, roughly one row per REPEAT_INTERVAL")


func test_letting_go_stops_it():
	_rows[0].grab_focus()
	await wait_physics_frames(1)
	_send_key(true, false)
	await wait_seconds(UiNavigationRepeater.INITIAL_DELAY + UiNavigationRepeater.REPEAT_INTERVAL * 2.0)
	_send_key(false, false)
	var stopped_at := _focused_row()

	await wait_seconds(UiNavigationRepeater.REPEAT_INTERVAL * 4.0)

	assert_eq(_focused_row(), stopped_at, "nothing should still be moving after the key came up")


# A slider answers left and right itself, which is why it is left alone - but only along that axis.
# Treating the whole control as off-limits stranded a held "down" on the first volume row of the
# settings list, with nothing left to carry the focus past it.
func test_a_slider_still_hands_a_held_direction_down_the_list():
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_ALL
	add_child_autofree(slider)
	await wait_physics_frames(1)
	slider.grab_focus()
	await wait_physics_frames(1)

	assert_true(UiNavigationRepeater._owns("ui_down"), \
		"up and down past a horizontal slider are plain navigation and have to keep repeating")
	assert_false(UiNavigationRepeater._owns("ui_left"), \
		"left and right are the slider's own, and repeating them too makes it jitter")


func test_a_text_field_keeps_its_own_key_repeat():
	var field := LineEdit.new()
	add_child_autofree(field)
	await wait_physics_frames(1)
	field.grab_focus()
	await wait_physics_frames(1)

	assert_false(UiNavigationRepeater._owns("ui_left"), \
		"the caret repeats off the OS echo through ui_text_*, which is bound to the same key - " + \
		"swallowing it would stop a held arrow dead in the name entry box")

extends Node

# Godot's built-in Control focus navigation only reacts to a fresh press of ui_up/down/left/right,
# not to the input being held - so without this, moving through a long menu means mashing the same
# direction over and over instead of just holding it. This makes a held direction repeat at one
# steady cadence the whole game shares, gamepad included.
#
# "One" is the load-bearing word. The engine answers a key echo as readily as a real press, and a
# deflected analog stick jitters out a stream of motion events that read as presses too, so a held
# direction used to be repeated by two or three things at once at unrelated rates - which is what
# made holding up or down lurch, skip rows and generally behave differently every time. Everything
# a direction sends between its first press and its release is swallowed here, and the cadence
# below is the only thing that moves the focus.

const REPEATABLE_ACTIONS : Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
const VERTICAL_ACTIONS : Array[String] = ["ui_up", "ui_down"]

const INITIAL_DELAY := 0.35
const REPEAT_INTERVAL := 0.08

# A frame long enough to owe several repeats - a scene load, a hitch - should not spend them all at
# once and throw the focus down the list.
const MAX_REPEATS_PER_FRAME := 2

# Screens that capture the next raw input themselves (e.g. control rebinding) set this so a
# synthetic repeat firing mid-capture isn't mistaken for the real input being bound.
var suspended : bool = false

# Only one direction is tracked at a time - holding two at once is not a real menu-navigation
# case, so the most recent one simply wins.
var _held_action : String = ""
var _held_time : float = 0.0
var _repeat_time : float = 0.0
var _repeating : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event : InputEvent) -> void:
	# InputEventAction is the type _fire() sends. Reading those back would have this node treat its
	# own repeats as fresh presses, resetting its delay and interval at random.
	if suspended or event is InputEventAction:
		return

	for action in REPEATABLE_ACTIONS:
		if event.is_action_pressed(action, true):
			if _held_action == action:
				_swallow_if_ours(action)
			else:
				_press(action)
			return
		if event.is_action_released(action) and _held_action == action:
			_release()
			return


# The first press of a direction is left alone - the engine navigates on it, which is what makes
# a tap feel immediate. Everything after it until the release is this node's to schedule, so it is
# taken out of the input stream before GUI dispatch ever sees it.
func _swallow_if_ours(action : String) -> void:
	if _owns(action):
		get_viewport().set_input_as_handled()


func _press(action : String) -> void:
	_held_action = action
	_held_time = 0.0
	_repeat_time = 0.0
	_repeating = false


func _release() -> void:
	_held_action = ""
	_held_time = 0.0
	_repeat_time = 0.0
	_repeating = false


func _process(delta : float) -> void:
	if suspended or _held_action == "":
		return
	# A release can go missing - the direction let go while a menu was closing, or while suspended -
	# so the hold is confirmed against Input rather than trusted to have been seen.
	if not Input.is_action_pressed(_held_action):
		_release()
		return
	if not _owns(_held_action):
		return

	if not _repeating:
		_held_time += delta
		if _held_time < INITIAL_DELAY:
			return
		# The first repeat lands on the delay itself rather than an interval after it, so the pause
		# before the list starts moving is the one INITIAL_DELAY names.
		_repeating = true
		_repeat_time = 0.0
		_fire(_held_action)
		return

	_repeat_time += delta
	var fired := 0
	# Carrying the remainder rather than zeroing it keeps the cadence even: a 0.08s interval falls
	# between frames at 60fps, and resetting to zero rounded every repeat up to the next whole
	# frame, turning a steady hold into a limp.
	while _repeat_time >= REPEAT_INTERVAL and fired < MAX_REPEATS_PER_FRAME:
		_repeat_time -= REPEAT_INTERVAL
		fired += 1
		_fire(_held_action)
	if _repeat_time >= REPEAT_INTERVAL:
		_repeat_time = 0.0


# Whether this node is the thing that should be repeating the action - that is, whether the
# direction is plain focus navigation. Two cases belong to the focused control instead:
#
# A Range repeats itself along its own axis, off every qualifying event, so repeating on top of it
# drives one hold down two paths at once - the jitter sliders used to show under a controller.
# Only along its own axis, though: an HSlider leaves up and down to focus navigation like any other
# control, and treating the whole slider as off-limits stranded a held "down" on the first volume
# row of the settings list with nothing left to move it on.
#
# A text field repeats its own caret from the OS echo, through the ui_text_* actions bound to the
# same arrow keys - swallowing those would stop a held arrow dead in the name entry box.
func _owns(action : String) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return false
	if focused is LineEdit or focused is TextEdit:
		return false
	if focused is Range:
		return VERTICAL_ACTIONS.has(action) != _range_axis_is_vertical(focused)
	return true


# Godot splits a Range's orientation into the class rather than exposing it as a property, so which
# way one answers a direction has to be asked by type.
func _range_axis_is_vertical(bar : Range) -> bool:
	return bar is VSlider or bar is VScrollBar or bar is SpinBox


func _fire(action : String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

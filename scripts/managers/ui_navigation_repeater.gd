extends Node

# Godot's built-in Control focus navigation only reacts to a fresh press of ui_up/down/left/right,
# not to the input being held - so without this, moving through a long menu means mashing the same
# direction over and over instead of just holding it. This re-fires each direction as a synthetic
# action press once after an initial delay, then repeatedly at a fixed interval, for as long as it
# stays held - the same feel as OS key repeat, but for every menu in the game (gamepad included).

const REPEATABLE_ACTIONS : Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
const INITIAL_DELAY := 0.4
const REPEAT_INTERVAL := 0.12

# Screens that capture the next raw input themselves (e.g. control rebinding) set this so a
# synthetic repeat firing mid-capture isn't mistaken for the real input being bound.
var suspended : bool = false

# Only one direction is tracked at a time - holding two at once is not a real menu-navigation
# case, so the most recent one simply wins.
var _held_action : String = ""
var _held_time : float = 0.0
var _repeat_time : float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Hold tracking is driven from raw input events rather than Input.is_action_just_pressed(), and
# explicitly ignores InputEventAction - the type _fire() itself sends. Polling the global action
# state instead would have this node's own synthetic repeats read back as a fresh press, resetting
# its own delay/interval timers at random and producing an erratic stutter instead of a steady
# repeat (this is what caused sliders and other bars to visibly jitter when a direction was held).
func _input(event : InputEvent) -> void:
	if event is InputEventAction:
		return

	for action in REPEATABLE_ACTIONS:
		if event.is_action_pressed(action, false):
			if _held_action != action:
				_held_action = action
				_held_time = 0.0
				_repeat_time = 0.0
			return
		if event.is_action_released(action) and _held_action == action:
			_held_action = ""
			return


func _process(delta : float) -> void:
	if suspended or _held_action == "":
		return
	if not Input.is_action_pressed(_held_action):
		_held_action = ""
		return

	# Range (Slider) already repeats ui_left/right/up/down on its own without any help - it reacts
	# directly to every qualifying input event, including the continuous stream of motion events an
	# analog stick sends every frame while deflected (there's no "echo" concept for joypad axes the
	# way there is for keyboard, so each one re-triggers it). Firing synthetic presses on top of that
	# double-repeats the same hold through two independent paths at once, which is what was making
	# sliders (and only sliders, and only with a controller) behave erratically.
	if get_viewport().gui_get_focus_owner() is Range:
		return

	_held_time += delta
	if _held_time < INITIAL_DELAY:
		return
	_repeat_time += delta
	if _repeat_time >= REPEAT_INTERVAL:
		_repeat_time = 0.0
		_fire(_held_action)


func _fire(action : String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

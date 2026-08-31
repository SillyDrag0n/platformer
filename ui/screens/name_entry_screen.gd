extends CanvasLayer

# Alphabetical rather than QWERTY - a reading-order grid is easier to reason about with
# directional D-pad input than hunting across a staggered keyboard layout. Symbols are limited to
# ones that actually show up in names/nicknames (hyphen, apostrophe, period, underscore) rather
# than a full ASCII set. 26 letters + 10 digits + 4 symbols + Space + Delete = 42, exactly 6 full
# rows of KEYBOARD_COLUMNS with no ragged last row to special-case.
const KEYBOARD_KEYS : Array[String] = [
	"A", "B", "C", "D", "E", "F", "G",
	"H", "I", "J", "K", "L", "M", "N",
	"O", "P", "Q", "R", "S", "T", "U",
	"V", "W", "X", "Y", "Z", "0", "1",
	"2", "3", "4", "5", "6", "7", "8",
	"9", "-", "'", ".", "_", "SP", "DEL",
]
const KEYBOARD_COLUMNS := 7

@onready var name_input : LineEdit = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/NameInput
@onready var confirm_button : Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ConfirmButton
@onready var keyboard_grid : GridContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/KeyboardGrid


func _ready():
	SettingsManager.apply_ui_scale(self)
	_build_keyboard()
	name_input.grab_focus()


# LineEdit has built-in behavior where ui_cancel (Escape / controller B) makes it drop focus
# ("exit edit mode") - confirmed against Godot's own issue tracker (godotengine/godot#114865) and
# reproduced here. There's nothing to cancel back to on this screen, so it's swallowed in _input()
# - which runs before GUI dispatch - rather than left to reach LineEdit's own handling at all.
func _input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and name_input.has_focus():
		get_viewport().set_input_as_handled()


# Blank input (or all whitespace) falls back to a default rather than leaving the player with an
# empty name for the rest of the save. Split out from _on_confirm_button_pressed() so the
# resolution logic is testable without also triggering that function's scene transition.
func _resolve_entered_name() -> String:
	var entered_name := name_input.text.strip_edges()
	return entered_name if entered_name != "" else PlayerManager.DEFAULT_NAME

func _on_confirm_button_pressed():
	PlayerManager.player_name = _resolve_entered_name()
	queue_free()
	SceneManager.transition_to_scene("Hub")


func _on_name_input_text_submitted(_new_text : String) -> void:
	_on_confirm_button_pressed()


# On-screen keyboard so a controller (no physical keys to type with) can still build a name -
# built here rather than hand-authored in the .tscn since 28 buttons with correct signal
# connections would be tedious and error-prone to write by hand.
func _build_keyboard() -> void:
	var key_buttons : Array = []
	for key in KEYBOARD_KEYS:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size = Vector2(44, 40)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_key_pressed.bind(key))
		keyboard_grid.add_child(button)
		key_buttons.append(button)

	# The keyboard sits between the text field above it and Confirm below it - wired explicitly
	# since Godot's automatic focus search doesn't reliably reach into or out of a wide grid.
	FocusGrid.wire_grid(key_buttons, KEYBOARD_COLUMNS, confirm_button, name_input)


func _on_key_pressed(key : String) -> void:
	match key:
		"SP":
			_insert_text(" ")
		"DEL":
			if name_input.text.length() > 0:
				name_input.text = name_input.text.substr(0, name_input.text.length() - 1)
		_:
			_insert_text(key)


func _insert_text(text : String) -> void:
	if name_input.text.length() >= name_input.max_length:
		return
	name_input.text += text

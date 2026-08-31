extends Node

# One dedicated AudioStreamPlayer per sound so a burst of "move" blips (e.g. while a direction is
# held via UiNavigationRepeater) never cuts off a "confirm"/"cancel" blip landing at the same
# moment, or itself.
@onready var move_player : AudioStreamPlayer = $MovePlayer
@onready var confirm_player : AudioStreamPlayer = $ConfirmPlayer
@onready var cancel_player : AudioStreamPlayer = $CancelPlayer

# Buttons that take something away rather than commit to it - the name screen's DEL key so far.
# They speak with the cancel blip instead of the confirm one, so undoing sounds like undoing
# wherever it happens, without each screen having to carry its own AudioStreamPlayer.
const CANCEL_SOUND_GROUP := &"UiCancelSound"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	get_tree().node_added.connect(_on_node_added)


# ui_cancel (Escape / controller B) fires everywhere, gameplay included, whether or not anything
# is actually listening for it - unlike confirm (tied to a real BaseButton.pressed) and move (tied
# to an actual focus change), there's no built-in signal for "this press closed/cancelled
# something." Every menu in this game grabs focus the moment it opens and nothing else ever holds
# focus, so "is any control currently focused" doubles as a reliable proxy for "a menu is open and
# ui_cancel is about to do something" without this node needing to know about each screen.
func _input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and get_viewport().gui_get_focus_owner() != null:
		cancel_player.play()


func _on_gui_focus_changed(_control : Control) -> void:
	move_player.play()


# Hooks every Button/CheckButton/OptionButton/etc. (anything deriving BaseButton) the moment it
# enters the tree, including rows built at runtime (control rebind list, quest entries, item
# pickers...) - there's no single built-in "any button was pressed" signal to hang this off of.
func _on_node_added(node : Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_on_button_pressed.bind(node))


func _on_button_pressed(button : BaseButton) -> void:
	if button.is_in_group(CANCEL_SOUND_GROUP):
		cancel_player.play()
	else:
		confirm_player.play()


# For a press that undoes something without being a Button at all - the name screen's Back-as-
# backspace, which is swallowed in _input() long before either of the hooks above could see it.
func play_cancel() -> void:
	cancel_player.play()

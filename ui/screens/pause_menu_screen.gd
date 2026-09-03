extends CanvasLayer

# Two of the four ways out of this menu abandon whatever the player is stood in the middle of, so
# neither is a single press any more: RETURN TO TOWN and MAIN MENU both ask first, through the
# embedded panel below. The prompt is a Control in this scene rather than a ConfirmationDialog for
# the same reason the save slots' delete prompt is (see ui/screens/save_slot_screen.gd) - a native
# Window never reliably receives gamepad input, and a pause menu is exactly where a player is
# holding a pad.

# Which way out the prompt is currently asking about. One panel serves both buttons, so it has to
# be told each time rather than knowing.
enum Leaving { Nothing, Hub, MainMenu }

var settings_menu_screen = preload("res://ui/screens/settings_menu_screen.tscn")
var debug_menu_screen = preload("res://ui/screens/debug_menu_screen.tscn")

@onready var continue_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var debug_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/DebugButton
@onready var return_to_hub_button : Button = \
	$MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ReturnToHubButton
@onready var main_menu_button : Button = \
	$MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuButton

@onready var confirm_panel : PanelContainer = $ConfirmPanel
@onready var confirm_backdrop : Button = $ConfirmBackdrop
@onready var confirm_title : Label = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmTitle
@onready var confirm_text : Label = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmText
@onready var confirm_stay_button : Button = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmButtons/StayButton
@onready var confirm_leave_button : Button = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmButtons/LeaveButton

var _pending_exit : Leaving = Leaving.Nothing

# The button the prompt was opened from, so backing out puts focus back where the player was
# rather than at the top of the menu.
var _confirm_opener : Control = null


func _ready():
	SettingsManager.apply_ui_scale(self)
	# A cheat panel has no business in a shipped build. OS.is_debug_build() is true when running
	# from the editor and in a debug export, and false in exactly the one build a player gets.
	debug_button.visible = OS.is_debug_build()
	continue_button.grab_focus()


func _on_settings_button_pressed():
	var settings_menu_screen_instance = settings_menu_screen.instantiate()
	get_tree().get_root().add_child(settings_menu_screen_instance)
	settings_menu_screen_instance.tree_exited.connect(continue_button.grab_focus)


func _on_debug_button_pressed():
	var debug_menu_screen_instance = debug_menu_screen.instantiate()
	get_tree().get_root().add_child(debug_menu_screen_instance)
	debug_menu_screen_instance.tree_exited.connect(continue_button.grab_focus)


# B / Escape backs out one level at a time: the prompt first if it is up, and only then the pause
# menu itself - the same gesture the save slot screen uses.
func _unhandled_input(event : InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if is_confirming():
		close_confirm()
		return
	_on_continue_button_pressed()


func _on_continue_button_pressed():
	GameManager.continue_game()
	queue_free()


func _on_return_to_hub_button_pressed() -> void:
	_open_confirm(Leaving.Hub, return_to_hub_button)


func _on_main_menu_button_pressed() -> void:
	_open_confirm(Leaving.MainMenu, main_menu_button)


func is_confirming() -> bool:
	return confirm_panel.visible


func _open_confirm(exit : Leaving, opener : Control) -> void:
	_pending_exit = exit
	_confirm_opener = opener

	if exit == Leaving.Hub:
		confirm_title.text = tr("RETURN TO TOWN")
		confirm_text.text = tr("Ride back to town? Whatever you are in the middle of out here " + \
			"starts over the next time you take it on.")
		confirm_leave_button.text = tr("Ride Back")
	else:
		confirm_title.text = tr("MAIN MENU")
		confirm_text.text = tr("Leave for the main menu? Your game is saved first, and you pick " + \
			"this playthrough back up in town.")
		confirm_leave_button.text = tr("Leave")

	confirm_backdrop.visible = true
	confirm_panel.visible = true
	# Stay, not the exit. The answer that throws away what the player is doing should never be the
	# one they confirm by reflex.
	confirm_stay_button.grab_focus()


func close_confirm() -> void:
	_pending_exit = Leaving.Nothing
	confirm_panel.visible = false
	confirm_backdrop.visible = false
	if _confirm_opener != null and is_instance_valid(_confirm_opener):
		_confirm_opener.grab_focus()
	_confirm_opener = null


func _on_leave_confirmed() -> void:
	var exit := _pending_exit
	_pending_exit = Leaving.Nothing
	_confirm_opener = null
	confirm_panel.visible = false
	confirm_backdrop.visible = false

	# Every other deliberate way out of a running game writes a save on the way (GameManager's
	# exit_game(), and the window's close button). Walking out through this menu is the same thing
	# from the player's side, so it saves too rather than costing them the money they picked up and
	# the objectives they ticked off getting this far.
	SaveManager.save_game()
	if exit == Leaving.Hub:
		GameManager.return_to_hub()
	else:
		GameManager.main_menu()
	queue_free()

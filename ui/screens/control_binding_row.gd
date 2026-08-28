extends HBoxContainer

signal rebind_requested(action_name : String)

enum ListenMode { NONE, KEYBOARD, JOYPAD }

var action_name : String = ""
var listen_mode : ListenMode = ListenMode.NONE

@onready var name_label : Label = $NameLabel
@onready var bind_button : Button = $BindButton
@onready var joypad_bind_button : Button = $JoypadBindButton


func _ready() -> void:
	bind_button.pressed.connect(_on_bind_button_pressed)
	joypad_bind_button.pressed.connect(_on_joypad_bind_button_pressed)


func set_action(action : String, display_name : String) -> void:
	action_name = action
	name_label.text = display_name
	joypad_bind_button.disabled = not SettingsManager.is_joypad_rebindable(action_name)
	refresh()


func is_currently_listening() -> bool:
	return listen_mode != ListenMode.NONE


func refresh() -> void:
	listen_mode = ListenMode.NONE
	bind_button.text = SettingsManager.get_binding_display_text(action_name)
	joypad_bind_button.text = SettingsManager.get_joypad_binding_display_text(action_name)
	UiNavigationRepeater.suspended = false


func _on_bind_button_pressed() -> void:
	if listen_mode != ListenMode.NONE:
		return
	listen_mode = ListenMode.KEYBOARD
	bind_button.text = "Press a key..."
	bind_button.release_focus()
	UiNavigationRepeater.suspended = true


func _on_joypad_bind_button_pressed() -> void:
	if listen_mode != ListenMode.NONE or joypad_bind_button.disabled:
		return
	listen_mode = ListenMode.JOYPAD
	joypad_bind_button.text = "Press a button..."
	joypad_bind_button.release_focus()
	UiNavigationRepeater.suspended = true


# Escape cancels listening instead of binding to it, since Escape is already "pause"/ui_cancel.
func _unhandled_input(event : InputEvent) -> void:
	if listen_mode == ListenMode.NONE:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		refresh()
		return

	if listen_mode == ListenMode.KEYBOARD:
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			_finish_keyboard_rebind(event)
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_finish_keyboard_rebind(event)
	elif listen_mode == ListenMode.JOYPAD:
		if event is InputEventJoypadButton and event.pressed:
			get_viewport().set_input_as_handled()
			_finish_joypad_rebind(event)


func _finish_keyboard_rebind(event : InputEvent) -> void:
	listen_mode = ListenMode.NONE
	SettingsManager.rebind_action(action_name, event)
	rebind_requested.emit(action_name)


func _finish_joypad_rebind(event : InputEventJoypadButton) -> void:
	listen_mode = ListenMode.NONE
	SettingsManager.rebind_action_joypad(action_name, event)
	rebind_requested.emit(action_name)

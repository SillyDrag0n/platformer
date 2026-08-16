extends Control

signal closed

@onready var poster: Control = $CenterContainer/VBoxContainer/NoticeBoardBounty
@onready var accept_button: Button = $CenterContainer/VBoxContainer/ButtonRow/AcceptButton

var bounty_data: BountyData

func _ready() -> void:
	poster.set_interactive(false)


func open(bounty: BountyData) -> void:
	bounty_data = bounty
	poster.setup(bounty)
	visible = true
	accept_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_accept_pressed() -> void:
	GameStateManager.set_active_bounty(bounty_data)
	GameStateManager.load_active_bounty_level()


func _on_decline_pressed() -> void:
	_close()


func _close() -> void:
	visible = false
	bounty_data = null
	closed.emit()

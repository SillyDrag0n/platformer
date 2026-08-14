extends CanvasLayer

@onready var continue_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton


func _ready():
	continue_button.grab_focus()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_continue_button_pressed()
		get_viewport().set_input_as_handled()


func _on_continue_button_pressed():
	GameManager.continue_game()
	queue_free()


func _on_main_menu_button_pressed():
	GameManager.main_menu()
	queue_free()

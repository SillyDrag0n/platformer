extends CanvasLayer

var settings_menu_screen = preload("res://ui/screens/settings_menu_screen.tscn")
var debug_menu_screen = preload("res://ui/screens/debug_menu_screen.tscn")

@onready var continue_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var debug_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/DebugButton


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

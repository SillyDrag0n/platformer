extends CanvasLayer

var settings_menu_screen = preload("res://ui/screens/settings_menu_screen.tscn")

@onready var play_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton


func _ready():
	SettingsManager.apply_ui_scale(self)
	play_button.grab_focus()


# Freed rather than hidden. Hiding it looked like it worked and didn't: CanvasLayer.visible only
# reaches the layer's *direct* CanvasItem children, and this menu's desert backdrop is a set of
# TileMapLayers nested under a plain Node called "TileMap" - so the panel disappeared and the
# scenery carried on drawing, over the loading screen and into the next level's fade.
#
# The slot screen sees itself back here if the player backs out (GameManager.main_menu()).
func _on_play_button_pressed():
	GameManager.start_game()
	queue_free()


func _on_exit_button_pressed():
	GameManager.exit_game()


func _on_settings_button_pressed():
	var settings_menu_screen_instance = settings_menu_screen.instantiate()
	get_tree().get_root().add_child(settings_menu_screen_instance)
	settings_menu_screen_instance.tree_exited.connect(play_button.grab_focus)


# Wiping a save is per-slot now, on the slot screen (Delete), rather than one button that erased
# the only save there was.

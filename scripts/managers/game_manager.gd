extends Node

var main_menu_screen = preload("res://ui/screens/main_menu_screen.tscn")
var pause_menu_screen = preload("res://ui/screens/pause_menu_screen.tscn")
var save_slot_screen = preload("res://ui/screens/save_slot_screen.tscn")

func _ready():
	#RenderingServer.set_default_clear_color(Color(0.44,0.12,0.53,1.00))

	SettingsManager.load_settings()


# PLAY opens the save slots rather than the game. Nothing is loaded at boot any more, so which of
# the three files to read is the first thing the player has to answer - and it is also where they
# start a second playthrough or throw one away. The slot screen sees itself the rest of the way in
# (see ui/screens/save_slot_screen.gd).
func start_game() -> CanvasLayer:
	if get_tree().paused:
		continue_game()
		return null

	var slot_screen : CanvasLayer = save_slot_screen.instantiate()
	get_tree().get_root().add_child(slot_screen)
	return slot_screen


func exit_game():
	SaveManager.save_game()
	get_tree().quit()


func pause_game():
	get_tree().paused = true
	
	var pause_menu_screen_instance = pause_menu_screen.instantiate()
	get_tree().get_root().add_child(pause_menu_screen_instance)


func continue_game():
	get_tree().paused = false


func main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_packed(main_menu_screen)
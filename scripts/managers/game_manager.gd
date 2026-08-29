extends Node

var main_menu_screen = preload("res://ui/screens/main_menu_screen.tscn")
var pause_menu_screen = preload("res://ui/screens/pause_menu_screen.tscn")
var name_entry_screen = preload("res://ui/screens/name_entry_screen.tscn")

func _ready():
	#RenderingServer.set_default_clear_color(Color(0.44,0.12,0.53,1.00))

	SettingsManager.load_settings()


func start_game():
	if get_tree().paused:
		continue_game()
		return

	# A brand new save has no player_name yet - ask for one before the Hub loads rather than
	# starting the player off as an empty string. An existing save already has one, restored by
	# SaveManager.load_game() at boot, so this only ever shows once per save.
	if SaveManager.has_save():
		SceneManager.transition_to_scene("Hub")
	else:
		var name_entry_screen_instance = name_entry_screen.instantiate()
		get_tree().get_root().add_child(name_entry_screen_instance)


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
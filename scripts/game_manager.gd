extends Node

var main_menu_screen = preload("res://ui/screens/main_menu_screen.tscn")
var pause_menu_screen = preload("res://ui/screens/pause_menu_screen.tscn")
var player: Node2D

func _ready():
	#RenderingServer.set_default_clear_color(Color(0.44,0.12,0.53,1.00))
	
	SettingsManager.load_settings()


func start_game():
	if get_tree().paused:
		continue_game()
		return
	
	SceneManager.transition_to_scene("Level1")


func exit_game():
	get_tree().quit()


func pause_game():
	get_tree().paused = true
	
	var pause_menu_screen_instance = pause_menu_screen.instantiate()
	get_tree().get_root().add_child(pause_menu_screen_instance)


func continue_game():
	get_tree().paused = false


func main_menu():
	var main_menu_screen_instance = main_menu_screen.instantiate()
	get_tree().get_root().add_child(main_menu_screen_instance)

func get_global_player_position() -> Vector2:
	if player:
		return player.global_position
	return Vector2.ZERO
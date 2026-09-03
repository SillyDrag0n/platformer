extends Node

var main_menu_screen = preload("res://ui/screens/main_menu_screen.tscn")
var pause_menu_screen = preload("res://ui/screens/pause_menu_screen.tscn")
var save_slot_screen = preload("res://ui/screens/save_slot_screen.tscn")

func _ready():
	#RenderingServer.set_default_clear_color(Color(0.44,0.12,0.53,1.00))

	SettingsManager.load_settings()
	# Godot closes the window itself unless asked not to, which meant a player who quit the way
	# almost everyone quits - the X, or Alt+F4 - was never given the chance to save. Only the Exit
	# Game button in the menus called save_game(), so a session's progress since the last story
	# beat simply went away: money picked up, items bought, objectives ticked off, the lot.
	get_tree().auto_accept_quit = false


# Reached for the window's close button and Alt+F4 (and nothing else - exit_game() below saves on
# its own before quitting, and is not routed through here).
func _notification(what : int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	SaveManager.save_game()
	get_tree().quit()


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


# Leaving a level part-way and riding back to town, from the pause menu. Unpaused first for the
# same reason main_menu() does it - the fade the transition rides on runs on the tree, and a paused
# tree would leave the player looking at a half-faded screen that never resolves. The bounty's own
# progress is not touched: objectives already ticked off stay ticked, and the leg itself starts
# over the next time it is taken on, since a level has no mid-level save point.
func return_to_hub() -> void:
	get_tree().paused = false
	SceneManager.transition_to_scene_faded("Hub")

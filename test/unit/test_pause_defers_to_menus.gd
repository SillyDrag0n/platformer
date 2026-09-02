extends GutTest

# Escape is bound to both "pause" and "ui_cancel". The menus that answer ui_cancel - the inventory
# and every MenuPopup (shop, dialogue) - poll for it in _process, which runs after input, so one
# press used to open the pause menu *and* freeze the tree before the menu underneath ever got the
# _process call it needed to close itself. The player was left staring at a pause screen with a
# shop stranded behind it. Escape has to back out one level per press instead.

const GameScreenScene = preload("res://ui/screens/game_screen.tscn")


func before_each():
	InventoryManager.is_open = false


func after_each():
	InventoryManager.is_open = false
	_dismiss_pause_menu()


func test_escape_is_left_to_an_open_menu():
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)
	# A shop, the inventory, a dialogue - they all hold this one shared flag while they are up.
	InventoryManager.is_open = true

	screen._unhandled_input(_pause_press())

	assert_false(get_tree().paused, \
		"the first press belongs to the menu that is up, not to the pause screen")
	assert_null(_find_pause_menu())


func test_escape_pauses_once_nothing_else_is_open():
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)

	screen._unhandled_input(_pause_press())

	assert_true(get_tree().paused, "with the menu closed, the next press is the pause menu's")
	assert_not_null(_find_pause_menu())


func _pause_press() -> InputEventAction:
	var press := InputEventAction.new()
	press.action = "pause"
	press.pressed = true
	return press


func _find_pause_menu() -> Node:
	for child in get_tree().get_root().get_children():
		if child.scene_file_path == "res://ui/screens/pause_menu_screen.tscn":
			return child
	return null


# Unpaused and torn down inside the same frame it was opened in, so no test that follows this one
# ever gets a frozen tree or a stray pause screen sitting over it.
func _dismiss_pause_menu() -> void:
	var pause_menu := _find_pause_menu()
	if pause_menu != null:
		pause_menu.get_parent().remove_child(pause_menu)
		pause_menu.free()
	get_tree().paused = false

extends GutTest

# A loading screen has to be the thing on screen while a level loads. Two ways that stopped being
# true, both of which put the main menu's desert backdrop over the "LOADING" screen for the two and
# a half seconds before the scene swapped:
#
#   1. The menu was hidden instead of freed, and hiding it did not hide its backdrop. That half is
#      fixed structurally and covered by test_canvas_layer_visibility.gd; the menu still frees
#      itself here, which is the simpler thing for a screen that is being left behind entirely.
#   2. The transition screens sat on the default canvas layer, underneath every menu.

const MainMenuScene = preload("res://ui/screens/main_menu_screen.tscn")
const TRANSITION_SCENES := [
	"res://ui/screen_transition/scene_transition_screen.tscn",
	"res://ui/screen_transition/FadeTransitionScreen.tscn",
]


func after_each():
	for child in get_tree().get_root().get_children():
		if child.scene_file_path == "res://ui/screens/save_slot_screen.tscn":
			child.free()


func test_the_transition_screens_sit_above_every_menu():
	var menu = MainMenuScene.instantiate()
	autofree(menu)
	var slots = load("res://ui/screens/save_slot_screen.tscn").instantiate()
	autofree(slots)
	var highest_menu_layer : int = maxi(menu.layer, slots.layer)

	for path in TRANSITION_SCENES:
		var transition = load(path).instantiate()
		autofree(transition)
		assert_gt(transition.layer, highest_menu_layer, \
			"%s has to draw over the menus, not under them" % path)




func test_pressing_play_takes_the_menu_off_the_screen_entirely():
	var menu = MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_frames(1)

	menu._on_play_button_pressed()
	await wait_frames(2)

	assert_true(menu.is_queued_for_deletion() or not is_instance_valid(menu), \
		"the menu frees itself, so there is nothing of it left to draw over the loading screen")

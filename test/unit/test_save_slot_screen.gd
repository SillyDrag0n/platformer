extends GutTest

# The screen the player picks a save on (ui/screens/save_slot_screen.gd), which now sits between
# the main menu's PLAY and the game. Its rows are built at runtime from whatever the slots hold,
# so what is worth pinning is that it offers one row per slot and reads them correctly.

const SaveSlotScreenScene = preload("res://ui/screens/save_slot_screen.tscn")

var _real_save_path : String
var _real_slot : int


func before_each():
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch/screen/"
	SaveManager.active_slot = SaveManager.NO_SLOT


func after_each():
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var path := SaveManager.slot_path(slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot


func _make_screen() -> CanvasLayer:
	var screen = SaveSlotScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_frames(1)
	return screen


func test_it_offers_one_row_per_slot():
	var screen := await _make_screen()

	assert_eq(screen.slot_list.get_child_count(), SaveManager.SLOT_COUNT, \
		"three saves means three rows to choose between")


func test_an_empty_slot_says_so_and_cannot_be_deleted():
	var screen := await _make_screen()

	var row : HBoxContainer = screen.slot_list.get_child(0)
	var play : Button = row.get_child(0)
	var erase : Button = row.get_child(1)

	assert_string_contains(play.text, "Empty", "an unused slot reads as empty rather than blank")
	assert_true(erase.disabled, "there is nothing to delete")
	assert_eq(erase.focus_mode, Control.FOCUS_NONE, \
		"and a controller should not have to step through a dead button to reach the next slot")


func test_a_used_slot_shows_who_is_in_it():
	SaveManager.start_new_game(2)
	PlayerManager.player_name = "Cassidy"
	CollectibleManager.total_award_amount = 240
	SaveManager.save_game()
	SaveManager.active_slot = SaveManager.NO_SLOT

	var screen := await _make_screen()
	var row : HBoxContainer = screen.slot_list.get_child(1)

	assert_string_contains(row.get_child(0).text, "Cassidy", "the slot is labelled with the playthrough in it")
	assert_string_contains(row.get_child(0).text, "240", "and what they are carrying")
	assert_false(row.get_child(1).disabled, "a used slot can be thrown away")


func test_choosing_an_empty_slot_starts_a_new_game_in_it():
	var screen := await _make_screen()

	screen._on_slot_pressed(3)
	await wait_frames(1)

	assert_eq(SaveManager.active_slot, 3, "the new playthrough belongs to the slot that was picked")
	# It hands off to the name screen, which it parents to the root rather than to itself - so this
	# has to take it back down, or it sits over every test that runs after this one.
	for child in get_tree().get_root().get_children():
		if child.scene_file_path == "res://ui/screens/name_entry_screen.tscn":
			child.free()

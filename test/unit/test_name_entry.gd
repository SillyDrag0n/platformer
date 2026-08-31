extends GutTest

# Coverage for the new "enter your name" flow on a brand new save: SaveManager.has_save() is what
# GameManager.start_game() branches on to decide whether to show this screen at all, and the
# blank-input fallback is the one bit of actual logic in the screen itself.

const NameEntryScreenScene = preload("res://ui/screens/name_entry_screen.tscn")

var _real_save_path : String
var _real_slot : int


func before_each():
	# SaveManager.save_path points at the player.s real save directory - redirected to a scratch
	# location for the has_save() tests below so they can never touch or delete it.
	_real_save_path = SaveManager.save_path
	_real_slot = SaveManager.active_slot
	SaveManager.save_path = "user://test_scratch/"
	SaveManager.active_slot = 1


func after_each():
	var scratch_full_path := SaveManager.slot_path(1)
	if FileAccess.file_exists(scratch_full_path):
		DirAccess.remove_absolute(scratch_full_path)

	SaveManager.save_path = _real_save_path
	SaveManager.active_slot = _real_slot


func test_has_save_is_false_when_no_save_file_exists():
	assert_false(SaveManager.has_save(1))


func test_has_save_is_true_once_a_save_file_exists():
	var data := SaveDataResource.new()
	if !DirAccess.dir_exists_absolute(SaveManager.save_path):
		DirAccess.make_dir_absolute(SaveManager.save_path)
	ResourceSaver.save(data, SaveManager.slot_path(1))

	assert_true(SaveManager.has_save(1))


func test_blank_name_falls_back_to_a_default():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen.name_input.text = "   "
	assert_eq(screen._resolve_entered_name(), PlayerManager.DEFAULT_NAME)

func test_entered_name_is_trimmed():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen.name_input.text = "  Annie  "
	assert_eq(screen._resolve_entered_name(), "Annie")


# On-screen keyboard, for controllers - no physical keys to type a name with otherwise.
func test_keyboard_builds_one_button_per_key():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	assert_eq(screen.keyboard_grid.get_child_count(), screen.KEYBOARD_KEYS.size(), \
		"one button per entry in KEYBOARD_KEYS")
	assert_eq(screen.KEYBOARD_KEYS.size() % screen.KEYBOARD_COLUMNS, 0, \
		"sanity: the key count should divide evenly into full rows, no ragged last row")


func test_digit_and_symbol_keys_append_to_the_name():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen._on_key_pressed("J")
	screen._on_key_pressed("9")
	screen._on_key_pressed("-")
	screen._on_key_pressed("A")
	assert_eq(screen.name_input.text, "J9-A")


func test_pressing_letter_keys_appends_to_the_name():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen._on_key_pressed("H")
	screen._on_key_pressed("I")
	assert_eq(screen.name_input.text, "HI")


func test_space_key_inserts_a_space():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen._on_key_pressed("A")
	screen._on_key_pressed("SP")
	screen._on_key_pressed("B")
	assert_eq(screen.name_input.text, "A B")


func test_delete_key_removes_the_last_character():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen.name_input.text = "ANN"
	screen._on_key_pressed("DEL")
	assert_eq(screen.name_input.text, "AN")


func test_delete_key_on_empty_text_is_a_safe_no_op():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen._on_key_pressed("DEL")
	assert_eq(screen.name_input.text, "")


func test_letter_keys_respect_max_length():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen.name_input.text = "X".repeat(screen.name_input.max_length)
	screen._on_key_pressed("A")
	assert_eq(screen.name_input.text.length(), screen.name_input.max_length, \
		"typing past max_length via the on-screen keyboard should be a no-op, not truncate/error")


# Regression test: LineEdit has built-in behavior where ui_cancel (Escape / controller B) makes
# it drop focus entirely ("exit edit mode" - see godotengine/godot#114865), so pressing B while
# typing a name silently kicked the player out of the text field for no reason on this screen,
# which has nothing to cancel back to.
func test_pressing_cancel_does_not_defocus_the_name_field():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	screen.name_input.grab_focus()
	await wait_physics_frames(1)
	assert_true(screen.name_input.has_focus(), "sanity: the name field is focused")

	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_B
	event.pressed = true
	Input.parse_input_event(event)
	await wait_physics_frames(1)

	assert_true(screen.name_input.has_focus(), \
		"pressing B while typing a name should not defocus the field")


# Back (controller B / Escape) is backspace on this screen - there is nothing to cancel back to,
# and a controller otherwise has to travel across the grid to DEL for every correction.
func _press_back() -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = JOY_BUTTON_B
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_physics_frames(1)


func test_pressing_back_deletes_the_last_character():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.name_input.grab_focus()
	screen.name_input.text = "ANNIE"

	await _press_back()

	assert_eq(screen.name_input.text, "ANNI")


func test_holding_back_down_deletes_one_character_per_press():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.name_input.grab_focus()
	screen.name_input.text = "ANNIE"

	await _press_back()
	await _press_back()

	assert_eq(screen.name_input.text, "ANN", "two presses, two characters")


func test_pressing_back_on_an_empty_name_is_a_safe_no_op():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.name_input.grab_focus()

	await _press_back()

	assert_eq(screen.name_input.text, "")


func test_back_deletes_from_anywhere_on_the_screen():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.name_input.text = "ANNIE"
	screen.confirm_button.grab_focus()
	await wait_physics_frames(1)

	await _press_back()

	assert_eq(screen.name_input.text, "ANNI", \
		"the name field doesn't have to be the focused control for Back to mean backspace")


# LineEdit.text = ... parks the caret at column 0, so without this an on-screen edit followed by
# a physical keystroke would drop the next letter at the front of the name.
func test_editing_leaves_the_caret_at_the_end_of_the_name():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.name_input.grab_focus()

	screen._on_key_pressed("A")
	screen._on_key_pressed("B")
	assert_eq(screen.name_input.caret_column, 2, "typing leaves the caret after what was typed")

	await _press_back()

	assert_eq(screen.name_input.caret_column, 1, "and so does deleting")


# Both ways of deleting a character answer with the back/cancel blip rather than the confirm blip
# every other key gets - see UiSoundPlayer.CANCEL_SOUND_GROUP.
func test_the_delete_key_sounds_like_going_back():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	var delete_button : Button = null
	for child in screen.keyboard_grid.get_children():
		if child.text == "DEL":
			delete_button = child
	assert_not_null(delete_button, "sanity: the on-screen keyboard has a DEL key")
	assert_true(delete_button.is_in_group(UiSoundPlayer.CANCEL_SOUND_GROUP))

	UiSoundPlayer.confirm_player.stop()
	UiSoundPlayer.cancel_player.stop()
	delete_button.pressed.emit()

	assert_true(UiSoundPlayer.cancel_player.playing)
	assert_false(UiSoundPlayer.confirm_player.playing, "and not the blip a letter key gives")


func test_pressing_back_sounds_the_same_as_the_delete_key():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.name_input.grab_focus()
	screen.name_input.text = "ANNIE"
	UiSoundPlayer.cancel_player.stop()

	await _press_back()

	assert_true(UiSoundPlayer.cancel_player.playing, \
		"the screen swallows the event, so it has to ask for the blip itself")


# A way out, for a player who opened the wrong slot. It has to be a button: B is backspace on this
# screen, so the usual back gesture is spoken for.
func test_the_screen_offers_a_way_back_to_the_slot_picker():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	assert_eq(screen.back_button.text, "BACK")
	assert_eq(screen.confirm_button.focus_neighbor_bottom, \
		screen.confirm_button.get_path_to(screen.back_button), \
		"and it is reachable by navigating down off START, not only by mouse")


func test_backing_out_lets_go_of_the_slot_it_claimed():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	SaveManager.active_slot = 1

	screen._on_back_button_pressed()
	await wait_physics_frames(1)

	assert_eq(SaveManager.active_slot, SaveManager.NO_SLOT, \
		"an abandoned playthrough must not still own a slot for the next autosave to write into")

	# start_game() puts the slot picker back on screen - clean it up rather than leave it in root.
	for child in get_tree().get_root().get_children():
		if child.get_script() == preload("res://ui/screens/save_slot_screen.gd"):
			child.queue_free()
	await wait_physics_frames(1)


func test_backing_out_leaves_no_save_behind():
	var screen = NameEntryScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	SaveManager.start_new_game(1)

	screen._on_back_button_pressed()
	await wait_physics_frames(1)

	assert_false(SaveManager.has_save(1), \
		"the slot the player opened and backed out of should still read as empty")

	for child in get_tree().get_root().get_children():
		if child.get_script() == preload("res://ui/screens/save_slot_screen.gd"):
			child.queue_free()
	await wait_physics_frames(1)

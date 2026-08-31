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

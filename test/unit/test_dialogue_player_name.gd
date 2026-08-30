extends GutTest

# Anything the player character says has to be credited to the name the player entered at the start
# of the game (ui/screens/name_entry_screen.gd -> PlayerManager.player_name), not to a hard-coded
# stand-in. DialogueBox.PLAYER_TOKEN is how a scene asks for that, so what's pinned here is the
# substitution itself: speaker, line body, the choice variant, and the fallback for a save that
# never got asked.

const DialogueBoxScene = preload("res://ui/dialogue/DialogueBox.tscn")

var _original_name : String


func before_each():
	_original_name = PlayerManager.player_name
	InventoryManager.is_open = false


func after_each():
	PlayerManager.player_name = _original_name
	InventoryManager.is_open = false


func _make_box() -> DialogueBox:
	var box = DialogueBoxScene.instantiate()
	add_child_autofree(box)
	return box


func test_the_player_speaks_under_the_name_they_entered():
	PlayerManager.player_name = "Cassidy"
	var box := _make_box()

	box.show_dialogue(DialogueBox.PLAYER_TOKEN, ["Spines on a coyote."] as Array[String])

	assert_eq(box.speaker_label.text, "Cassidy", \
		"the player character's lines are credited to the name they entered, not a placeholder")


func test_the_token_works_inside_a_line_too():
	PlayerManager.player_name = "Cassidy"
	var box := _make_box()

	box.show_dialogue("Hutch", ["Name's {player}, ain't it?"] as Array[String])

	assert_eq(box.speaker_label.text, "Hutch", "an NPC speaker is left exactly as written")
	assert_eq(box.text_label.text, "Name's Cassidy, ain't it?", \
		"so an NPC can say the player's name back to them without reading PlayerManager itself")


func test_the_choice_box_resolves_the_name_the_same_way():
	PlayerManager.player_name = "Cassidy"
	var box := _make_box()

	box.show_choice(DialogueBox.PLAYER_TOKEN, "Reckon I'll buy.", "Yes", "No", func(): pass, func(): pass)

	assert_eq(box.speaker_label.text, "Cassidy")
	assert_eq(box.text_label.text, "Reckon I'll buy.")


func test_a_save_that_was_never_asked_still_gets_a_name():
	PlayerManager.player_name = ""
	var box := _make_box()

	box.show_dialogue(DialogueBox.PLAYER_TOKEN, ["Somethin' strange out here."] as Array[String])

	assert_eq(box.speaker_label.text, PlayerManager.DEFAULT_NAME, \
		"a level run straight from the editor, or a save made before the name screen existed, " + \
		"should fall back to the same default a blank entry does - never a blank speaker")

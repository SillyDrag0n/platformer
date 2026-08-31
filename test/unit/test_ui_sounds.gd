extends GutTest

# UiSoundPlayer hooks every BaseButton entering the tree and blips for it, so which blip a button
# gets is decided in one place rather than screen by screen. Most buttons commit to something and
# get the confirm blip; a button that takes something away instead (the name screen's DEL key)
# joins CANCEL_SOUND_GROUP and answers with the same back/cancel sound Back itself plays.


func before_each():
	UiSoundPlayer.confirm_player.stop()
	UiSoundPlayer.cancel_player.stop()


func after_each():
	UiSoundPlayer.confirm_player.stop()
	UiSoundPlayer.cancel_player.stop()


func _make_button(in_cancel_group : bool) -> Button:
	var button := Button.new()
	if in_cancel_group:
		button.add_to_group(UiSoundPlayer.CANCEL_SOUND_GROUP)
	# Added to the tree rather than wired by hand: node_added is the hook being exercised.
	add_child_autofree(button)
	return button


func test_an_ordinary_button_still_confirms():
	var button := _make_button(false)

	button.pressed.emit()

	assert_true(UiSoundPlayer.confirm_player.playing)
	assert_false(UiSoundPlayer.cancel_player.playing)


func test_a_button_that_takes_something_away_uses_the_back_sound():
	var button := _make_button(true)

	button.pressed.emit()

	assert_true(UiSoundPlayer.cancel_player.playing, \
		"undoing should sound like undoing, not like committing")
	assert_false(UiSoundPlayer.confirm_player.playing)


func test_a_press_that_is_not_a_button_at_all_can_ask_for_the_back_sound():
	# The name screen's Back-as-backspace swallows its own input event, so nothing upstream is
	# left to blip for it - see name_entry_screen.gd's _input().
	UiSoundPlayer.play_cancel()

	assert_true(UiSoundPlayer.cancel_player.playing)

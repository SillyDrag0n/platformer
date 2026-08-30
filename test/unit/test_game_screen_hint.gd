extends GutTest

# Coverage for GameScreen's reusable on-screen contextual hint widget (show_hint/_dismiss_hint),
# the thing HintZone triggers point at to teach the player controls during the tutorial bounty.

const GameScreenScene = preload("res://ui/screens/game_screen.tscn")


func test_show_hint_displays_the_composed_text():
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)

	screen.show_hint(&"jump", "Press %s to Jump")

	assert_true(screen.action_hint.visible)
	assert_true(screen.action_hint_label.text.begins_with("Press "))
	assert_true(screen.action_hint_label.text.ends_with(" to Jump"))


func test_second_hint_is_ignored_while_one_is_showing():
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)

	screen.show_hint(&"jump", "Press %s to Jump")
	var first_text = screen.action_hint_label.text

	screen.show_hint(&"crouch", "Press %s to Crouch")

	assert_eq(screen.action_hint_label.text, first_text, \
		"a hint already showing should not be replaced by a new one")


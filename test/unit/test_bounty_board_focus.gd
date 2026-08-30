extends GutTest

# Regression test for a reported bug: with nothing posted on the bounty board, a controller could
# not reach the Return button. BountyBoard.spawn_bounties() only ever grabbed focus on the first
# poster, so an empty board left no focus owner at all - and directional input needs something
# already focused to move from, which made the screen a dead end for anyone not using a mouse.
#
# An empty board is not a rare state: the game's first bounty isn't posted until the player has
# talked to the old timer in the hub, so this is what a new save walks into.
#
# Focus is asserted off the viewport's real focus owner rather than off the board's own bookkeeping,
# same as test_shop_ui_focus.gd - what matters is where input would actually go.

const BountyBoardScene = preload("res://ui/notice_board/bounty_board.tscn")
const BOUNTY_ID := "missing_cattle"

var _original_unlocks : Dictionary
var _board : Control


func before_each():
	# Unlock state lives on shared BountyData resources, so each test sets the board up it wants
	# and hands the real ones back afterwards.
	_original_unlocks = {}
	for bounty in GameStateManager.bounties:
		_original_unlocks[bounty.id] = bounty.unlocked
		bounty.unlocked = false


func after_each():
	if is_instance_valid(_board):
		_board.queue_free()
		_board = null
	for bounty in GameStateManager.bounties:
		bounty.unlocked = _original_unlocks.get(bounty.id, bounty.unlocked)


# Added to the root rather than as a child of the test, since focus is a viewport-wide thing and
# this needs to be the real one.
func _open_board() -> Control:
	_board = BountyBoardScene.instantiate()
	get_tree().get_root().add_child(_board)
	await wait_physics_frames(2)
	return _board


func test_an_empty_board_focuses_the_return_button():
	var board := await _open_board()

	assert_eq(board.poster_grid.get_child_count(), 0, "nothing is posted")
	assert_eq(board.get_viewport().gui_get_focus_owner(), board.return_button, \
		"with no posters to focus, Return has to take it - otherwise a controller has nothing " + \
		"to move from and no way off the screen at all")


func test_a_board_with_a_bounty_still_focuses_the_first_poster():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()

	assert_gt(board.poster_grid.get_child_count(), 0, "the posted bounty is on the board")
	var focus_owner := board.get_viewport().gui_get_focus_owner()
	assert_ne(focus_owner, board.return_button, \
		"a board with work on it opens on the work, not on the way out")
	assert_true(board.poster_grid.get_child(0).is_ancestor_of(focus_owner), \
		"and it's the first poster's own button that holds focus")


func test_the_return_button_is_reachable_from_a_poster():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()

	var poster_button := board.get_viewport().gui_get_focus_owner()
	assert_eq(poster_button.find_valid_focus_neighbor(SIDE_BOTTOM), board.return_button, \
		"pressing down off the bottom row of posters should land on Return, so the way out is " + \
		"reachable with a controller from a full board too")


# Godot's directional focus search reads geometry, and these posters are inside a ScrollContainer,
# tilted at a random angle and bobbing every frame - so the way off the board is wired by hand
# rather than left to that search to work out.
func test_every_poster_has_a_wired_way_down_to_the_return_button():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()

	for poster in board.poster_grid.get_children():
		var button : Button = poster.get_focus_button()
		var neighbour : Node = button.get_node_or_null(button.focus_neighbor_bottom)
		assert_not_null(neighbour, "every poster needs somewhere to go on a press down")
		assert_eq(neighbour, board.return_button, \
			"the bottom row drops onto Return, so the way out is one press from the board")


func test_the_return_button_leads_back_up_onto_the_board():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()

	var neighbour : Node = board.return_button.get_node_or_null(board.return_button.focus_neighbor_top)
	assert_eq(neighbour, board.poster_grid.get_child(0).get_focus_button(), \
		"and pressing up off Return goes back to the postings rather than nowhere")


# Driven through the actual ui_down action, not just the wiring, so this covers what the player's
# controller does rather than what the neighbours claim.
func test_pressing_down_from_a_poster_lands_on_the_return_button():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()

	var press := InputEventAction.new()
	press.action = "ui_down"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(2)
	var release := InputEventAction.new()
	release.action = "ui_down"
	release.pressed = false
	Input.parse_input_event(release)
	await wait_frames(2)

	assert_eq(board.get_viewport().gui_get_focus_owner(), board.return_button, \
		"one press down off the board is the way out")


# Belt and braces for a screen a controller has to be able to leave: B / Escape backs out of the
# board itself, so getting home never depends on focus navigation reaching a particular button.
func test_cancel_leaves_the_board_without_touching_the_return_button():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()
	var scenes_backup : Dictionary = SceneManager.scenes.duplicate()
	# Nowhere real to go: a valid key would swap the test runner's own scene out.
	SceneManager.scenes["Hub"] = ""

	var cancelled := false
	var watcher := func(): cancelled = true
	board.return_button.pressed.connect(watcher)

	var press := InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(2)

	SceneManager.scenes = scenes_backup
	assert_true(board.get_viewport().is_input_handled() or not cancelled, \
		"the press is consumed by the board rather than left to fall through")


func test_cancel_is_left_to_the_dossier_while_it_is_open():
	GameStateManager.get_bounty_by_id(BOUNTY_ID).unlocked = true
	var board := await _open_board()
	board.inspect_panel.open(GameStateManager.get_bounty_by_id(BOUNTY_ID))
	await wait_frames(1)

	var press := InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(2)

	assert_false(board.inspect_panel.visible, \
		"backing out of an open dossier returns to the board, and must not walk out of the " + \
		"board in the same press")

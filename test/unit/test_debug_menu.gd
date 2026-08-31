extends GutTest

# The pause menu's DEBUG MODE panel (ui/screens/debug_menu_screen.gd) - the cheat buttons used to
# test a shop or a later level without playing up to it. What is pinned here is that each button
# actually moves the manager it claims to, and that the panel greys out what it has already done
# rather than leaving a live-looking button that does nothing.
#
# Every test winds the managers back afterwards: they are autoloads holding a whole playthrough,
# so a debug unlock left behind would follow the next test file in.

const PauseMenuScene = preload("res://ui/screens/pause_menu_screen.tscn")
const DebugMenuScene = preload("res://ui/screens/debug_menu_screen.tscn")
const DYNAMITE : ItemData = preload("res://items/utility/dynamite.tres")

const BUTTONS_PATH := "MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ButtonList"


func before_each():
	CollectibleManager.reset_progress()
	AbilityManager.reset_progress()
	GameStateManager.reset_progress()
	InventoryManager.is_open = false
	InventoryManager.reset_progress()


func after_each():
	CollectibleManager.reset_progress()
	AbilityManager.reset_progress()
	GameStateManager.reset_progress()
	InventoryManager.is_open = false
	InventoryManager.reset_progress()


func _make_panel() -> CanvasLayer:
	var panel = DebugMenuScene.instantiate()
	add_child_autofree(panel)
	return panel


# Labels carry live counts ("Give Dynamite (0/3)"), so buttons are found by what they start with.
func _button(panel : CanvasLayer, label_prefix : String) -> Button:
	for child in panel.get_node(BUTTONS_PATH).get_children():
		if child is Button and child.text.begins_with(label_prefix):
			return child
	return null


func _press(panel : CanvasLayer, label_prefix : String) -> Button:
	var button := _button(panel, label_prefix)
	assert_not_null(button, "no debug button labelled '%s'" % label_prefix)
	if button != null:
		button.pressed.emit()
	return button


# --- Getting to it ---

func test_the_pause_menu_carries_a_debug_mode_button():
	var pause = PauseMenuScene.instantiate()
	add_child_autofree(pause)
	await wait_frames(1)

	assert_eq(pause.debug_button.text, "DEBUG MODE")
	assert_true(pause.debug_button.visible, \
		"shown in a debug build - a release export is the one build it hides in")


func test_the_button_opens_the_panel():
	var pause = PauseMenuScene.instantiate()
	add_child_autofree(pause)
	await wait_frames(1)

	pause._on_debug_button_pressed()
	await wait_frames(1)

	var opened : Node = null
	for child in get_tree().get_root().get_children():
		if child.scene_file_path == DebugMenuScene.resource_path:
			opened = child
	assert_not_null(opened, "pressing DEBUG MODE puts the panel on screen")
	if opened != null:
		opened.queue_free()
		await wait_frames(1)


# --- Money ---

func test_it_hands_over_fifty_dollars():
	var panel := _make_panel()
	var before : int = CollectibleManager.total_award_amount

	_press(panel, "+ $50")

	assert_eq(CollectibleManager.total_award_amount, before + 50)
	assert_string_contains(panel.state_label.text, "Dollars: %d" % (before + 50), \
		"and the readout at the top follows along")


func test_the_money_buttons_stack_up():
	var panel := _make_panel()

	_press(panel, "+ $50")
	_press(panel, "+ $50")
	_press(panel, "+ $500")

	assert_eq(CollectibleManager.total_award_amount, 600, "pressed three times, paid three times")


# --- Abilities ---

func test_it_unlocks_the_grappling_hook():
	var panel := _make_panel()
	assert_false(AbilityManager.is_unlocked("grapple_hook"), "sanity: locked to start with")

	_press(panel, "Unlock Grappling Hook")

	assert_true(AbilityManager.is_unlocked("grapple_hook"))


func test_it_unlocks_the_double_jump():
	var panel := _make_panel()

	_press(panel, "Unlock Double Jump")

	assert_true(AbilityManager.is_unlocked("double_jump"))
	assert_false(AbilityManager.is_unlocked("dash"), "and only the one that was asked for")


func test_an_ability_already_unlocked_greys_its_button_out():
	var panel := _make_panel()

	var button := _press(panel, "Unlock Dash")

	assert_eq(button.text, "Dash (unlocked)", "the button says what happened")
	assert_true(button.disabled, "rather than staying live and quietly doing nothing")


func test_there_is_a_button_for_every_authored_ability():
	var panel := _make_panel()

	# Read off AbilityManager rather than listed here, so a newly authored ability shows up in
	# the panel without anyone remembering to add it.
	for ability in AbilityManager.abilities:
		assert_not_null(_button(panel, "Unlock %s" % ability.display_name), \
			"%s should be unlockable from the debug panel" % ability.display_name)


func test_unlock_all_abilities_opens_every_one():
	var panel := _make_panel()

	_press(panel, "Unlock All Abilities")

	for ability in AbilityManager.abilities:
		assert_true(AbilityManager.is_unlocked(ability.id), "%s should be unlocked" % ability.id)


# --- Items ---

func test_it_grants_an_item_into_the_bag():
	var panel := _make_panel()

	var button := _press(panel, "Give Dynamite")

	assert_eq(InventoryManager.get_owned_quantity(DYNAMITE), 1)
	assert_eq(button.text, "Give Dynamite (1/3)", "the label counts what is already in the bag")


func test_granting_stops_at_a_full_stack():
	var panel := _make_panel()

	for i in DYNAMITE.max_stack_size:
		_press(panel, "Give Dynamite")

	assert_eq(InventoryManager.get_owned_quantity(DYNAMITE), DYNAMITE.max_stack_size)
	assert_true(_button(panel, "Give Dynamite").disabled, \
		"a full stack has nowhere to put another, so the button stops offering")


# --- World ---

func test_it_opens_every_bounty():
	var panel := _make_panel()

	_press(panel, "Unlock All Bounties")

	for bounty in GameStateManager.bounties:
		assert_true(bounty.unlocked, "bounty '%s' should be unlocked" % bounty.id)


func test_it_opens_every_region():
	var panel := _make_panel()

	_press(panel, "Unlock All Regions")

	for region in GameStateManager.regions:
		assert_true(region.unlocked, "region '%s' should be unlocked" % region.id)


# --- Player ---

func test_it_heals_the_player_back_to_full():
	var panel := _make_panel()
	HealthManager.current_health = 1

	_press(panel, "Heal to Full")

	assert_eq(HealthManager.current_health, HealthManager.max_health)

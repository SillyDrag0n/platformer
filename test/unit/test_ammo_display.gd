extends GutTest

# Coverage for the HUD's bottom-left ammo readout (ui/ammo_display/ammo_display.gd). The gun it
# reads from lives inside player.tscn (there's no standalone gun scene to instance), so the binding
# is exercised against a stand-in that offers the same three things the display actually touches:
# a magazine_changed signal, magazine_current, and get_magazine_size().

const AmmoDisplayScene = preload("res://ui/ammo_display/ammo_display.tscn")
const GameScreenScene = preload("res://ui/screens/game_screen.tscn")


class FakeGun:
	extends Node
	signal magazine_changed(current : int, capacity : int)
	var magazine_current : int = 6
	var magazine_size : int = 6

	func get_magazine_size() -> int:
		return magazine_size


func _make_display() -> AmmoDisplay:
	var display = AmmoDisplayScene.instantiate()
	add_child_autofree(display)
	return display


func _make_player_holding(gun : FakeGun) -> Node2D:
	var player := Node2D.new()
	gun.name = "Gun"
	player.add_child(gun)
	add_child_autofree(player)
	return player


func _loaded_count(display : AmmoDisplay) -> int:
	var loaded : int = 0
	for pip in display._pips:
		if (pip.get_child(1) as ColorRect).color == AmmoDisplay.CASE_COLOR:
			loaded += 1
	return loaded


func test_it_draws_one_pip_per_round_the_magazine_holds():
	var display := _make_display()

	display.set_magazine(6, 6)

	assert_eq(display._pips.size(), 6, "a full revolver reads as six rounds")
	assert_eq(_loaded_count(display), 6)


func test_spent_rounds_stay_on_screen_greyed_out():
	var display := _make_display()

	display.set_magazine(2, 6)

	assert_eq(display._pips.size(), 6, \
		"spent rounds keep their slot, so the magazine's full size stays readable")
	assert_eq(_loaded_count(display), 2, "only what's actually left is lit")


func test_a_weapon_with_a_different_magazine_rebuilds_the_row():
	var display := _make_display()
	display.set_magazine(6, 6)

	display.set_magazine(2, 2)

	assert_eq(display._pips.size(), 2, "swapping the revolver for the shotgun re-draws the row")
	assert_eq(display.get_child_count(), 2, \
		"and the pips it dropped are off the HBox immediately, not still laid out for a frame")


func test_it_shows_nothing_while_no_weapon_is_loaded():
	var display := _make_display()

	display.set_magazine(0, 0)

	assert_false(display.visible, "an empty gap in the corner is worse than no readout at all")


func test_binding_to_a_player_picks_up_the_gun_it_is_holding():
	var display := _make_display()
	var gun := FakeGun.new()
	gun.magazine_current = 4
	gun.magazine_size = 6

	display.bind_to_player(_make_player_holding(gun))

	assert_eq(display._pips.size(), 6, "the readout starts from the gun's current state")
	assert_eq(_loaded_count(display), 4, \
		"rather than assuming a full magazine the player may already have fired from")


func test_it_follows_the_gun_it_is_bound_to():
	var display := _make_display()
	var gun := FakeGun.new()
	display.bind_to_player(_make_player_holding(gun))

	gun.magazine_changed.emit(3, 6)

	assert_eq(_loaded_count(display), 3, \
		"firing is pushed to the HUD by signal - it doesn't poll the gun every frame")


func test_respawning_rebinds_the_readout_to_the_new_player():
	var display := _make_display()
	var old_gun := FakeGun.new()
	display.bind_to_player(_make_player_holding(old_gun))

	var new_gun := FakeGun.new()
	new_gun.magazine_current = 6
	new_gun.magazine_size = 2
	display.bind_to_player(_make_player_holding(new_gun))

	assert_eq(display._pips.size(), 2, "a respawn hands the level a brand new player and gun")

	old_gun.magazine_changed.emit(0, 6)

	assert_eq(display._pips.size(), 2, \
		"and the gun that died with the last one must not still be driving the HUD")


func test_the_hud_carries_the_readout_in_the_bottom_left():
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)

	var display = screen.get_node_or_null("AmmoDisplay")
	assert_not_null(display, "game_screen.tscn should carry the ammo readout")
	assert_eq(display.anchor_left, 0.0)
	assert_eq(display.anchor_top, 1.0, "anchored to the bottom-left corner of the screen")
	assert_gt(display.offset_left, 0.0, "inset from the very edge")
	assert_lt(display.offset_bottom, 0.0)

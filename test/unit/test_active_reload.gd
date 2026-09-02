extends GutTest

# The revolver's speed loader (items/weapons/attachements/speed_loader.tres) - the arms dealer's
# reload upgrade. What it buys is the timing window on the reload dial: a randomly placed notch in
# the bottom of the ring that finishes the reload on the spot if the reload key is pressed while
# the draining meter is inside it.
#
# Gun lives inside player.tscn (there's no standalone gun scene), and it reads upgrades off the
# InventoryManager autoload, so both are driven for real here rather than faked - the inventory is
# wound back around each test the way test_saloon_shop.gd does.

const PlayerScene = preload("res://player/player.tscn")
const ReloadUiScene = preload("res://player/gun/ui/gun_reload_ui.tscn")
const ArmsDealerScene = preload("res://tileset/structures/arms_dealer/arms_dealer.tscn")
const REVOLVER : WeaponItemData = preload("res://items/weapons/revolver.tres")
const SHOTGUN : WeaponItemData = preload("res://items/weapons/shotgun.tres")
const SPEED_LOADER : WeaponUpgradeItemData = preload("res://items/weapons/attachements/speed_loader.tres")


func before_each():
	InventoryManager.is_open = false
	InventoryManager.reset_progress()


func after_each():
	InventoryManager.is_open = false
	InventoryManager.reset_progress()


func _make_gun() -> Node2D:
	var player = PlayerScene.instantiate()
	add_child_autofree(player)
	return player.get_node("Gun")


# --- The upgrade on the shelf ---

func test_the_arms_dealer_sells_the_speed_loader():
	var dealer = ArmsDealerScene.instantiate()
	add_child_autofree(dealer)
	await wait_frames(1)

	assert_has(dealer.shop_ui.shop_items, SPEED_LOADER, "the arms dealer stocks the reload upgrade")
	assert_eq(SPEED_LOADER.price, 75)
	assert_eq(SPEED_LOADER.max_stack_size, 1, "bought once and fitted for good")
	assert_eq(SPEED_LOADER.target_weapon, REVOLVER, "it's a revolver part")
	assert_gt(SPEED_LOADER.active_reload_window, 0.0, "and it does carry a timing window")


# --- Auto-reload on an empty cylinder ---

func test_firing_the_last_round_starts_a_reload_on_its_own():
	var gun := _make_gun()
	gun.magazine_current = 1

	gun.try_shoot()

	assert_eq(gun.magazine_current, 0)
	assert_false(gun.reload_timer.is_stopped(), \
		"an empty cylinder reloads itself rather than waiting to be asked")
	assert_true(gun.reload_ui.visible, "and the dial comes up to show it")


# --- Asking for a reload ---
#
# Both of these come off the same key press in Gun._process. Pressing it again mid-reload used to
# start the whole thing over: the timer went back to the top and the dial was rebuilt with it, so
# a player leaning on the key never reached the end of a reload, and with the speed loader fitted
# every press rolled a fresh sweet spot instead of the single attempt the upgrade is sold as.

func test_mashing_reload_cannot_restart_one_already_running():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	# Drained halfway by hand rather than waited out: what matters here is what a second press does
	# to a reload already in progress, not how long one takes to run.
	gun.reload_ui.set_value(0.5)
	var window_start : float = gun._active_reload_window_start

	gun.reload()

	assert_false(gun.can_reload(), "a reload already running is not one to start over")
	assert_eq(gun.reload_ui.bar.value, 0.5, \
		"a second press must not rebuild the dial from the top")
	assert_eq(gun._active_reload_window_start, window_start, \
		"nor roll it a fresh sweet spot to aim for")


func test_a_full_cylinder_refuses_to_reload():
	var gun := _make_gun()

	assert_eq(gun.magazine_current, REVOLVER.magazine_size, "the gun starts loaded")
	assert_false(gun.can_reload(), "and a full cylinder has nothing to put in it")

	gun.reload()

	assert_true(gun.reload_timer.is_stopped(), "so asking for one does nothing")
	assert_false(gun.reload_ui.visible, "and the dial never comes up")


# --- Which weapon the upgrade applies to ---

func test_no_window_is_armed_without_the_upgrade():
	var gun := _make_gun()
	gun.magazine_current = 0

	gun.reload()

	assert_eq(gun.get_active_reload_window(), 0.0)
	assert_false(gun.has_active_reload(), "a plain revolver just waits the reload out")
	assert_false(gun.reload_ui.window_bar.visible, "and the dial shows no notch to aim for")


func test_the_upgrade_only_applies_to_the_weapon_it_was_made_for():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)

	assert_eq(gun.get_active_reload_window(), SPEED_LOADER.active_reload_window, \
		"fitted to the revolver the gun starts with")

	InventoryManager.add_item(SHOTGUN)
	InventoryManager.equip_weapon(InventoryManager.WeaponSlot.PRIMARY, SHOTGUN)

	assert_eq(gun.get_active_reload_window(), 0.0, \
		"a revolver part must not quietly improve the shotgun too")


# --- Where the window lands ---

func test_the_window_lands_somewhere_in_the_bottom_of_the_dial():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)

	# Rolled fresh on every reload, so a handful of reloads is what pins the range down. Each pass
	# has to put the gun back somewhere a reload is allowed from - it now refuses one it is already
	# doing, and one it does not need (see Gun.can_reload).
	for i in 25:
		gun.reload_timer.stop()
		gun.magazine_current = 0
		gun.reload()
		assert_true(gun.has_active_reload(), "the upgrade arms a window on every reload")
		assert_almost_eq(gun._active_reload_window_width, SPEED_LOADER.active_reload_window, 0.0001)
		assert_between(gun._active_reload_window_start, gun.ACTIVE_RELOAD_ZONE_START, \
			gun.ACTIVE_RELOAD_ZONE_END - gun._active_reload_window_width, \
			"the whole notch has to sit inside the bottom of the ring")


func test_the_window_moves_between_reloads():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)

	var seen : Array = []
	for i in 25:
		gun.reload_timer.stop()
		gun.magazine_current = 0
		gun.reload()
		seen.append(gun._active_reload_window_start)

	assert_gt(seen.max() - seen.min(), 0.0, \
		"a notch in the same place every time would just be memorised once")


func test_the_dial_draws_the_notch_where_the_window_is():
	var ui = ReloadUiScene.instantiate()
	add_child_autofree(ui)

	ui.begin(0.4, 0.1)

	assert_true(ui.window_bar.visible)
	assert_almost_eq(ui.window_bar.radial_initial_angle, 144.0, 0.001, \
		"0.4 of the way round from 12 o'clock")
	assert_almost_eq(ui.window_bar.radial_fill_degrees, 36.0, 0.001, "covering a tenth of the ring")

	ui.begin(0.0, 0.0)

	assert_false(ui.window_bar.visible, "no upgrade fitted, no notch")
	assert_true(ui.visible, "but the ordinary reload dial still comes up")


# --- Hitting and missing ---

func test_pressing_inside_the_window_fills_the_cylinder_immediately():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	# The timer has only just started, so progress is still 1.0 - put the notch under it.
	gun._active_reload_window_start = 0.9
	gun._active_reload_window_width = 0.1

	gun._try_active_reload()

	assert_eq(gun.magazine_current, REVOLVER.magazine_size, "a hit fills the cylinder")
	assert_true(gun.reload_timer.is_stopped(), \
		"without waiting out the rest of the reload it would otherwise have taken")
	assert_false(gun.has_active_reload(), "and the window is done with until the next reload")


func test_pressing_outside_the_window_costs_only_the_attempt():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	var time_left_before : float = gun.reload_timer.time_left
	# Progress is 1.0 here, so a notch down at the bottom of the ring is a miss.
	gun._active_reload_window_start = 0.4
	gun._active_reload_window_width = 0.1

	gun._try_active_reload()

	assert_eq(gun.magazine_current, 0, "a miss doesn't load anything early")
	assert_false(gun.reload_timer.is_stopped(), "the reload just carries on")
	assert_almost_eq(gun.reload_timer.time_left, time_left_before, 0.0001, \
		"neither restarted nor lengthened as a punishment")
	assert_eq(gun.reload_ui.window_bar.tint_progress, gun.reload_ui.MISSED_COLOR, \
		"the spent notch greys out so the miss reads as a miss")


func test_only_one_attempt_is_allowed_per_reload():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	gun._active_reload_window_start = 0.4
	gun._active_reload_window_width = 0.1
	gun._try_active_reload()

	# Second press, this time with the notch sitting right under the meter - it should still
	# come to nothing, otherwise mashing reload would hit the window every single time.
	gun._active_reload_window_start = 0.9
	gun._try_active_reload()

	assert_eq(gun.magazine_current, 0, "the one attempt was already spent on the miss")
	assert_false(gun.reload_timer.is_stopped())


func test_a_finished_reload_still_fills_the_cylinder_the_slow_way():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()

	gun._on_reload_timer_timeout()

	assert_eq(gun.magazine_current, REVOLVER.magazine_size, \
		"letting the dial run out reloads exactly as it always did")
	assert_false(gun.reload_ui.visible, "and the dial clears itself")


# --- Calling the attempt ---

func test_a_hit_is_called_out_over_the_dial():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	gun._active_reload_window_start = 0.9
	gun._active_reload_window_width = 0.1

	gun._try_active_reload()

	assert_true(gun.reload_ui.message_label.visible, "a hit says so rather than just happening")
	assert_eq(gun.reload_ui.message_label.text, tr(gun.reload_ui.HIT_TEXT))
	assert_true(gun.active_reload_hit_sound.playing, "with a sound to match")


func test_a_miss_is_called_out_too():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	gun._active_reload_window_start = 0.4
	gun._active_reload_window_width = 0.1

	gun._try_active_reload()

	assert_true(gun.reload_ui.message_label.visible)
	assert_eq(gun.reload_ui.message_label.text, tr(gun.reload_ui.MISSED_TEXT))
	assert_true(gun.active_reload_miss_sound.playing)
	assert_true(gun.reload_ui.visible, \
		"and the dial stays up, because the reload it belongs to is still running")


func test_the_next_reload_clears_the_last_verdict():
	var gun := _make_gun()
	InventoryManager.add_item(SPEED_LOADER)
	gun.magazine_current = 0
	gun.reload()
	gun._active_reload_window_start = 0.4
	gun._active_reload_window_width = 0.1
	gun._try_active_reload()

	# The missed reload runs its clock out the way it would in play before the next one is asked
	# for - a second reload can no longer be started over the top of the first.
	gun._on_reload_timer_timeout()
	gun.magazine_current = 0
	gun.reload()

	assert_false(gun.reload_ui.message_label.visible, \
		"last reload's verdict must not still be hanging over this one")


func test_the_notch_is_drawn_solidly_enough_to_pick_out():
	var ui = ReloadUiScene.instantiate()
	add_child_autofree(ui)

	ui.begin(0.4, 0.1)

	assert_eq(ui.window_bar.tint_progress.a, 1.0, \
		"a see-through notch mixes into the green fill underneath it and stops reading as a target")

extends GutTest

# The ride-out screen (ui/screen_transition/scene_transition_screen.gd). The rider *is* the
# readout - its position along the trail is the progress - so what is worth pinning is that
# mapping, the bar it draws behind it, and the two rules that keep the ride readable: it never runs
# backwards, and it is never on screen for less time than it takes to see.

const LoadingScreenScene = preload("res://ui/screen_transition/scene_transition_screen.tscn")


func _make_screen():
	var screen = LoadingScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_frames(1)
	return screen


func test_it_starts_at_the_near_end_of_the_trail():
	var screen = await _make_screen()

	assert_eq(screen.get_progress(), 0.0)
	assert_eq(screen.trail_fill.size.x, 0.0, "no trail covered yet")
	assert_eq(screen.percent_label.text, "0%")


func test_the_rider_and_the_bar_both_follow_progress():
	var screen = await _make_screen()
	var track_width : float = screen.trail_track.size.x

	screen.set_progress(0.5)

	assert_almost_eq(screen.trail_fill.size.x, track_width * 0.5, 1.0, "half the trail is covered")
	assert_almost_eq(screen.rider.position.x, track_width * 0.5, 1.0, \
		"and the rider is halfway along it - the horse is the readout, not decoration")
	assert_eq(screen.percent_label.text, "50%")


# The horse should never hang half off either end of the trail.
func test_the_rider_stays_on_the_trail_at_both_ends():
	var screen = await _make_screen()
	var track_width : float = screen.trail_track.size.x

	screen.set_progress(0.0)
	assert_gt(screen.rider.position.x, 0.0, "stood on the near end, not off the edge of it")

	screen.set_progress(1.0)
	assert_lt(screen.rider.position.x, track_width, "and arrived at the far end, still on it")


func test_progress_is_clamped():
	var screen = await _make_screen()

	screen.set_progress(-1.0)
	assert_eq(screen.get_progress(), 0.0)

	screen.set_progress(4.0)
	assert_eq(screen.get_progress(), 1.0)
	assert_eq(screen.percent_label.text, "100%")


# A threaded load can report a lower number between stages. A rider that trots backwards reads as
# a bug, so the ride only ever moves forward.
func test_the_ride_never_runs_backwards():
	var screen = await _make_screen()
	screen.minimum_ride_seconds = 0.05

	var reported := [0.0]
	var readings : Array[float] = []
	# Reports 60%, then drops to 10%, then finishes.
	var script := [0.6, 0.1, 1.0]
	var index := [0]
	await screen.ride(func():
		readings.append(screen.get_progress())
		var value : float = script[mini(index[0], script.size() - 1)]
		index[0] += 1
		reported[0] = value
		return value
	)

	for i in range(1, readings.size()):
		assert_gte(readings[i], readings[i - 1], "the rider only ever moves forward along the trail")
	assert_eq(screen.get_progress(), 1.0, "and gets there in the end")


# An instant load should still show a ride rather than a one-frame flash of a full bar.
func test_an_instant_load_still_rides_long_enough_to_be_seen():
	var screen = await _make_screen()
	screen.minimum_ride_seconds = 0.4

	var started := Time.get_ticks_msec()
	await screen.ride(func(): return 1.0)
	var took : float = (Time.get_ticks_msec() - started) / 1000.0

	assert_gt(took, 0.3, "the ride has a floor, so a fast scene change is still readable")
	assert_eq(screen.get_progress(), 1.0)


# The silhouette is only a stand-in until there is horse art. Handing it a texture should take
# over rather than draw both.
func test_real_art_replaces_the_placeholder_silhouette():
	var screen = LoadingScreenScene.instantiate()
	screen.rider_texture = preload("res://icon.svg")
	screen.rider_hframes = 1
	add_child_autofree(screen)
	await wait_frames(1)

	assert_true(screen.sprite.visible, "the supplied art is what rides")
	assert_false(screen.silhouette.visible, "and the placeholder steps aside")


# The silhouette is authored at sprite size (38x43). Drawn unscaled against a 900px trail it would
# be a speck - so the scale is part of the design, not a nicety.
func test_the_rider_is_big_enough_to_read_against_the_trail():
	var screen = await _make_screen()
	var track_width : float = screen.trail_track.size.x

	var rider_width : float = 38.0 * screen.rider.scale.x
	assert_gt(rider_width, track_width * 0.05, \
		"a rider under a twentieth of the trail's length is not a readable marker")
	assert_lt(rider_width, track_width * 0.25, "and one that size would swamp the bar")


# The inset has to clear the rider's own width, or the horse hangs off the end of the trail at 0%.
func test_the_rider_clears_the_ends_of_the_trail_at_its_own_scale():
	var screen = await _make_screen()
	var track_width : float = screen.trail_track.size.x
	# The silhouette runs from x=-22 to x=16 around its origin.
	var overhang_left : float = 22.0 * screen.rider.scale.x

	screen.set_progress(0.0)
	assert_gt(screen.rider.position.x - overhang_left, 0.0, \
		"at 0%% the whole horse is still on the trail, not hanging off the near end")

	screen.set_progress(1.0)
	assert_lt(screen.rider.position.x + 16.0 * screen.rider.scale.x, track_width + 1.0, \
		"and at 100%% it has arrived without running past the far end")

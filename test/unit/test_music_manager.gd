extends GutTest

# Background music (scripts/managers/music_manager.gd). It lives on an autoload rather than in each
# level so that walking between scenes doesn't restart the track - town alone is six scenes the
# player crosses constantly - so what is worth pinning is exactly that: which requests change the
# music and which are deliberately no-ops.

# Two real streams rather than bare AudioStream instances, so the players have something valid to
# take. Which sounds they are doesn't matter here.
const TRACK_A = preload("res://ui/sounds/ui_confirm.wav")
const TRACK_B = preload("res://ui/sounds/ui_cancel.wav")


func after_each():
	# Torn down outright rather than by waiting out a fade - every test here starts from silence.
	MusicManager.stop()
	MusicManager._kill_fade()
	MusicManager._stop_all_players()


func test_it_has_two_players_on_the_music_bus():
	assert_eq(MusicManager._players.size(), 2, \
		"two, so a change can crossfade instead of cutting")
	for player in MusicManager._players:
		assert_eq(player.bus, MusicManager.BUS, \
			"tagged onto the Music bus, so the Music slider moves them and nothing else")


func test_asking_for_a_track_plays_it():
	MusicManager.play(TRACK_A)

	assert_eq(MusicManager.current_track, TRACK_A)
	assert_true(MusicManager.is_playing(TRACK_A))


# The reason this manager exists. Hub -> saloon -> hub is three scene loads across one piece of
# music, and restarting the town theme on each of them is what a per-level player would do.
func test_asking_again_for_the_track_already_playing_does_not_restart_it():
	MusicManager.play(TRACK_A)
	var active_before : int = MusicManager._active
	var stream_before = MusicManager._players[MusicManager._active].stream

	MusicManager.play(TRACK_A)

	assert_eq(MusicManager._active, active_before, \
		"no player swap means no restart - the same track keeps running where it was")
	assert_eq(MusicManager._players[MusicManager._active].stream, stream_before, \
		"and it is still the same stream on the same player, not a fresh one")


# Null is "leave the music alone", not "silence". That is what lets the hub's interiors carry the
# town's theme without each one declaring it (see levels/_common/level.gd's music export).
func test_a_level_with_no_track_of_its_own_leaves_the_music_alone():
	MusicManager.play(TRACK_A)

	MusicManager.play(null)

	assert_eq(MusicManager.current_track, TRACK_A, \
		"an interior that declares no music should not cut the town's theme off")


func test_a_different_track_takes_over_on_the_other_player():
	MusicManager.play(TRACK_A)
	var first_player = MusicManager._players[MusicManager._active]

	MusicManager.play(TRACK_B)
	var second_player = MusicManager._players[MusicManager._active]

	assert_eq(MusicManager.current_track, TRACK_B)
	assert_ne(second_player, first_player, \
		"the incoming track comes up on the other player so the two can crossfade")
	assert_eq(second_player.stream, TRACK_B)


func test_the_crossfade_leaves_only_the_new_track_running():
	MusicManager.play(TRACK_A)
	var outgoing = MusicManager._players[MusicManager._active]

	MusicManager.play(TRACK_B)
	var incoming = MusicManager._players[MusicManager._active]
	await wait_seconds(MusicManager.FADE_SECONDS + 0.3)

	assert_almost_eq(incoming.volume_db, 0.0, 0.5, "the new track comes all the way up")
	assert_null(outgoing.stream, \
		"and the old one is released rather than left decoding for the rest of the session")


func test_stopping_clears_the_track():
	MusicManager.play(TRACK_A)

	MusicManager.stop()
	await wait_seconds(MusicManager.FADE_SECONDS + 0.3)

	assert_null(MusicManager.current_track)
	assert_false(MusicManager.is_playing(TRACK_A))
	for player in MusicManager._players:
		assert_null(player.stream, "both players let go of whatever they were holding")


# A level hands its own track over on load - that is the whole integration point.
func test_a_level_hands_its_track_to_the_manager_on_load():
	var level = load("res://levels/coyote_den/coyote_den.tscn").instantiate()
	level.music = TRACK_B
	add_child_autofree(level)
	await wait_frames(1)

	assert_eq(MusicManager.current_track, TRACK_B, \
		"Level._ready() should pass its music export to the manager")

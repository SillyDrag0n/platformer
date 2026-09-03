extends GutTest

# Every playable level has a music slot (levels/_common/level.gd), so a track is assigned in the
# editor rather than wired in code. This just pins that the slot is there and reaches the manager -
# the tracks themselves are dropped in per level.

const TOWN_THEME = preload("res://audio/music/hub_theme.wav")

const HUB := "res://levels/hub/hub_level.tscn"

# Everywhere the player goes that isn't town. None of them has a track of its own yet.
const AWAY_FROM_TOWN := [
	"res://levels/regions/plains/farm_house_backyard/farm_house_backyard.tscn",
	"res://levels/regions/plains/shaman_camp/shaman_camp.tscn",
	"res://levels/regions/plains/coyote_den/coyote_den.tscn",
	"res://levels/test_level.tscn",
]


func after_each():
	MusicManager.stop()
	MusicManager._kill_fade()
	MusicManager._stop_all_players()


func test_every_level_exposes_a_music_slot():
	for path in [HUB] + AWAY_FROM_TOWN:
		var level = load(path).instantiate()
		autofree(level)
		assert_true("music" in level, \
			"%s should take a track in the inspector - it extends Level" % path)


# The town theme is the only track in the game so far, and the hub is where it starts.
func test_the_hub_carries_the_town_theme():
	var hub = load(HUB).instantiate()
	autofree(hub)

	assert_not_null(hub.music, "the hub is where the town theme starts playing")
	assert_eq(hub.music.resource_path, TOWN_THEME.resource_path)


# An empty slot means silence, not "whatever was playing keeps playing". Riding out to a bounty has
# to leave the town's theme behind in town rather than carrying a saloon piano into the desert.
func test_leaving_town_leaves_the_town_theme_behind():
	for path in AWAY_FROM_TOWN:
		MusicManager.play(TOWN_THEME)
		assert_eq(MusicManager.current_track, TOWN_THEME, "(the player rides out of town...)")

		var level = load(path).instantiate()
		autofree(level)
		assert_null(level.music, "%s has no track of its own yet" % path)

		level._apply_music()

		assert_null(MusicManager.current_track, \
			"%s should cut the town theme rather than take it along" % path)


# What the interiors do instead: nothing at all. They are InteriorLevels rather than Levels, so
# they have no slot to leave empty and never reach MusicManager - which is what lets the theme run
# unbroken through hub -> saloon -> hub while a level away from town cuts it.
func test_the_hub_interiors_carry_the_theme_by_never_asking_for_music():
	MusicManager.play(TOWN_THEME)

	var saloon = load("res://levels/hub/saloon_interior/saloon_interior.tscn").instantiate()
	add_child_autofree(saloon)
	await wait_frames(1)

	assert_false("music" in saloon, "an interior has no music slot to get this wrong with")
	assert_eq(MusicManager.current_track, TOWN_THEME, \
		"stepping inside a building in town shouldn't interrupt the town's theme")


# MusicManager forces looping on streams that expose a `loop` property, which an AudioStreamWAV
# does not. A town theme that plays through once and leaves the player standing in silence reads
# as a bug, so the loop has to come from somewhere else.
func test_the_town_theme_loops():
	var track = load("res://audio/music/hub_theme.wav")

	assert_true(track is AudioStreamWAV, "the theme is a WAV, so MusicManager cannot loop it")
	assert_eq(track.loop_mode, AudioStreamWAV.LOOP_FORWARD, \
		"the town theme has to loop - the player is in town for as long as they like")
	assert_eq(track.loop_begin, 0, "over the whole track...")
	assert_gt(track.loop_end, 0, "...rather than over nothing")


# Where that loop comes from: a `smpl` chunk written into the .wav by tools/music/hub_theme_gen.gd
# and read by the importer's default "Detect From WAV". The importer's own loop_mode flag would do
# the same job, but it lives in hub_theme.wav.import, and *.import is gitignored - a fresh clone
# would import the theme without a loop and nobody would notice until the town went quiet.
func test_the_loop_is_carried_by_the_wav_itself_not_by_its_import_settings():
	var file := FileAccess.open("res://audio/music/hub_theme.wav", FileAccess.READ)
	assert_not_null(file, "the generated theme should be in the repo")

	# The chunk is written last: 8 bytes of header plus 60 of payload, at the end of the file.
	file.seek(file.get_length() - 68)
	assert_eq(file.get_buffer(4).get_string_from_ascii(), "smpl", \
		"the .wav should carry its own loop marker, so no import setting has to be remembered")
	file.close()

extends Node

# Background music, held on an autoload rather than in each level.
#
# A level that owned its own AudioStreamPlayer would restart its track on every scene change, and
# town is the worst case for that: the hub, its five interiors and the bounty board are six scenes
# the player walks between constantly, and the theme has to run through all of them uninterrupted.
# Living up here means the track only changes when something actually asks for a different one.
#
# Tracks are tagged onto the Music bus (see default_bus_layout.tres), so the settings screen's
# Music slider moves them without touching gunshots or menu blips.

const BUS := &"Music"

# Long enough to read as one place giving way to another rather than a hard cut, short enough that
# a level's own opening beat isn't spent waiting on it.
const FADE_SECONDS := 1.2

# Effectively silence. -80 is Godot's own floor, but the last stretch of it is inaudible anyway and
# tweening through it just makes the fade feel slower than it is.
const SILENT_DB := -40.0

# Two players rather than one, so a change crossfades instead of cutting: the incoming track comes
# up while the outgoing one goes down. They swap roles on every change.
var _players : Array[AudioStreamPlayer] = []
var _active : int = 0
var _fade : Tween

# What is meant to be playing. Read it rather than the players to find out where the music is - a
# player mid-fade is not a reliable answer.
var current_track : AudioStream = null


func _ready() -> void:
	# Music keeps playing over the pause menu - stopping it would make pausing feel like leaving
	# the game rather than stepping out of it for a moment.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % i
		player.volume_db = SILENT_DB
		if AudioServer.get_bus_index(BUS) != -1:
			player.bus = BUS
		add_child(player)
		_players.append(player)


# Crossfades to `track`. Asking for what is already playing does nothing, so a scene change back
# into somewhere the same theme covers never restarts it. Passing null does nothing either - it is
# not a request for silence, which is stop()'s job.
func play(track : AudioStream) -> void:
	if track == null or track == current_track:
		return

	current_track = track
	_ensure_looping(track)

	# _active always names the player holding current_track; the other one is whatever is fading
	# out behind it.
	var outgoing : AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var incoming : AudioStreamPlayer = _players[_active]

	incoming.stream = track
	incoming.volume_db = SILENT_DB
	incoming.play()

	_crossfade(incoming, outgoing)


# Fades out to silence. Levels ask for this by leaving their music slot empty, so it lands on every
# load of a level with no track of its own - including plenty where nothing is playing to begin
# with. Bailing out on that case keeps it from building a Tween with nothing in it, which Godot
# treats as an error and never finishes.
func stop() -> void:
	current_track = null
	_kill_fade()

	var sounding := _players.filter(func(player): return player.playing)
	if sounding.is_empty():
		return

	_fade = create_tween().set_parallel(true)
	for player in sounding:
		_fade.tween_property(player, "volume_db", SILENT_DB, FADE_SECONDS)
	_fade.finished.connect(_stop_all_players, CONNECT_ONE_SHOT)


# What a scene's music slot means, in one place: the track it names, or silence if it names none.
#
# The distinction matters and is easy to get wrong, which is why it is a function rather than a
# convention. play() deliberately ignores null - it is a request to play something, and "nothing"
# is not something - so a scene that only ever called play() would leave whatever was already
# running underneath it. That is exactly how the town theme used to follow the player out to the
# main menu: the menu is not a Level, so nothing ever spoke to this manager on the way there.
func apply_slot(track : AudioStream) -> void:
	if track == null:
		stop()
	else:
		play(track)


func is_playing(track : AudioStream) -> bool:
	return current_track == track and current_track != null


func _crossfade(incoming : AudioStreamPlayer, outgoing : AudioStreamPlayer) -> void:
	_kill_fade()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", 0.0, FADE_SECONDS)
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", SILENT_DB, FADE_SECONDS)
		# Freeing the stream reference too, so a track that has been faded out isn't left decoding
		# in the background for the rest of the session.
		_fade.finished.connect(func(): _release(outgoing), CONNECT_ONE_SHOT)


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()


func _release(player : AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null


func _stop_all_players() -> void:
	for player in _players:
		_release(player)


# An imported .ogg/.mp3 defaults to playing once and stopping, which for a music track reads as a
# bug rather than a setting - so looping is turned on here instead of relying on every track being
# imported with the right flag. Streams that have no `loop` property (a WAV, say) are left alone;
# their looping lives in the import settings.
func _ensure_looping(track : AudioStream) -> void:
	if "loop" in track and not track.loop:
		track.loop = true

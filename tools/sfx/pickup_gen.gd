extends SceneTree

# Renders res://audio/sfx/pickup_coin.wav - the chime for taking something off the ground.
#
# Synthesised rather than recorded, the same way the town theme is (see tools/music/hub_theme_gen.gd,
# which this borrows its WAV writer from): the .wav is a build artefact and this script is its
# source, so retuning the sound means editing the constants below and re-running
#
#   godot --headless -s res://tools/sfx/pickup_gen.gd
#
# rather than editing samples. Deliberately not a @tool script, so it cannot run itself inside the
# editor.

const SAMPLE_RATE := 44100
const OUT_PATH := "res://audio/sfx/pickup_coin.wav"

# Two notes rather than one. A single blip reads as a UI click; the little upward step is what
# makes it a coin - and it is the same interval a fifth up, so it lands in the theme's key rather
# than against it. E6 then B6, as [MIDI, when it starts in seconds, how long it rings].
const NOTES := [
	[88, 0.0, 0.16],
	[95, 0.055, 0.20],
]

# Metal is inharmonic - that is what stops a pure tone sounding like a test signal. Partials as
# [multiple of the fundamental, how loud], picked slightly off the whole numbers a string would
# give so the ring has a bell's grain to it.
const PARTIALS := [[1.0, 1.0], [2.76, 0.28], [5.4, 0.12]]

# Long enough for the second note's tail to die out on its own. A pickup sound that is still
# ringing when the next one starts stacks up into a mess in a room full of dropped dollars.
const LENGTH := 0.26

var total : int = int(LENGTH * SAMPLE_RATE)
var buf : PackedFloat32Array = PackedFloat32Array()


func _initialize() -> void:
	buf.resize(total)
	buf.fill(0.0)

	for note in NOTES:
		_ring(midi_hz(note[0]), int(note[1] * SAMPLE_RATE), note[2])

	_write()
	quit()


func midi_hz(n : float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


# One struck note: the partials above, each decaying exponentially, with a couple of milliseconds
# of attack so it starts with a tick instead of a click.
func _ring(freq : float, start : int, dur : float) -> void:
	var length : int = int(dur * SAMPLE_RATE)
	var attack : int = int(0.002 * SAMPLE_RATE)

	for i in length:
		var t : float = float(i) / SAMPLE_RATE
		var sample : float = 0.0
		for partial in PARTIALS:
			# Higher partials die away first, the way they do on anything struck.
			var decay : float = exp(-t * (14.0 + 10.0 * partial[0]))
			sample += sin(TAU * freq * partial[0] * t) * partial[1] * decay
		if i < attack:
			sample *= float(i) / attack

		var at : int = start + i
		if at < total:
			buf[at] += sample * 0.5


func _write() -> void:
	var peak := 0.0
	for i in total:
		peak = maxf(peak, absf(buf[i]))
	if peak <= 0.0:
		push_error("pickup_gen: rendered silence")
		return
	# Short of full scale on purpose: this fires under gunfire and dialogue, and where it sits in
	# the mix is the SFX bus's job, not this script's.
	var gain : float = 0.72 / peak

	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, clampi(int(round(buf[i] * gain * 32767.0)), -32768, 32767))

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("pickup_gen: cannot write %s" % OUT_PATH)
		return
	f.store_buffer("RIFF".to_ascii_buffer())
	# Everything after this field: fmt (24) + data header (8) + samples. No `smpl` chunk - unlike
	# the town theme this is a one-shot, and a loop marker on it would ring forever.
	f.store_32(36 + data.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)                    # PCM
	f.store_16(1)                    # mono
	f.store_32(SAMPLE_RATE)
	f.store_32(SAMPLE_RATE * 2)      # byte rate
	f.store_16(2)                    # block align
	f.store_16(16)                   # bits per sample
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()

	print("pickup_gen: wrote %s - %.3f s, %d KB" % [OUT_PATH, LENGTH, data.size() / 1024])

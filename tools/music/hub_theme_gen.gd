extends SceneTree

# Renders res://audio/music/hub_theme.wav - the town theme that plays across the hub and the
# interiors that inherit it.
#
# The track is synthesised rather than recorded, so this script is its source: the .wav next to it
# is a build artefact and every musical decision - the progression, the picking pattern, the
# melody - is a constant below. Retuning the theme means editing this and re-running it, not
# editing 3 MB of samples. Run it with:
#
#   godot --headless -s res://tools/music/hub_theme_gen.gd
#
# Nothing in the game loads this file; it is a tool, and it is deliberately not a @tool script so
# it cannot run itself inside the editor.

const SAMPLE_RATE := 44100
const BPM := 92.0
const BARS := 16
const OUT_PATH := "res://audio/music/hub_theme.wav"

# A minor. Four bars of i-VI-III-VII twice, then a turn through VI-III-VII-i so the second half
# does not simply repeat the first - the player hears this theme for as long as they are in town,
# and a four-bar loop wears through in about a minute.
const PROGRESSION := [
	"Am", "F", "C", "G",
	"Am", "F", "C", "G",
	"F", "C", "G", "Am",
	"Am", "F", "G", "Am",
]

# Guitar voicings, low string to high, as MIDI numbers.
const VOICINGS := {
	"Am": [45, 52, 57, 60, 64],
	"F": [41, 48, 53, 57, 60],
	"C": [48, 52, 55, 60, 64],
	"G": [43, 50, 55, 59, 62],
}

# Bass roots, two octaves under the guitar.
const ROOTS := {"Am": 33, "F": 29, "C": 36, "G": 31}

# A rolling fingerpick: thumb on the bass string, fingers rocking across the top three. Eight
# eighth notes, as indices into the voicing above.
const PICK := [0, 3, 2, 4, 1, 3, 2, 4]
const PICK_AMP := [1.0, 0.5, 0.68, 0.46, 0.82, 0.5, 0.68, 0.46]

# The whistle line, as [bar, beat, length in beats, MIDI]. Bars are 1-based like sheet music.
# It stays out of the first four bars so the theme establishes itself before anything sings over
# it, and it is sparse throughout - this plays under shopkeeper dialogue.
const MELODY := [
	[5, 1.0, 2.0, 76], [5, 3.0, 1.0, 72], [5, 4.0, 1.0, 74],
	[6, 1.0, 2.5, 72], [6, 4.0, 1.0, 69],
	[7, 1.0, 2.0, 76], [7, 3.0, 2.0, 79],
	[8, 1.0, 2.5, 74], [8, 4.0, 1.0, 72],

	[9, 2.0, 1.0, 69], [9, 3.0, 2.0, 72],
	[10, 2.0, 1.0, 76], [10, 3.0, 2.0, 74],
	[11, 1.0, 2.0, 71], [11, 3.0, 2.0, 74],
	[12, 1.0, 3.0, 69],

	[13, 1.0, 2.0, 81], [13, 3.0, 2.0, 76],
	[14, 1.0, 2.0, 72], [14, 3.0, 1.0, 74], [14, 4.0, 1.0, 72],
	[15, 1.0, 2.0, 74], [15, 3.0, 2.0, 71],
	[16, 1.0, 4.0, 69],
]

var beat : float = 60.0 / BPM
var total : int = int(round(BARS * 4.0 * beat * SAMPLE_RATE))
var buf : PackedFloat32Array = PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	# Fixed seed. The humanisation below is random, but the track should not change every time
	# somebody re-runs this - a regenerated file that differs only in noise is a 3 MB diff.
	rng.seed = 20260902
	buf.resize(total)

	_lay_down_backing()
	_lay_down_melody()
	_lay_down_shaker()
	_add_room()
	_write()
	quit()


# --- Placement ---

func midi_hz(n : float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


# Bar and beat are 1-based, so bar 3 beat 1 is where a musician would say it is.
func at(bar : int, beat_pos : float) -> int:
	return int(round(((bar - 1) * 4.0 + (beat_pos - 1.0)) * beat * SAMPLE_RATE))


func _lay_down_backing() -> void:
	for bar in range(1, BARS + 1):
		var chord : String = PROGRESSION[bar - 1]
		var voicing : Array = VOICINGS[chord]
		for eighth in 8:
			# A few milliseconds of drift and some unevenness in the picking hand. Perfectly
			# quantised plucks at identical volume are the giveaway that nobody played this.
			var drift := rng.randf_range(-0.005, 0.005)
			var start : int = at(bar, 1.0 + eighth * 0.5) + int(drift * SAMPLE_RATE)
			var amp : float = PICK_AMP[eighth] * rng.randf_range(0.88, 1.0) * 0.16
			pluck(start, midi_hz(voicing[PICK[eighth]]), 1.7, amp)

		# Root on 1, fifth on 3. A walking line would pull attention forward, and this theme
		# sits under a town the player is wandering around in rather than in front of it.
		var root : int = ROOTS[chord]
		bass(at(bar, 1.0), midi_hz(root), 1.3, 0.30)
		bass(at(bar, 3.0), midi_hz(root + 7), 1.1, 0.22)


func _lay_down_melody() -> void:
	for event in MELODY:
		whistle(at(event[0], event[1]), midi_hz(event[3]), event[2] * beat, 0.19)


func _lay_down_shaker() -> void:
	# Held back until bar 3 so the theme opens on guitar alone.
	for bar in range(3, BARS + 1):
		for eighth in 8:
			var drift := rng.randf_range(-0.004, 0.004)
			var accent : float = 0.055 if eighth % 2 == 0 else 0.03
			var start : int = at(bar, 1.0 + eighth * 0.5) + int(drift * SAMPLE_RATE)
			shaker(start, accent * rng.randf_range(0.8, 1.1))


# --- Voices ---
#
# Every voice wraps its writes around the end of the buffer rather than clipping them. That is
# what makes the loop seamless: the ring of the last bar's chord and the tail of the final
# whistle note arrive underneath bar 1, so the join has no gap and no truncated note.

# Karplus-Strong: a delay line full of noise, averaged as it circulates, which is about the
# cheapest thing that genuinely sounds like a plucked string rather than a beeping oscillator.
func pluck(start : int, freq : float, dur : float, amp : float) -> void:
	var n := int(SAMPLE_RATE / freq)
	if n < 2:
		return

	var ks := PackedFloat32Array()
	ks.resize(n)
	for i in n:
		ks[i] = rng.randf_range(-1.0, 1.0)

	# Raw noise gives a bright, banjo-ish attack. Two smoothing passes darken the excitation
	# into something closer to a nylon string.
	for _pass in 2:
		var carry := ks[n - 1]
		for i in n:
			var cur := ks[i]
			ks[i] = 0.5 * (cur + carry)
			carry = cur

	# The delay line cycles `freq` times a second, so a fixed per-cycle damping would make the
	# high strings die away far faster than the low ones. Solving for the pitch keeps every note
	# ringing for the same length of time.
	var damping : float = pow(0.06, 1.0 / (dur * freq))
	var samples := int(dur * SAMPLE_RATE)
	var fade := int(0.04 * SAMPLE_RATE)
	var idx := 0
	for i in samples:
		var cur := ks[idx]
		var nxt := ks[(idx + 1) % n]
		ks[idx] = damping * 0.5 * (cur + nxt)
		var env := 1.0
		if i > samples - fade:
			env = float(samples - i) / float(fade)
		var p := start + i
		if p >= total:
			p -= total
		buf[p] += cur * amp * env
		idx += 1
		if idx >= n:
			idx = 0


func bass(start : int, freq : float, dur : float, amp : float) -> void:
	var samples := int(dur * SAMPLE_RATE)
	var w := TAU * freq / SAMPLE_RATE
	var decay := SAMPLE_RATE * 0.42
	var attack := SAMPLE_RATE * 0.006
	for i in samples:
		var t := float(i)
		# A little second and third harmonic: a pure sine down here reads as a test tone, where
		# an upright bass has body above the fundamental.
		var s : float = sin(w * t) + 0.28 * sin(2.0 * w * t) + 0.1 * sin(3.0 * w * t)
		# Fast attack, but not instant - a click on the front of every bass note is the most
		# audible artefact a synthesised mix can have.
		var env : float = exp(-t / decay) * minf(1.0, t / attack)
		var p := start + i
		if p >= total:
			p -= total
		buf[p] += s * env * amp


func whistle(start : int, freq : float, dur : float, amp : float) -> void:
	var samples := int(dur * SAMPLE_RATE)
	var attack := int(0.09 * SAMPLE_RATE)
	var release := int(0.22 * SAMPLE_RATE)
	var phase := 0.0
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		# Vibrato eases in over the first half second. A whistle - or a voice - holds a note
		# straight for a moment before it wavers; vibrato from the attack sounds synthetic.
		var vib : float = sin(TAU * 5.2 * t) * 0.004 * minf(1.0, t / 0.5)
		phase += TAU * freq * (1.0 + vib) / SAMPLE_RATE
		var s : float = sin(phase) + 0.12 * sin(2.0 * phase)
		var env := 1.0
		if i < attack:
			env = float(i) / float(attack)
		elif i > samples - release:
			env = float(samples - i) / float(release)
		# Smoothstep, so the envelope has no corners for the ear to catch on.
		env = env * env * (3.0 - 2.0 * env)
		var p := start + i
		if p >= total:
			p -= total
		buf[p] += s * env * amp


func shaker(start : int, amp : float) -> void:
	var samples := int(0.075 * SAMPLE_RATE)
	var low := 0.0
	for i in samples:
		var n := rng.randf_range(-1.0, 1.0)
		# One-pole highpass. What is left after the low end is removed is the sand-in-a-gourd
		# hiss; the full-band noise underneath it just sounds like a burst of static.
		low += 0.55 * (n - low)
		var env : float = exp(-float(i) / (SAMPLE_RATE * 0.018))
		var p := start + i
		if p >= total:
			p -= total
		buf[p] += (n - low) * env * amp


# --- Mix ---

func _add_room() -> void:
	# Four delayed copies of the dry mix rather than a real reverb: no feedback path, so it cannot
	# ring or run away, and it is enough to stop the instruments sounding like they were recorded
	# in separate vacuums. Taps wrap around the buffer too, so they do not break the loop.
	var taps := [[0.031, 0.26], [0.047, 0.20], [0.071, 0.15], [0.101, 0.11]]
	var dry := buf.duplicate()
	for tap in taps:
		var delay : int = int(tap[0] * SAMPLE_RATE)
		var gain : float = tap[1]
		for i in total:
			var p := i + delay
			if p >= total:
				p -= total
			buf[p] += dry[i] * gain


func _write() -> void:
	# Gentle lowpass to take the edge off the plucks. Seeded from the last sample rather than from
	# silence: starting cold would put a tiny swell on the first few milliseconds, which is audible
	# on every pass of a loop even though it would pass unnoticed in a track that only plays once.
	var carry : float = buf[total - 1]
	for _pass in 2:
		for i in total:
			carry += 0.62 * (buf[i] - carry)
			buf[i] = carry

	var peak := 0.0
	for i in total:
		peak = maxf(peak, absf(buf[i]))
	if peak <= 0.0:
		push_error("hub_theme_gen: rendered silence")
		return
	# Short of full scale on purpose. This is background music under gunfire and dialogue, and
	# sitting it in the mix is the Music bus's job, not this script's.
	var gain : float = 0.82 / peak

	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, clampi(int(round(buf[i] * gain * 32767.0)), -32768, 32767))

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("hub_theme_gen: cannot write %s" % OUT_PATH)
		return
	f.store_buffer("RIFF".to_ascii_buffer())
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

	print("hub_theme_gen: wrote %s - %.2f s, %d bars at %d BPM, %.2f MB" \
		% [OUT_PATH, float(total) / SAMPLE_RATE, BARS, int(BPM), data.size() / 1048576.0])

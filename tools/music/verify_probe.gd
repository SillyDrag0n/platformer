extends SceneTree

# Throwaway probe: confirms the rendered track is actually the music it claims to be.

const SR := 44100.0
const BEAT := 60.0 / 92.0


func _initialize() -> void:
	var f := FileAccess.open("res://audio/music/hub_theme.wav", FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	f.close()

	# Skip the 44-byte canonical header.
	var n := (bytes.size() - 44) / 2
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = bytes.decode_s16(44 + i * 2) / 32768.0
	print("samples: %d  (%.2f s)" % [n, n / SR])

	var peak := 0.0
	var sum := 0.0
	var dc := 0.0
	for i in n:
		peak = maxf(peak, absf(s[i]))
		sum += s[i] * s[i]
		dc += s[i]
	print("peak %.3f   rms %.4f   dc %.5f" % [peak, sqrt(sum / n), dc / n])

	# Loop seam: the biggest sample-to-sample step anywhere in the track, against the step across
	# the join. If the join is the outlier, the loop clicks.
	var worst := 0.0
	for i in range(1, n):
		worst = maxf(worst, absf(s[i] - s[i - 1]))
	print("largest step mid-track %.4f   step across loop join %.4f" % [worst, absf(s[0] - s[n - 1])])

	print("\nper-bar rms (arrangement should build, not sit flat):")
	var bar_len := int(4.0 * BEAT * SR)
	for bar in 16:
		var acc := 0.0
		for i in range(bar * bar_len, mini((bar + 1) * bar_len, n)):
			acc += s[i] * s[i]
		var rms : float = sqrt(acc / bar_len)
		print("  bar %2d  %.4f  %s" % [bar + 1, rms, "#".repeat(int(rms * 400.0))])

	# Which bass root is actually sounding in each bar.
	print("\nbass root detected per bar (expected from the progression):")
	var expected := ["A", "F", "C", "G", "A", "F", "C", "G", "F", "C", "G", "A", "A", "F", "G", "A"]
	var cand := {"A": 55.00, "F": 43.65, "C": 65.41, "G": 49.00}
	var hits := 0
	for bar in 16:
		var from := bar * bar_len
		var win := int(0.9 * SR)
		var best := ""
		var best_mag := 0.0
		for name in cand:
			var mag := _goertzel(s, from, win, cand[name])
			if mag > best_mag:
				best_mag = mag
				best = name
		var ok : bool = best == expected[bar]
		if ok:
			hits += 1
		print("  bar %2d  heard %s  expected %s   %s" % [bar + 1, best, expected[bar], "ok" if ok else "MISMATCH"])
	print("  -> %d/16 bars land on the written root" % hits)

	# The whistle is written to stay out of bars 1-4 and enter on bar 5 with an E5.
	print("\nwhistle entry (energy at E5 = 659 Hz):")
	for bar in [1, 2, 3, 4, 5, 6, 7]:
		var mag := _goertzel(s, (bar - 1) * bar_len, int(1.5 * SR), 659.26)
		print("  bar %d  %.4f  %s" % [bar, mag, "#".repeat(int(mag * 300.0))])

	quit()


# Energy at one frequency in one window.
func _goertzel(s : PackedFloat32Array, from : int, count : int, freq : float) -> float:
	var w := TAU * freq / SR
	var coeff := 2.0 * cos(w)
	var q1 := 0.0
	var q2 := 0.0
	var last : int = mini(from + count, s.size())
	for i in range(from, last):
		var q0 := coeff * q1 - q2 + s[i]
		q2 = q1
		q1 = q0
	return sqrt(q1 * q1 + q2 * q2 - coeff * q1 * q2) / float(last - from)

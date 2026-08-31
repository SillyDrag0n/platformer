extends Control

# The reload dial floating over the player. The ring drains from full to empty across the reload
# (Gun.gd feeds it time_left / wait_time), and with an active-reload upgrade fitted a highlighted
# wedge marks the sweet spot: press reload while the draining edge is inside it and the cylinder
# slams home without waiting the rest out. The attempt is then called out in a word over the dial -
# Gun.gd plays the matching sound alongside it, where the rest of the gun's audio lives.
#
# The wedge is a second TextureProgressBar sitting over the first at full value, using the same
# circle art but only the arc named by radial_initial_angle/radial_fill_degrees. It has to be
# drawn *over* the fill rather than under it: the fill starts covering the whole ring and retreats
# backwards through the wedge, so underneath it the marker would only become visible at the exact
# moment it stopped being any use to aim for.

# Both bars fill clockwise from 12 o'clock, so a progress value maps straight onto an angle:
# value * 360 degrees round from the top.
const DEGREES_PER_VALUE := 360.0

# Opaque, and warm against the green fill. It was a half-transparent amber at first, which over
# the bright green fill mixed into a muddy yellow-green that read as "slightly different green"
# rather than as a target - at this scale (the whole dial is 128px drawn at 0.2) a wedge has very
# little room to make its case, so it gets full alpha.
const WINDOW_COLOR := Color(1.0, 0.72, 0.1, 1.0)
# A spent attempt greys out rather than disappearing, so a miss reads as "that was your one try"
# instead of the marker having glitched away.
const MISSED_COLOR := Color(0.35, 0.35, 0.35, 0.75)
const HIT_COLOR := Color(1.0, 0.97, 0.85, 1.0)

const HIT_TEXT := "PERFECT!"
const MISSED_TEXT := "MISSED!"
const HIT_TEXT_COLOR := Color(1.0, 0.88, 0.35)
const MISSED_TEXT_COLOR := Color(0.9, 0.35, 0.28)

# How long the ring hangs on after a hit before clearing, and how long the word above it stays up.
# The message outlives the ring on purpose: the reload is over the instant it lands, and a dial
# still sitting there would read as one that is still running.
const HIT_FLASH_TIME := 0.15
const MESSAGE_HOLD_TIME := 0.45
const MESSAGE_FADE_TIME := 0.25

@onready var bar : TextureProgressBar = $TextureProgressBar
@onready var window_bar : TextureProgressBar = $Highlight
@onready var message_label : Label = $MessageLabel

# Read off the bar rather than repeated as a constant here, so the ring's normal colour stays
# something picked in the editor - flash_window_hit() below has to put it back afterwards.
@onready var _fill_color : Color = bar.tint_progress

var _ring_tween : Tween
var _message_tween : Tween


func _ready() -> void:
	window_bar.hide()
	message_label.hide()
	self.hide()


# Called at the start of every reload. A window_width of 0 means no active-reload upgrade is
# fitted and the dial behaves exactly as it did before there was one.
func begin(window_start : float, window_width : float) -> void:
	_kill_tween(_ring_tween)
	_kill_tween(_message_tween)
	message_label.hide()
	bar.tint_progress = _fill_color
	bar.value = bar.max_value
	bar.show()
	window_bar.visible = window_width > 0.0
	if window_bar.visible:
		window_bar.tint_progress = WINDOW_COLOR
		window_bar.radial_initial_angle = window_start * DEGREES_PER_VALUE
		window_bar.radial_fill_degrees = window_width * DEGREES_PER_VALUE
	self.show()


func set_value(value):
	bar.value = value


# The reload is over and the dial has nothing left to show. A verdict still fading out keeps the
# node itself on screen until it is done, so the word isn't cut off mid-sentence by the ring
# clearing underneath it.
func finish() -> void:
	_hide_ring()
	if _message_tween == null or not _message_tween.is_valid():
		self.hide()


func mark_window_missed() -> void:
	window_bar.tint_progress = MISSED_COLOR
	_show_message(MISSED_TEXT, MISSED_TEXT_COLOR)


# The ring snaps full and flashes for a moment before clearing, so a hit is something the player
# sees land rather than the dial simply vanishing a beat early.
func flash_window_hit() -> void:
	bar.value = bar.max_value
	bar.tint_progress = HIT_COLOR
	window_bar.tint_progress = HIT_COLOR
	_show_message(HIT_TEXT, HIT_TEXT_COLOR)
	_kill_tween(_ring_tween)
	_ring_tween = create_tween()
	_ring_tween.tween_interval(HIT_FLASH_TIME)
	_ring_tween.tween_callback(_hide_ring)


func _show_message(text : String, color : Color) -> void:
	_kill_tween(_message_tween)
	message_label.text = tr(text)
	message_label.modulate = color
	message_label.show()
	self.show()
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_HOLD_TIME)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, MESSAGE_FADE_TIME)
	_message_tween.tween_callback(_on_message_finished)


func _on_message_finished() -> void:
	message_label.hide()
	# A miss leaves the reload still running, so the dial is very much still wanted - only clear
	# the whole node if the ring has already gone.
	if not bar.visible:
		self.hide()


func _hide_ring() -> void:
	bar.hide()
	window_bar.hide()


func _kill_tween(tween : Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

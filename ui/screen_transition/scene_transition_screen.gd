extends CanvasLayer

# The screen between one place and the next: a trail across the plains with the player riding along
# it, the ride's distance standing in for how far the load has got.
#
# The rider is a silhouette drawn from polygon points rather than a sprite, because the project has
# no horse art. Drop a spritesheet into `rider_texture` and it takes over - the silhouette is only
# used while that slot is empty. Everything else here (the sky band, the ground, the trail) is
# built from plain ColorRects in the game's own palette, so the screen needs no assets at all.

# Kept off both ends of the trail, as a fraction of its width, so the horse never hangs off an
# edge. Wide enough to clear the rider at its default scale.
const RIDE_MARGIN := 0.08

# Rides for at least this long even if the load finishes instantly, so a fast scene change doesn't
# flash a bar that was never readable. The old screen sat on a flat 2.5s timer whatever it was
# loading; this is a floor, not a fixed cost.
@export var minimum_ride_seconds : float = 1.1

# Real art, when there is some. Left empty, the silhouette below is drawn instead.
@export var rider_texture : Texture2D
@export var rider_hframes : int = 1
@export var rider_fps : float = 10.0

# The silhouette is authored at roughly 38x43 - about the size of a game sprite - so it needs
# scaling up to read against a 900px trail. Applied to the rider as a whole, so real art dropped
# into rider_texture is sized by the same dial.
@export var rider_scale : float = 3.0

# How far the horse rises and falls at a gallop, in pixels, and how quickly.
@export var gallop_bob_pixels : float = 8.0
@export var gallop_bob_hz : float = 6.0

@onready var trail_fill : ColorRect = $Trail/Fill
@onready var trail_track : ColorRect = $Trail
@onready var rider : Node2D = $Trail/Rider
@onready var silhouette : Node2D = $Trail/Rider/Silhouette
@onready var sprite : Sprite2D = $Trail/Rider/Sprite
@onready var percent_label : Label = $Trail/PercentLabel

var _progress : float = 0.0
var _elapsed : float = 0.0


func _ready() -> void:
	SettingsManager.apply_ui_scale(self)
	rider.scale = Vector2(rider_scale, rider_scale)
	if rider_texture != null:
		sprite.texture = rider_texture
		sprite.hframes = maxi(rider_hframes, 1)
		sprite.visible = true
		silhouette.visible = false
	set_progress(0.0)


func _process(delta : float) -> void:
	_elapsed += delta
	# The gallop is on a clock rather than on progress, so the horse keeps moving its legs even
	# while a slow load leaves the bar sitting still.
	rider.position.y = -sin(_elapsed * gallop_bob_hz * TAU) * gallop_bob_pixels
	if sprite.visible and sprite.hframes > 1:
		sprite.frame = int(_elapsed * rider_fps) % sprite.hframes


# 0..1. The rider is the readout - the bar behind it is just the trail already covered.
func set_progress(value : float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var width : float = trail_track.size.x
	trail_fill.size.x = width * _progress
	rider.position.x = _ride_x(_progress, width)
	percent_label.text = "%d%%" % roundi(_progress * 100.0)


# Kept off both ends of the track so the horse never hangs half off the trail: at 0 it is stood at
# the near end, at 1 it has arrived at the far one.
func _ride_x(progress : float, track_width : float) -> float:
	var inset : float = track_width * RIDE_MARGIN
	return lerpf(inset, track_width - inset, clampf(progress, 0.0, 1.0))


func get_progress() -> float:
	return _progress


# Rides the trail while `report_progress` keeps answering with how far along the real work is.
# Returns once the work is done *and* the ride has been on screen long enough to read.
func ride(report_progress : Callable) -> void:
	_elapsed = 0.0
	var shown_for : float = 0.0
	while true:
		var reported : float = report_progress.call() if report_progress.is_valid() else 1.0
		# Never let the bar run backwards - a threaded load can report a lower number between
		# stages, and a rider that trots backwards reads as a bug.
		set_progress(maxf(_progress, minf(reported, shown_for / minimum_ride_seconds)))
		if _progress >= 1.0:
			break
		shown_for += await _next_frame()
	# A beat at the far end, so "arrived" registers before the screen is torn down.
	await get_tree().create_timer(0.15).timeout


func _next_frame() -> float:
	await get_tree().process_frame
	return get_process_delta_time()

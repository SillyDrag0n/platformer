extends Node2D

const DURATION : float = 0.35
const COLOR := Color(1.0, 0.55, 0.15, 0.85)

# The core flash is a separate, much quicker pulse layered under the shockwave ring - it's gone
# by the time the ring is a quarter of the way expanded, giving the detonation a sharp "pop"
# instead of just a uniformly fading circle.
const FLASH_COLOR := Color(1.0, 0.95, 0.8, 1.0)
const FLASH_FRACTION : float = 0.25

# Screen shake scales with blast radius (bigger charge, bigger shake) but stays within a range
# that still reads as a shake rather than a camera glitch.
const MIN_SHAKE_INTENSITY : float = 8.0
const MAX_SHAKE_INTENSITY : float = 20.0
const SHAKE_INTENSITY_PER_RADIUS : float = 0.15
const SHAKE_DURATION : float = 0.4

var radius : float = 64.0
var _progress : float = 0.0

@onready var explosion_sound : AudioStreamPlayer2D = $ExplosionSound
@onready var explosion_deep : AudioStreamPlayer2D = $ExplosionDeep
@onready var explosion_crack : AudioStreamPlayer2D = $ExplosionCrack
@onready var debris : GPUParticles2D = $Debris
@onready var smoke : GPUParticles2D = $Smoke


func set_radius(new_radius : float) -> void:
	radius = new_radius


func _ready() -> void:
	explosion_sound.pitch_scale = randf_range(0.96, 1.04)
	explosion_deep.pitch_scale = randf_range(0.58, 0.66)
	explosion_crack.pitch_scale = randf_range(1.28, 1.38)
	explosion_sound.play()
	explosion_deep.play()
	get_tree().create_timer(0.018).timeout.connect(explosion_crack.play)
	_shake_camera()

	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)

	# The shockwave circle and particles only animate for so long, but the sound can outlast
	# them - don't cut anything off partway through by freeing on the shortest one's schedule.
	var lifetime : float = maxf(DURATION, explosion_sound.stream.get_length())
	lifetime = maxf(lifetime, explosion_deep.stream.get_length())
	lifetime = maxf(lifetime, explosion_crack.stream.get_length() + 0.018)
	lifetime = maxf(lifetime, debris.lifetime)
	lifetime = maxf(lifetime, smoke.lifetime)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _shake_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var intensity := clampf(radius * SHAKE_INTENSITY_PER_RADIUS, MIN_SHAKE_INTENSITY, MAX_SHAKE_INTENSITY)
	camera.screen_shake(intensity, SHAKE_DURATION)


func _set_progress(value : float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var current_radius : float = radius * _progress
	var color := COLOR
	color.a *= (1.0 - _progress)
	draw_circle(Vector2.ZERO, current_radius, color)

	if _progress < FLASH_FRACTION:
		var flash_progress : float = _progress / FLASH_FRACTION
		var flash_color := FLASH_COLOR
		flash_color.a *= (1.0 - flash_progress)
		draw_circle(Vector2.ZERO, radius * 0.4 * (1.0 - flash_progress * 0.5), flash_color)

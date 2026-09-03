extends PointLight2D

# What makes a lamp read as a flame rather than a bulb. A steady PointLight2D on a kerosene lantern
# looks electric, and the whole point of hanging lamps around a western is that the light is being
# burned rather than switched on.
#
# Procedural rather than an animated energy track: three sine waves at frequencies that do not
# divide into each other, so the pattern never audibly repeats, and each lamp draws its own phase
# and its own speed at _ready. Without that last part a street of lamps pulses in unison, which is
# far more obviously fake than no flicker at all.

# How far the light swings either side of its resting energy, as a fraction of it. Past about a
# quarter it stops reading as a flame and starts reading as a fault in the lamp.
@export_range(0.0, 0.5, 0.01) var flicker_depth : float = 0.14

# Swings per second, roughly. A lantern in still air is slower than one in wind.
@export_range(0.5, 20.0, 0.1) var flicker_speed : float = 5.5

# The energy set in the scene is the flame's resting brightness; the flicker is measured off it, so
# turning a lamp up in the inspector does not also make it twitchier.
var _resting_energy : float = 1.0
var _phase : float = 0.0
var _speed_scale : float = 1.0
var _time : float = 0.0


func _ready() -> void:
	_resting_energy = energy
	_phase = randf() * TAU
	_speed_scale = randf_range(0.85, 1.2)


func _process(delta : float) -> void:
	_time += delta * flicker_speed * _speed_scale
	energy = _resting_energy * (1.0 + flicker_offset(_time + _phase) * flicker_depth)


# Split out from _process so the shape of the flame can be tested without running a light for a
# second. Stays within +-1, so the light never doubles or goes out.
static func flicker_offset(t : float) -> float:
	return sin(t) * 0.6 + sin(t * 1.73 + 1.1) * 0.28 + sin(t * 3.11 + 2.4) * 0.12

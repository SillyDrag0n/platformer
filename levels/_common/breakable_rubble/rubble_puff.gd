extends Node2D

# One tile's worth of wall coming down: a spray of rock chips that falls under its own weight, and
# a slower cloud of dust that hangs in the hole the tile left. Spawned per destroyed cell by
# rubble_burst.gd rather than once for a whole patch, so a wall crumbles along its own outline
# instead of puffing out of a bounding box that would include the empty air around an L-bend.
#
# The emission boxes are sized for the 16px cells of the desert breakables tileset - the one thing
# in here that would need revisiting if a level ever painted breakables at another tile size.

@onready var chunks : GPUParticles2D = $Chunks
@onready var dust : GPUParticles2D = $Dust


func _ready() -> void:
	# Every puff frees itself and nothing keeps track of them. Waiting on the longer of the two
	# systems is what keeps the dust from being cut off mid-fade once the chips are already down.
	var lifetime : float = maxf(chunks.lifetime, dust.lifetime)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

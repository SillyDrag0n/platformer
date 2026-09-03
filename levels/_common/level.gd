class_name Level
extends Node2D

# What every playable level is: a player, the camera following them, and the marker they come
# back to when they die.
#
# Claiming the respawn wiring is the part no level can skip. RespawnManager holds one set of
# nodes - whichever level called set_respawn_nodes() last - so a level that doesn't claim it on
# load leaves the player respawning against the level before it, or, on a fresh boot, against
# nothing at all (which used to crash respawn() on a null marker). Doing it here means a new
# level gets it by extending this instead of by remembering to.

# What plays here. Left empty means silence: riding out to a bounty should leave the town's theme
# behind in town rather than carrying it into the desert. Music that follows the player between
# scenes is the hub interiors' doing, and they get it by not being Levels at all - InteriorLevel
# never touches MusicManager, so whatever the hub started keeps running while the player is inside
# one of its buildings. MusicManager owns the actual playback and crossfades between tracks.
@export var music : AudioStream


@onready var player : CharacterBody2D = $Player
@onready var camera : Camera2D = $PlayerCamera
@onready var respawn_marker : Marker2D = $RespawnPosition


func _ready() -> void:
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)
	_apply_music()
	_on_level_ready()


# An empty slot is a decision, not an omission - see the note on `music` above. MusicManager.
# apply_slot() is what "empty means silence" lives in, shared with the main menu, which is not a
# Level but has a slot for the same reason.
func _apply_music() -> void:
	MusicManager.apply_slot(music)


# Where a level does its own setup. Overriding this rather than _ready() means a level can't
# accidentally skip the respawn wiring above by forgetting to call super().
func _on_level_ready() -> void:
	pass


# Called by RespawnManager once it has built a fresh player, so the level's own reference stops
# pointing at the body it just replaced.
func set_player_instance(player_instance : CharacterBody2D) -> void:
	player = player_instance

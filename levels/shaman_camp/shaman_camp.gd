extends Node2D

# The ride out to the shaman - PROJECT.md's "Level 2 - The Shaman", and the job Hutch puts on the
# board at the end of the tutorial (see levels/farm_house_backyard/coyote_encounter.gd). A traverse
# east out of the farm country: a dry wash to cross, a mesa to climb, and her camp at the far end.
#
# The bounty is turned in by talking to her rather than by killing anything - ShamanNPC is a
# BountyTurnInNPC, so the completion/reward/summary screen all run off her dialogue closing. That
# also means the level is harmless to run on its own with no active bounty: she just talks.
#
# The terrain is authored as tile data rather than hand-placed collision, same as every other
# level, so it can be painted over in the editor without restructuring anything.

@onready var player : CharacterBody2D = $Player
@onready var camera : Camera2D = $PlayerCamera
@onready var respawn_marker : Marker2D = $RespawnPosition


func _ready() -> void:
	# Without this, dying here would respawn against whatever level last called
	# set_respawn_nodes() - the hub, or the backyard the player came from. Same wiring
	# hub_level.gd and farm_house_backyard.gd do for themselves.
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)


func set_player_instance(player_instance : CharacterBody2D) -> void:
	player = player_instance

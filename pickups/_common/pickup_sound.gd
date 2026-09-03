class_name PickupSound
extends AudioStreamPlayer2D

# The chime for taking something off the ground.
#
# It cannot live on the pickup itself: a pickup frees the moment it is taken - it has nothing left
# to show - and a player freed with it is cut off mid-ring. This is spawned into the level in the
# pickup's place and frees itself once it has finished.
#
# It is in the "SFX" group rather than having `bus` set on the node, for the reason spelled out at
# the top of scripts/managers/audio_buses.gd.

const SCENE : PackedScene = preload("res://pickups/_common/pickup_sound.tscn")

# A dropped stack of dollars taken in one stride would otherwise fire the same sample on top of
# itself several times in a frame, which is not louder so much as wrong - it phases into a single
# clipped blat. Small enough that two pickups a stride apart still both sound.
const RETRIGGER_GAP : float = 0.06

const GROUP := &"pickup_sound"


static func play_for(pickup : Node2D) -> void:
	if not is_instance_valid(pickup) or not pickup.is_inside_tree():
		return
	for playing in pickup.get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(playing) and playing.get_playback_position() < RETRIGGER_GAP:
			return

	var sound : PickupSound = SCENE.instantiate()
	pickup.get_parent().add_child(sound)
	sound.global_position = pickup.global_position
	sound.play()


func _ready() -> void:
	add_to_group(GROUP)
	finished.connect(queue_free)

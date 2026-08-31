class_name ContactHitbox
extends Node2D

# The space around a creature that hurts to stand in.
#
# Enemies deal damage through the player's own Hurtbox, which reads it off
# area.get_parent().get_damage_amount() (see player/player.gd's _on_hurtbox_area_entered) - so the
# damaging Area2D has to hang off a node that answers that call. That node deliberately isn't the
# enemy itself: the enemy already owns a Hurtbox on a layer the player watches, and putting
# get_damage_amount() on the enemy would quietly turn the box that *receives* bullets into one
# that *deals* damage too.
#
# Needed at all because a body-to-body touch never reliably registers. The player's collision
# capsule and an enemy's stop them at very nearly the exact distance where the player's Hurtbox
# would begin to overlap the enemy's body, so walking into a creature did nothing - the physics
# push-apart wins the race against the overlap every time. This box is drawn a little wider than
# the body it belongs to, so contact lands before the two bodies wedge against each other.

# On the EnemyAttacks layer (1024) in the scene, the same one spikes and cactus needles use, since
# that is what the player's Hurtbox is watching for.
@export var damage_amount : int = 1

@onready var area : Area2D = $Area2D


func get_damage_amount() -> int:
	return damage_amount


# Authored inert, so a creature only becomes dangerous to touch when its owner says so - the
# coyote is walked in on while it eats, and it must not chip the player during that beat or on its
# way out once the fight is over. Deferred because callers reach this from inside a physics
# callback (a hit landing is what starts the coyote's fight).
func set_active(active : bool) -> void:
	area.set_deferred("monitorable", active)
	area.set_deferred("monitoring", active)

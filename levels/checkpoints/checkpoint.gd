extends Node2D

@export var checkpoint_active : bool = false
@export var respawn_marker: Marker2D
@export var animated_sprite_2d : AnimatedSprite2D

# The campfire sprite's art fills its 32x32 frame right to the bottom edge, so this node's own
# origin (the sprite's center, since AnimatedSprite2D is centered by default) sits 16px above the
# ground line. The player's capsule collider is centered on ITS origin too (height 66, no offset),
# extending 33px above and below it. Copying global_position straight into the marker put the
# player's origin only 16px above ground instead of the 33px its capsule needs, sinking its bottom
# half ~17px into the floor on respawn.
const RESPAWN_HEIGHT_OFFSET : float = -17.0

func _on_area_2d_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		respawn_marker.global_position = global_position + Vector2(0, RESPAWN_HEIGHT_OFFSET)
		checkpoint_active = true
		animated_sprite_2d.play("active")
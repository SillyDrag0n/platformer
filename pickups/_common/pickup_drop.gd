class_name PickupDrop
extends RefCounted

# Enemies drop pickups at their own position, which is their capsule's center rather than their
# feet - spawned as-is, a pickup would hang in mid-air. Raycasts down to the ground (or a one-way
# platform) from wherever the pickup was spawned and tweens it the rest of the way down, so it
# reads as falling and landing instead of floating.
#
# It also settles where the pickup is drawn, since that is the other half of ending up on the
# ground: a level's floor is painted in layers - terrain at 0, one-way platforms at 10, decorations
# at 30, breakables at 40, foreground at 70 (see any level's TileMap) - and at the default 0 a
# dollar lying in the dirt was drawn under every tuft of grass and stone painted on top of it.
# Visible in a bare patch, invisible everywhere the level has any dressing at all. Sitting with the
# decorations is what makes a dropped pickup read as lying ON the ground rather than beneath it.
const DECORATION_LAYER_Z: int = 30

const GROUND_MASK: int = 1 | (1 << 7) # Ground (layer 1) + OneWayPlatform (layer 8)
const FALL_SPEED: float = 400.0
const MAX_FALL_DISTANCE: float = 500.0


static func fall_to_ground(pickup: Node2D) -> void:
	# Before the raycast, not after: a pickup dropped somewhere with no ground under it at all
	# returns early below, and it still has to be drawn where it can be seen.
	pickup.z_index = DECORATION_LAYER_Z

	var space_state := pickup.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		pickup.global_position, pickup.global_position + Vector2(0, MAX_FALL_DISTANCE)
	)
	query.collision_mask = GROUND_MASK
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var ground_y: float = result.position.y
	var fall_distance: float = ground_y - pickup.global_position.y
	if fall_distance <= 0.0:
		return

	var tween := pickup.create_tween()
	tween.tween_property(pickup, "global_position:y", ground_y, fall_distance / FALL_SPEED) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

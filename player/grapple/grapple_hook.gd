extends Node2D

@export_category("Grapple Hook")
@export var max_distance : float = 500.0

const GROUND_MASK : int = 1          # layer 1 "Ground"
const GRAPPLE_ANCHOR_MASK : int = 1 << 11 # layer 12 "GrappleAnchor"

@onready var rope_line : Line2D = $RopeLine


func get_aim_direction(from_global : Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2.ZERO
	var mouse_global := camera.get_global_mouse_position()
	return (mouse_global - from_global).normalized()


# Casts a ray toward the mouse and returns the hit GrappleAnchor, or null if
# the aim is out of range, blocked by geometry, or not pointed at an anchor.
func find_anchor(from_global : Vector2) -> Node2D:
	var direction := get_aim_direction(from_global)
	if direction == Vector2.ZERO:
		return null

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from_global, from_global + direction * max_distance)
	query.collision_mask = GROUND_MASK | GRAPPLE_ANCHOR_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var collider = result.collider
	if collider is Node2D and collider.is_in_group("GrappleAnchor"):
		return collider
	return null


func update_rope_visual(from_global : Vector2, to_global : Vector2) -> void:
	rope_line.points = [rope_line.to_local(from_global), rope_line.to_local(to_global)]


func hide_rope() -> void:
	rope_line.points = PackedVector2Array()

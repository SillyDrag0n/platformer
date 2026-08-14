extends Node2D

@export var radius : float = 70.0
@export var anchor_offset : Vector2 = Vector2(0, -37)
@export var reticle_radius_px : float = 6.0
@export var reticle_color : Color = Color(1, 0.3, 0.3, 0.95)

@export_category("Trajectory Line")
@export var trajectory_max_distance : float = 900.0
@export var trajectory_color : Color = Color(1, 1, 1, 0.18)
@export var trajectory_width : float = 1.5
@export var trajectory_dash_length : float = 8.0

# Same layers the bullet's own hitbox checks (see bullet.tscn Hitbox.collision_mask), so the
# line always ends exactly where a shot fired right now would actually land.
const TRAJECTORY_MASK : int = 1 | (1 << 2) # Ground (layer 1) + Enemy (layer 3)

var trajectory_start_global : Vector2
var trajectory_end_global : Vector2


func _process(_delta : float) -> void:
	var anchor_global : Vector2 = get_parent().to_global(anchor_offset)
	var direction : Vector2 = GameInputEvents.aim_input(anchor_global)
	position = anchor_offset + direction * radius
	_update_trajectory(anchor_global, direction)
	queue_redraw()


func _update_trajectory(anchor_global : Vector2, direction : Vector2) -> void:
	trajectory_start_global = anchor_global + direction * (radius + reticle_radius_px * 2.0)
	var ray_end : Vector2 = anchor_global + direction * trajectory_max_distance

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(trajectory_start_global, ray_end)
	query.collision_mask = TRAJECTORY_MASK

	var result := space_state.intersect_ray(query)
	trajectory_end_global = result.position if result else ray_end


func _draw() -> void:
	draw_dashed_line(to_local(trajectory_start_global), to_local(trajectory_end_global), trajectory_color, trajectory_width, trajectory_dash_length)

	draw_arc(Vector2.ZERO, reticle_radius_px, 0.0, TAU, 20, reticle_color, 2.0, true)

	var gap := reticle_radius_px * 0.4
	var tick := reticle_radius_px * 0.8

	draw_line(Vector2(-reticle_radius_px - gap - tick, 0), Vector2(-reticle_radius_px - gap, 0), reticle_color, 2.0)
	draw_line(Vector2(reticle_radius_px + gap, 0), Vector2(reticle_radius_px + gap + tick, 0), reticle_color, 2.0)
	draw_line(Vector2(0, -reticle_radius_px - gap - tick), Vector2(0, -reticle_radius_px - gap), reticle_color, 2.0)
	draw_line(Vector2(0, reticle_radius_px + gap), Vector2(0, reticle_radius_px + gap + tick), reticle_color, 2.0)

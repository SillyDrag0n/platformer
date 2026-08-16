extends Node2D

@export var radius : float = 70.0
@export var anchor_offset : Vector2 = Vector2(0, -37)
@export var reticle_radius_px : float = 6.0
@export var reticle_color : Color = Color(1, 0.3, 0.3, 0.95)

@export_category("Trajectory Line")
@export var trajectory_max_distance : float = 700.0
@export var trajectory_color : Color = Color(1, 1, 1, 0.18)
@export var trajectory_width : float = 1.5
@export var trajectory_dash_length : float = 8.0

# Line stays at full trajectory_color.a out to this distance, then fades linearly to fully
# transparent by trajectory_max_distance.
@export var trajectory_fade_start_distance : float = 300.0

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


# draw_dashed_line() only takes one flat color, so a distance-based fade needs each dash drawn
# as its own segment with its own alpha instead of a single call.
func _draw_fading_trajectory() -> void:
	var from : Vector2 = to_local(trajectory_start_global)
	var to : Vector2 = to_local(trajectory_end_global)

	var total_length : float = from.distance_to(to)
	if total_length <= 0.0:
		return
	var direction : Vector2 = (to - from) / total_length

	var step := trajectory_dash_length * 2.0 # dash + gap
	var travelled := 0.0

	while travelled < total_length:
		var alpha := _trajectory_alpha_at(travelled)
		if alpha > 0.0:
			var dash_end : float = min(travelled + trajectory_dash_length, total_length)
			var color := trajectory_color
			color.a = alpha
			draw_line(from + direction * travelled, from + direction * dash_end, color, trajectory_width)

		travelled += step


# Full trajectory_color.a out to trajectory_fade_start_distance, then linearly down to 0 by
# trajectory_max_distance. `distance` is measured from the line's own start (a little past the
# reticle), not the player - close enough given fade distances are much larger than that offset.
func _trajectory_alpha_at(distance : float) -> float:
	if distance <= trajectory_fade_start_distance:
		return trajectory_color.a

	var fade_range := trajectory_max_distance - trajectory_fade_start_distance
	if fade_range <= 0.0:
		return 0.0

	var t := (distance - trajectory_fade_start_distance) / fade_range
	return trajectory_color.a * clampf(1.0 - t, 0.0, 1.0)


func _draw() -> void:
	_draw_fading_trajectory()

	draw_arc(Vector2.ZERO, reticle_radius_px, 0.0, TAU, 20, reticle_color, 2.0, true)

	var gap := reticle_radius_px * 0.4
	var tick := reticle_radius_px * 0.8

	draw_line(Vector2(-reticle_radius_px - gap - tick, 0), Vector2(-reticle_radius_px - gap, 0), reticle_color, 2.0)
	draw_line(Vector2(reticle_radius_px + gap, 0), Vector2(reticle_radius_px + gap + tick, 0), reticle_color, 2.0)
	draw_line(Vector2(0, -reticle_radius_px - gap - tick), Vector2(0, -reticle_radius_px - gap), reticle_color, 2.0)
	draw_line(Vector2(0, reticle_radius_px + gap), Vector2(0, reticle_radius_px + gap + tick), reticle_color, 2.0)
 
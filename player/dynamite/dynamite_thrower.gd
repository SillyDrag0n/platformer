extends Node2D

# Ground (layer 1) and OneWayPlatform (layer 8) - what the trajectory preview should stop at,
# matching what the thrown dynamite itself can actually land on.
const TRAJECTORY_COLLISION_MASK : int = 1 | (1 << 7)
const TRAJECTORY_STEP_TIME : float = 0.05
const TRAJECTORY_MAX_TIME : float = 2.0

var dynamite_scene = preload("res://player/dynamite/dynamite.tscn")

@onready var throw_marker : Marker2D = $ThrowMarker
@onready var trajectory_line : Line2D = $TrajectoryLine
@onready var player = get_parent()

var held_dynamite : Node2D = null
# Snapshot of whichever ThrowableItemData was equipped when the pin was pulled, so a mid-hold
# cycle to a different utility item can't change the stats (or cooldown) of a throw already in
# progress.
var held_item_data : ThrowableItemData = null
var cooldown_remaining : float = 0.0


func _process(delta) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)

	if held_dynamite != null and not is_instance_valid(held_dynamite):
		held_dynamite = null
		held_item_data = null
		trajectory_line.points = PackedVector2Array()

	if held_dynamite == null:
		if cooldown_remaining <= 0.0 and GameInputEvents.use_utility_just_pressed() and player.state_machine.current_node_state.name.to_lower() == "normal":
			_pull_dynamite()
		return

	held_dynamite.global_position = throw_marker.global_position
	_update_trajectory_preview()

	if GameInputEvents.use_utility_just_released():
		_release_dynamite()


func _pull_dynamite() -> void:
	var item = InventoryManager.get_equipped_utility()
	if not (item is ThrowableItemData):
		return
	if InventoryManager.get_owned_quantity(item) <= 0:
		return

	InventoryManager.remove_item(item)
	held_item_data = item

	held_dynamite = dynamite_scene.instantiate()
	ProjectileLayer.spawn(held_dynamite)
	held_dynamite.global_position = throw_marker.global_position
	held_dynamite.throw_speed = item.throw_speed
	held_dynamite.gravity = item.gravity
	held_dynamite.explosion_damage = item.explosion_damage
	held_dynamite.explosion_radius = item.explosion_radius
	held_dynamite.light_fuse(item.fuse_time)


func _release_dynamite() -> void:
	var direction : Vector2 = GameInputEvents.aim_input(held_dynamite.global_position)
	held_dynamite.throw(direction)

	cooldown_remaining = held_item_data.throw_cooldown
	held_dynamite = null
	held_item_data = null
	trajectory_line.points = PackedVector2Array()


# Traces the same ballistic arc the dynamite will actually follow once thrown (see dynamite.gd's
# gravity-driven _physics_process), stopping early at whatever ground/platform geometry it would
# land on - so the preview always matches the real throw instead of drawing through walls/floors.
func _update_trajectory_preview() -> void:
	var start : Vector2 = held_dynamite.global_position
	var direction : Vector2 = GameInputEvents.aim_input(start)
	var velocity : Vector2 = direction * held_item_data.throw_speed

	var space_state := get_world_2d().direct_space_state
	var points : PackedVector2Array = [trajectory_line.to_local(start)]

	var previous : Vector2 = start
	var t : float = 0.0
	while t < TRAJECTORY_MAX_TIME:
		t += TRAJECTORY_STEP_TIME
		var point : Vector2 = start + velocity * t + 0.5 * Vector2(0.0, held_item_data.gravity) * t * t

		var query := PhysicsRayQueryParameters2D.create(previous, point)
		query.collision_mask = TRAJECTORY_COLLISION_MASK
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			points.append(trajectory_line.to_local(result.position))
			break

		points.append(trajectory_line.to_local(point))
		previous = point

	trajectory_line.points = points

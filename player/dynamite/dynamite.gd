extends CharacterBody2D

enum State { HELD, THROWN, LANDED }

const ENEMY_COLLISION_MASK : int = 4

# Fuse blink speeds up as time runs out - MAX_BLINK_INTERVAL right after lighting, MIN_BLINK_INTERVAL
# right before it goes off - so there's always a visible countdown, whether it's still in the
# player's hand or already thrown.
const FUSE_SPARK_COLOR := Color(1, 0.85, 0.2, 1)
const FUSE_WARNING_COLOR := Color(1, 0.1, 0.1, 1)
const MIN_BLINK_INTERVAL : float = 0.08
const MAX_BLINK_INTERVAL : float = 0.45

var explosion_effect = preload("res://player/dynamite/dynamite_explosion_effect.tscn")

var state : State = State.HELD

var throw_speed : float = 500.0
var gravity : float = 1400.0
var explosion_damage : int = 4
var explosion_radius : float = 64.0

var _blink_elapsed : float = 0.0
var _blink_on : bool = false

@onready var fuse_timer : Timer = $FuseTimer
@onready var sprite : Sprite2D = $Sprite
@onready var fuse_spark : Polygon2D = $FuseSpark


func light_fuse(time : float) -> void:
	fuse_timer.wait_time = time
	fuse_timer.start()


func throw(direction : Vector2) -> void:
	state = State.THROWN
	velocity = direction * throw_speed


func _process(delta : float) -> void:
	if fuse_timer.is_stopped():
		return

	var fraction_remaining : float = fuse_timer.time_left / fuse_timer.wait_time
	var blink_interval : float = lerpf(MIN_BLINK_INTERVAL, MAX_BLINK_INTERVAL, fraction_remaining)

	_blink_elapsed += delta
	if _blink_elapsed < blink_interval:
		return
	_blink_elapsed = 0.0

	_blink_on = !_blink_on
	fuse_spark.color = FUSE_WARNING_COLOR if _blink_on else FUSE_SPARK_COLOR
	sprite.modulate = FUSE_WARNING_COLOR if _blink_on else Color.WHITE


func _physics_process(delta : float) -> void:
	if state == State.HELD:
		return

	velocity.y += gravity * delta
	move_and_slide()

	if state == State.THROWN and is_on_floor():
		state = State.LANDED
		velocity = Vector2.ZERO


func _on_fuse_timer_timeout() -> void:
	explode()


func explode() -> void:
	_damage_enemies_in_radius()
	_damage_player_in_radius()
	_destroy_breakable_tiles_in_radius()

	var explosion_effect_instance = explosion_effect.instantiate() as Node2D
	explosion_effect_instance.global_position = global_position
	explosion_effect_instance.set_radius(explosion_radius)
	ProjectileLayer.spawn(explosion_effect_instance)

	queue_free()


func _damage_enemies_in_radius() -> void:
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state := get_world_2d().direct_space_state
	for result in space_state.intersect_shape(query):
		var collider = result["collider"]
		if collider.is_in_group("Enemy") and collider.has_method("take_damage"):
			collider.take_damage(explosion_damage)


# Poorly timed throws - lighting the fuse and holding too long, or standing too close when it
# goes off - should hurt just as much as catching an enemy in the blast. take_hit() already
# handles the player's own invulnerability window, so this doesn't need to check that itself.
func _damage_player_in_radius() -> void:
	var player = PlayerManager.player
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= explosion_radius:
		player.take_hit(explosion_damage)


func _destroy_breakable_tiles_in_radius() -> void:
	for terrain in get_tree().get_nodes_in_group("BreakableTerrain"):
		_erase_breakable_cells(terrain)


func _erase_breakable_cells(terrain : TileMapLayer) -> void:
	var tile_size : Vector2i = terrain.tile_set.tile_size
	var local_center : Vector2 = terrain.to_local(global_position)
	var center_cell : Vector2i = terrain.local_to_map(local_center)
	var cell_radius : int = int(ceil(explosion_radius / min(tile_size.x, tile_size.y)))

	var hit_cells : Array[Vector2i] = []
	for x in range(-cell_radius, cell_radius + 1):
		for y in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(x, y)
			var cell_local_center : Vector2 = terrain.map_to_local(cell)
			if local_center.distance_to(cell_local_center) > explosion_radius:
				continue

			if terrain.get_cell_source_id(cell) != -1:
				hit_cells.append(cell)

	# A hidden structure can be built entirely out of breakable tiles and span further than any
	# blast radius - erasing only cells strictly inside the radius would leave a suspiciously
	# precise circular bite instead of fully opening the entrance. Extending exactly one tile past
	# each hit cell finishes off that entrance cleanly without cascading into the rest of the
	# structure, which is what keeps a bigger hidden cave still obscured beyond it.
	var cells_to_erase : Dictionary = {}
	for cell in hit_cells:
		cells_to_erase[cell] = true
		for neighbor in _get_adjacent_cells(cell):
			if terrain.get_cell_source_id(neighbor) != -1:
				cells_to_erase[neighbor] = true

	for cell in cells_to_erase:
		terrain.erase_cell(cell)


func _get_adjacent_cells(cell : Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1),
		cell + Vector2i(1, 1), cell + Vector2i(-1, 1),
		cell + Vector2i(1, -1), cell + Vector2i(-1, -1),
	]

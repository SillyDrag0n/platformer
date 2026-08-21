extends CharacterBody2D

enum State { HELD, THROWN, LANDED }

const ENEMY_COLLISION_MASK : int = 4

var explosion_effect = preload("res://player/dynamite/dynamite_explosion_effect.tscn")

var state : State = State.HELD

var throw_speed : float = 500.0
var gravity : float = 1400.0
var explosion_damage : int = 4
var explosion_radius : float = 64.0

@onready var fuse_timer : Timer = $FuseTimer


func light_fuse(time : float) -> void:
	fuse_timer.wait_time = time
	fuse_timer.start()


func throw(direction : Vector2) -> void:
	state = State.THROWN
	velocity = direction * throw_speed


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
	_destroy_breakable_tiles_in_radius()

	var explosion_effect_instance = explosion_effect.instantiate() as Node2D
	explosion_effect_instance.global_position = global_position
	explosion_effect_instance.set_radius(explosion_radius)
	get_tree().current_scene.add_child(explosion_effect_instance)

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


func _destroy_breakable_tiles_in_radius() -> void:
	for terrain in get_tree().get_nodes_in_group("BreakableTerrain"):
		_erase_breakable_cells(terrain)


func _erase_breakable_cells(terrain : TileMapLayer) -> void:
	var tile_size : Vector2i = terrain.tile_set.tile_size
	var local_center : Vector2 = terrain.to_local(global_position)
	var center_cell : Vector2i = terrain.local_to_map(local_center)
	var cell_radius : int = int(ceil(explosion_radius / min(tile_size.x, tile_size.y)))

	for x in range(-cell_radius, cell_radius + 1):
		for y in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(x, y)
			var cell_local_center : Vector2 = terrain.map_to_local(cell)
			if local_center.distance_to(cell_local_center) > explosion_radius:
				continue

			if terrain.get_cell_source_id(cell) != -1:
				terrain.erase_cell(cell)

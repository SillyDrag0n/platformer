extends Enemy

@export var is_chasing: bool = false
@export var gun_muzzle: Marker2D

var bandit_attack = preload("res://enemies/bandit/bandit_attack.tscn")

const SPEED = 90.0
const GROUND_MASK : int = 1 | (1 << 7) # Ground (layer 1) + OneWayPlatform (layer 8) - anything the bandit can actually stand on

# How far ahead of center (past the collision capsule's radius) and how far below the feet
# to probe for floor before committing to a step in that direction, so the bandit stops at
# a ledge instead of walking off it while chasing.
const LEDGE_CHECK_AHEAD : float = 20.0
const LEDGE_CHECK_DEPTH : float = 32.0
const FEET_OFFSET : float = 30.0 # half the collision capsule's height

var player_global_position: Vector2


func _physics_process(_delta: float) -> void:
	chase_player()


func chase_player():
	if is_chasing:
		get_player_position()
		var direction = (player_global_position - global_position).normalized()
		if direction.x != 0 and not is_ground_ahead(direction.x):
			velocity.x = 0
		else:
			velocity.x = direction.x * SPEED
	else:
		velocity.x = 0
	move_and_slide()


# Casts a short ray from just past the leading edge of the capsule, at foot height, straight
# down - if it doesn't hit ground within LEDGE_CHECK_DEPTH, there's a drop-off ahead.
func is_ground_ahead(direction_x : float) -> bool:
	var probe_origin : Vector2 = global_position + Vector2(sign(direction_x) * LEDGE_CHECK_AHEAD, FEET_OFFSET)
	var probe_end : Vector2 = probe_origin + Vector2(0, LEDGE_CHECK_DEPTH)

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(probe_origin, probe_end)
	query.collision_mask = GROUND_MASK

	var result := space_state.intersect_ray(query)
	return not result.is_empty()


func set_chase(should_chase: bool):
	is_chasing = should_chase


func shoot():
	var attack = bandit_attack.instantiate() as Node2D
	attack.global_position = gun_muzzle.global_position
	get_player_position()
	attack.direction = (player_global_position - global_position).normalized()
	attack.rotation = attack.direction.angle()
	get_tree().current_scene.add_child(attack)


func get_player_position():
	if PlayerManager.player != null:
		player_global_position = PlayerManager.player.global_position
	else:
		player_global_position = Vector2.ZERO

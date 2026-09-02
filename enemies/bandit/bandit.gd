extends Enemy

@export var is_chasing: bool = false
@export var gun_muzzle: Marker2D

# The state machine, so a hit can wake him. It is normally driven only by the AggroRange and
# AttackRange areas (see state_machine_controller.gd), which is the whole problem below.
@export var state_machine: NodeFiniteStateMachine

# Walls block sight; one-way platforms do not, since they are thin things you can plainly see past.
const SIGHT_MASK : int = 1 # Ground

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
		if _should_hold_ground():
			velocity.x = 0
		else:
			var direction = (player_global_position - global_position).normalized()
			if direction.x != 0 and not is_ground_ahead(direction.x):
				velocity.x = 0
			else:
				velocity.x = direction.x * SPEED
	else:
		velocity.x = 0
	move_and_slide()


# A player who is off the ground has not gone anywhere he needs to walk to - they are still right
# in front of him, just above him. Closing on that had the bandit shuffle a step nearer on every
# jump and end up walking in under their feet. He holds the spot instead, and only gives it up for
# a player who actually puts distance between them.
func _should_hold_ground() -> bool:
	var player = PlayerManager.player
	if player == null or not player.has_method("is_on_floor"):
		return false
	if player.is_on_floor():
		return false
	return absf(player_global_position.x - global_position.x) <= attack_reach()


# How far in front of him counts as "already there". Read off the attack range rather than written
# down twice, so it stays in step if that box is ever retuned.
func attack_reach() -> float:
	var shape_node : CollisionShape2D = get_node_or_null("AttackRange/CollisionShape2D")
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return 0.0
	return (shape_node.shape as RectangleShape2D).size.x * 0.5

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
	ProjectileLayer.spawn(attack)


func get_player_position():
	if PlayerManager.player != null:
		player_global_position = PlayerManager.player.global_position
	else:
		player_global_position = Vector2.ZERO


# --- Being shot ---

# The bandit's states are driven entirely off his two detection areas, so nothing about taking a
# bullet ever reached the state machine: a player firing from beyond the AggroRange - which the
# revolver comfortably outranges - could empty a cylinder into a bandit who went on idling as if
# nothing had happened.
#
# A hit now makes him look for whoever fired it. Sight is checked without a facing cone on purpose:
# being shot is exactly the thing that makes a man turn round, so what matters is whether anything
# is actually in the way, not which way he happened to be looking. Shot from behind cover or
# through a wall he stays put rather than magically knowing where the player is.
func take_damage(amount: int) -> void:
	super.take_damage(amount)
	# super.take_damage() runs die() on the killing blow, which queues him free - there is nothing
	# left to wake.
	if health_amount <= 0:
		return
	_look_for_whoever_shot_me()


func _look_for_whoever_shot_me() -> void:
	if state_machine == null or state_machine.current_node_state == null:
		return
	# Only an idle bandit is worth waking. One already aggroed, chasing, shooting or reloading is
	# busy with the player as it is, and dropping him back into a walk would interrupt that.
	if state_machine.current_node_state.name.to_lower() != "idle":
		return
	if not can_see_player():
		return
	# Chase rather than Aggro: he is being shot from outside his aggro range, so the job is to
	# close the distance. Chase also starts the give-up timer, so a bandit sniped from across the
	# level eventually settles rather than walking after the player forever.
	state_machine.transition_to("Chase")


func can_see_player() -> bool:
	if PlayerManager.player == null:
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, PlayerManager.player.global_position)
	query.collision_mask = SIGHT_MASK
	query.exclude = [self]

	return space_state.intersect_ray(query).is_empty()

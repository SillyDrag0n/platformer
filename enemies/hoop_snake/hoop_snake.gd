extends Enemy

const GROUND_MASK : int = 1 | (1 << 7) # Ground (layer 1) + OneWayPlatform (layer 8) - anything the snake can roll on

@export var roll_speed : float = 260.0
@export var visual_radius : float = 12.0 # purely cosmetic - controls how fast the sprite spins while rolling
@export var recover_pause : float = 0.6 # how long the snake sits still after coasting to a stop before re-aiming and rolling again
# Player.tscn's collision capsule is centered on the player's own origin (not the feet), so +24
# lands near the ankles/lower legs rather than the waist.
@export var follow_offset : Vector2 = Vector2(0, 24)

@onready var state_machine : NodeFiniteStateMachine = $StateMachine

# Locked in once per roll (see roll_state.gd's enter()) rather than re-read every frame, so a roll
# that starts toward the player keeps going straight underneath them if they jump overhead instead
# of curving to chase their new height.
var roll_direction : float = 1.0

var is_attached : bool = false
var attached_player : Node2D = null


func _on_aggro_range_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player") and not is_attached:
		state_machine.transition_to("Roll")


# The player's own Hurtbox is torso-height and doesn't reach down to a rolling hoop's much
# shorter profile, so contact is detected with a dedicated area on the snake itself instead of
# relying on the player's Hurtbox to reach down and find it.
func _on_player_detector_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		attach_to_player(body)


# Same ledge-probe idea as bandit.gd/skeleton.gd's is_ground_ahead(), just without their walking
# FEET_OFFSET - the hoop's collision circle is centered on the ground contact point, not sitting
# on top of a tall capsule.
func is_ground_ahead(direction_x : float) -> bool:
	var probe_origin : Vector2 = global_position + Vector2(sign(direction_x) * 18.0, 0.0)
	var probe_end : Vector2 = probe_origin + Vector2(0.0, 40.0)

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(probe_origin, probe_end)
	query.collision_mask = GROUND_MASK

	var result := space_state.intersect_ray(query)
	return not result.is_empty()


func get_player_direction() -> float:
	if PlayerManager.player == null:
		return roll_direction
	var dx : float = PlayerManager.player.global_position.x - global_position.x
	return signf(dx) if dx != 0.0 else roll_direction


# True once the player is now behind the snake's current roll direction - i.e. the snake has
# already rolled underneath/past them (jumped over) - so Roll can cut straight to Recover instead
# of committing to the full max_roll_duration every time.
func has_overshot_player() -> bool:
	if PlayerManager.player == null:
		return false
	var dx : float = PlayerManager.player.global_position.x - global_position.x
	return dx != 0.0 and signf(dx) != roll_direction


# Called by the player (see player.gd's _on_hurtbox_body_entered) instead of the usual
# take_hit()/knockback flow, since getting touched by the snake means it grabs on rather than just
# dealing a hit. Player.attach_snake() can refuse (already invulnerable, or the hit was lethal), in
# which case the snake never considers itself attached and just keeps rolling.
func attach_to_player(player : Node2D) -> void:
	if is_attached:
		return
	if not player.attach_snake(self):
		return
	is_attached = true
	attached_player = player
	state_machine.transition_to("Attached")


# Called by the player's SnakeAttached state once its jump-mash threshold is reached - struggling
# free kills the snake outright rather than sending it back off to roll around again.
func detach() -> void:
	if not is_attached:
		return
	is_attached = false
	attached_player = null
	die()


func die() -> void:
	if is_attached and attached_player != null:
		attached_player.notify_snake_detached(self)
	super.die()

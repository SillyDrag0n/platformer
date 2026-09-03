class_name CactusCoyote
extends Enemy

# The tutorial's closing encounter
# (see levels/regions/plains/farm_house_backyard/coyote_encounter.gd): the player catches it eating
# the remains of one of Hutch's cows, it turns on them, and the backyard's far end becomes a small
# arena. Unlike the rest of the bestiary it is never killed - once its health is gone it bolts,
# which is what leaves the story hook behind.
#
# Uses the same plain enum + _physics_process shape as enemies/cactus/enemy_cactus.gd rather than
# the NodeFiniteStateMachine addon skeleton/bandit use: this is one fixed, telegraphed rhythm
# (stalk -> pounce -> recover -> stalk -> spikes) rather than a web of reactive transitions, and
# spelling it out in one file keeps the whole fight's pacing readable in one place.

signal fled

enum State { Feeding, Alerted, Stalk, PounceWindup, Pounce, Recover, SpikeVolley, Flee }

const SPIKE_SCENE : PackedScene = preload("res://enemies/cactus_coyote/coyote_spike.tscn")

const GROUND_MASK : int = 1 | (1 << 7) # Ground (layer 1) + OneWayPlatform (layer 8), same as skeleton.gd
# Matches enemies/_common/gravity.gd's own constant. Applied inline here rather than adding that
# helper node to the scene, since it also calls move_and_slide() itself - which would fight the
# per-state velocity this script sets every frame.
const GRAVITY : int = 1000

# Beat between the coyote looking up from the carcass and the fight actually starting, so the
# player gets a read on it before anything comes at them.
@export var alert_duration : float = 0.9

@export var stalk_speed : float = 120.0 # deliberately well under the player's 300 max, so they can always disengage
@export var stalk_duration : float = 1.1

# How close it wants to be before leaping. Also ends a stalk early once reached, so it doesn't
# walk into the player's face before committing to the pounce.
@export var pounce_range : float = 220.0
@export var pounce_windup : float = 0.45 # crouch/telegraph before the leap
@export var pounce_speed : float = 290.0
@export var pounce_lift : float = 400.0
# Safety net so a pounce that somehow never lands (shoved into geometry, no floor under it) still
# ends instead of leaving the fight stuck mid-air.
@export var max_pounce_duration : float = 1.6
@export var recover_duration : float = 0.8 # landing lag - the player's main window to shoot back

@export var volley_windup : float = 0.45 # rears up before firing, same telegraph length as the pounce
@export var volley_recover : float = 0.55
@export var spike_count : int = 3
@export var spike_spread_degrees : float = 22.0
@export var spike_muzzle_offset : Vector2 = Vector2(28.0, 10.0) # its snout - low down, it fires these on all fours

@export var flee_speed : float = 300.0
@export var flee_lift : float = 520.0
@export var flee_duration : float = 1.4

@onready var hurtbox : Area2D = $Hurtbox
# Walking into it hurts, once the fight is on. Body-to-body contact never registers on its own -
# see enemies/_common/contact_hitbox.gd for why this is a separate node rather than the Hurtbox.
@onready var hitbox : ContactHitbox = $Hitbox

var current_state : State = State.Feeding
# Starts facing away from the player's approach (they come in from the left), so the first read is
# a creature hunched over the carcass with its back turned rather than one already watching them.
var facing : float = 1.0

var _state_timer : float = 0.0
# Alternated rather than picked by range, so a player who hugs the coyote still gets shot at and
# one who keeps their distance still gets leapt at - the rhythm stays legible either way. Starts
# true so that the first flip makes the opening attack the pounce, the louder telegraph of the two.
var _spikes_next : bool = true
var _pounce_left_ground : bool = false
var _volley_fired : bool = false

# The spines this one has put in the air. They are parented to ProjectileLayer rather than to the
# coyote, so they outlive it and have to be recalled by hand when it turns tail - see
# _recall_spikes(). Entries free themselves on impact or on their own timer, so this list goes
# stale on its own and is only ever read back through is_instance_valid().
var _spikes_in_flight : Array[Node2D] = []

# Captured at _ready() so a lost fight can be handed back exactly as the player first found it -
# see reset_to_feeding(). die() zeroes both collision fields, so their resting values have to be
# remembered rather than re-read.
var _home_position : Vector2
var _full_health : int = 0
var _rest_collision_layer : int = 0
var _rest_collision_mask : int = 0


func _ready() -> void:
	_home_position = global_position
	_full_health = health_amount
	_rest_collision_layer = collision_layer
	_rest_collision_mask = collision_mask
	animated_sprite.play("feed")


# Puts the coyote back over the carcass, whole. Called by the encounter when the player dies, so a
# retry opens on the scene they walked in on rather than on whatever the lost fight left behind -
# a half-dead coyote mid-pounce on the far side of the arena.
func reset_to_feeding() -> void:
	global_position = _home_position
	velocity = Vector2.ZERO
	health_amount = _full_health
	current_state = State.Feeding
	facing = 1.0
	_state_timer = 0.0
	_spikes_next = true
	_pounce_left_ground = false
	_volley_fired = false
	collision_layer = _rest_collision_layer
	collision_mask = _rest_collision_mask
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	# Back to being safe to stand next to - the retry opens on the player walking in on it eating,
	# and that approach must not cost them health before the fight has even started.
	hitbox.set_active(false)
	_update_sprite_facing()
	animated_sprite.play("feed")


func _physics_process(delta : float) -> void:
	match current_state:
		State.Feeding:
			velocity.x = 0.0
		State.Alerted:
			_run_alerted(delta)
		State.Stalk:
			_run_stalk(delta)
		State.PounceWindup:
			_run_pounce_windup(delta)
		State.Pounce:
			_run_pounce(delta)
		State.Recover:
			_run_recover(delta)
		State.SpikeVolley:
			_run_spike_volley(delta)
		State.Flee:
			_run_flee(delta)

	_apply_gravity(delta)
	move_and_slide()


# Called by the encounter zone once the player is stood on their mark, to start the feeding loop
# from the top - the beat they are being held there to watch should open where the camera does
# rather than wherever the idle loop happened to have got to.
func feed() -> void:
	if current_state != State.Feeding:
		return
	velocity.x = 0.0
	animated_sprite.play("feed")


# Called by the encounter zone when the player walks in on it, and by take_damage() if they open
# fire first. Idempotent, so neither route can restart a fight already under way.
func spot_player() -> void:
	if current_state != State.Feeding:
		return
	current_state = State.Alerted
	_state_timer = alert_duration
	# It is only dangerous to touch once it has turned on them. Before that the player is being
	# walked up behind it on purpose (see
	# levels/regions/plains/farm_house_backyard/coyote_encounter.gd).
	hitbox.set_active(true)
	_face_player()
	animated_sprite.play("alert")


func _run_alerted(delta : float) -> void:
	velocity.x = 0.0
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_stalk()


func _start_stalk() -> void:
	current_state = State.Stalk
	_state_timer = stalk_duration
	animated_sprite.play("stalk")


func _run_stalk(delta : float) -> void:
	_state_timer -= delta

	var direction : float = _direction_to_player()
	# Same ledge guard as skeleton.gd's chase: it holds position rather than walking off the edge
	# of its own arena.
	if is_on_wall() or not _is_ground_ahead(direction):
		velocity.x = 0.0
	else:
		velocity.x = direction * stalk_speed
		facing = direction
		_update_sprite_facing()

	# Ends early once it is already well inside pounce range, so it does not spend the rest of the
	# stalk shuffling into the player.
	if _state_timer <= 0.0 or absf(_offset_to_player()) <= pounce_range * 0.5:
		_choose_next_attack()


func _choose_next_attack() -> void:
	_spikes_next = not _spikes_next
	if _spikes_next:
		_start_spike_volley()
	else:
		_start_pounce_windup()


func _start_pounce_windup() -> void:
	current_state = State.PounceWindup
	_state_timer = pounce_windup
	velocity.x = 0.0
	_face_player()
	animated_sprite.play("pounce_windup")


func _run_pounce_windup(delta : float) -> void:
	velocity.x = 0.0
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_pounce()


func _start_pounce() -> void:
	current_state = State.Pounce
	_state_timer = max_pounce_duration
	_face_player()
	# Locked in for the whole leap rather than re-aimed each frame - a pounce the player can jump
	# over or dash under is the point, and a homing one would not be dodgeable at all.
	velocity = Vector2(facing * pounce_speed, -pounce_lift)
	_pounce_left_ground = false
	animated_sprite.play("pounce")


func _run_pounce(delta : float) -> void:
	_state_timer -= delta

	if is_on_wall():
		velocity.x = 0.0

	if not is_on_floor():
		_pounce_left_ground = true
	elif _pounce_left_ground:
		_start_recover()
		return

	if _state_timer <= 0.0:
		_start_recover()


func _start_recover() -> void:
	current_state = State.Recover
	_state_timer = recover_duration
	velocity.x = 0.0
	animated_sprite.play("recover")


func _run_recover(delta : float) -> void:
	velocity.x = 0.0
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_stalk()


func _start_spike_volley() -> void:
	current_state = State.SpikeVolley
	_state_timer = volley_windup
	_volley_fired = false
	velocity.x = 0.0
	_face_player()
	animated_sprite.play("spike")


func _run_spike_volley(delta : float) -> void:
	velocity.x = 0.0
	_state_timer -= delta
	if _state_timer > 0.0:
		return

	if not _volley_fired:
		_volley_fired = true
		_state_timer = volley_recover
		fire_spikes()
		return

	_start_stalk()


# Fans the volley around the line to the player rather than firing it flat, so standing still is
# punished but a single sidestep or jump still clears the whole spread.
func fire_spikes() -> void:
	var origin : Vector2 = global_position + Vector2(facing * spike_muzzle_offset.x, spike_muzzle_offset.y)
	var aim : Vector2 = Vector2(facing, 0.0)
	var player = PlayerManager.player
	if player != null:
		aim = (player.global_position - origin).normalized()

	var spread : float = deg_to_rad(spike_spread_degrees)
	for i in spike_count:
		var offset : float = 0.0 if spike_count <= 1 else float(i) / float(spike_count - 1) - 0.5
		var spike := SPIKE_SCENE.instantiate() as Node2D
		spike.global_position = origin
		spike.direction = aim.rotated(offset * spread)
		ProjectileLayer.spawn(spike)
		_spikes_in_flight.append(spike)


# Running it off is the win condition, so Enemy.die()'s kill credit / loot drop / death effect are
# deliberately never reached - there is no carcass to collect and no bounty to report on a creature
# that got away.
func die() -> void:
	if current_state == State.Flee:
		return
	current_state = State.Flee
	_state_timer = flee_duration
	# Nothing to shoot and nothing to run into on its way out - the fight is over the moment it
	# turns tail, so it should not be able to clip the player as it leaves.
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_active(false)
	_recall_spikes()

	# Away from the player, so the exit reads as bolting rather than through them.
	var player = PlayerManager.player
	if player != null:
		facing = signf(global_position.x - player.global_position.x)
	if facing == 0.0:
		facing = 1.0
	_update_sprite_facing()

	velocity = Vector2(facing * flee_speed, -flee_lift)
	animated_sprite.play("flee")


# The last volley outlives the creature that fired it: spines live on ProjectileLayer and keep
# travelling for as long as their own timer allows. Clearing its own collision (above) stopped the
# coyote clipping the player on the way out but left those in the air, so a fight the player had
# already won could still kill them a second or two later.
#
# In the tutorial that lands squarely in the worst place for it - the encounter has already logged
# the coyote as driven off and stood its own death handler down, and the debrief is holding the
# player's controls - so the volley is called back with the creature rather than patched around
# further downstream. See levels/regions/plains/farm_house_backyard/coyote_encounter.gd.
func _recall_spikes() -> void:
	for spike in _spikes_in_flight:
		if is_instance_valid(spike):
			spike.queue_free()
	_spikes_in_flight.clear()


func _run_flee(delta : float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		fled.emit()
		queue_free()


func take_damage(amount : int) -> void:
	if current_state == State.Flee:
		return
	# Shooting it before walking into the trigger zone is a perfectly reasonable opening move, so
	# a hit wakes it up the same way being walked in on does.
	spot_player()
	super.take_damage(amount)


func _apply_gravity(delta : float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta


func _face_player() -> void:
	var direction : float = _direction_to_player()
	if direction != 0.0:
		facing = direction
	_update_sprite_facing()


func _update_sprite_facing() -> void:
	animated_sprite.flip_h = facing > 0.0


func _offset_to_player() -> float:
	var player = PlayerManager.player
	if player == null:
		return 0.0
	return player.global_position.x - global_position.x


func _direction_to_player() -> float:
	var offset : float = _offset_to_player()
	return signf(offset) if offset != 0.0 else facing


func _is_ground_ahead(direction_x : float) -> bool:
	# Cast from past the nose rather than from under the ribs: the body is a quadruped's, 56 wide,
	# so anything shorter than its half-length only ever finds the ground it is already stood on.
	var probe_origin : Vector2 = global_position + Vector2(signf(direction_x) * 34.0, 30.0)
	var probe_end : Vector2 = probe_origin + Vector2(0.0, 32.0)

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(probe_origin, probe_end)
	query.collision_mask = GROUND_MASK

	return not space_state.intersect_ray(query).is_empty()

extends Area2D

# Orchestrates the tutorial's closing beat: the player walks in on a cactus coyote eating the
# remains of one of Hutch's cows, the way back seals behind them, and the fight runs until the
# coyote is driven off. Then the wall drops, the player says his piece, and the level hands back to
# the hub.
#
# The approach is staged rather than left to the player: crossing the trigger takes their controls
# (GameInputEvents.take_scripted_control()) and walks them up to Marker2D, so the read that follows
# - the coyote hunched over the carcass, the way out closing behind them - lands the same way every
# time instead of at whatever pace they happened to sprint in at. They get the controls back when
# the fight actually starts, not when the wall goes up.
#
# The seal/unseal is the same disabled-CollisionShape2D trick as levels/boss_arena/boss_arena.gd,
# reimplemented here rather than reused: BossArena's whole contract is a BossStateController it can
# call start_boss_fight() on and wait on defeated for, and the coyote is a plain Enemy that flees.

# Waiting and Fight are the resting points - the three between them run off _physics_process and
# are the only time this holds the player's controls.
enum Stage { Waiting, Approach, Feeding, Alerting, Fight }

@export var coyote : CactusCoyote
@export var dialogue_box : DialogueBox
# Placeholder copy - a role rather than a proper name, since the protagonist has none established
# in the project yet. Both this and dialogue_lines are meant to be rewritten in the scene.
@export var speaker_name : String = "Bounty Hunter"
@export var dialogue_lines : Array[String] = []
# Where the tutorial hands off once the player has had his say. Keyed into SceneManager.scenes
# rather than a PackedScene so this stays a level-flow decision made in the scene.
@export var exit_scene_key : String = "Hub"
# The level's camera, clamped to the arena wall for the duration of the fight so the framing stops
# where the player does instead of panning off over ground they can't reach.
@export var camera : Camera2D

@export_category("Staged Approach")
# How long the player is held on their mark watching it eat before it looks up. Long enough to read
# the carcass and the spines, short enough that it never reads as dropped input.
@export var feeding_beat : float = 1.2
# How close to the mark's x counts as arrived. About a frame of run speed, so the walk settles on
# the mark rather than shuffling either side of it.
@export var arrival_tolerance : float = 8.0
# Safety net: a walk that can't finish (something in the way, a mark left off the floor) hands the
# controls back anyway rather than freezing the player mid-cutscene.
@export var approach_timeout : float = 8.0

@onready var mark : Marker2D = get_node_or_null("Marker2D")

var _stage : Stage = Stage.Waiting
var _stage_timer : float = 0.0
# Which way the walk set off, so stepping past the mark ends it as surely as landing on it.
var _walk_direction : float = 0.0

var _open_limit_left : int
var _open_limit_right : int


func _ready() -> void:
	# Read off the scene before the first _seal() touches them, so unsealing restores the framing
	# the level was authored with rather than whatever the previous seal left behind.
	if is_instance_valid(camera):
		_open_limit_left = camera.limit_left
		_open_limit_right = camera.limit_right
	_seal(false)
	set_physics_process(false)

	# Gated on the same persisted flag pattern as WelcomeNPC's greeting (see
	# GameStateManager.has_driven_off_coyote) so coming back to the backyard after the coyote has
	# already been run off doesn't stage the whole encounter again. The coyote goes with it rather
	# than being left standing over a carcass with nothing to set it off.
	if GameStateManager.has_driven_off_coyote:
		if coyote != null:
			coyote.queue_free()
		queue_free()
		return

	coyote.fled.connect(_on_coyote_fled)
	dialogue_box.closed.connect(_on_dialogue_closed)
	PlayerManager.player_died.connect(_on_player_died)


# The lock lives on an autoload, so it outlives this scene. An encounter torn down mid-approach
# (the exit transition, a level reload) has to hand the controls back or the player wakes up frozen
# in whatever scene comes next.
func _exit_tree() -> void:
	GameInputEvents.release_scripted_control()


func _on_body_entered(body : Node2D) -> void:
	if _stage != Stage.Waiting or not body.is_in_group("Player"):
		return
	set_deferred("monitoring", false)

	# Shooting it from outside the zone is a fair opening move, and a fight already under way has
	# no use for a staged walk-in - seal up and leave the player holding their own controls.
	if not is_instance_valid(coyote) or coyote.current_state != CactusCoyote.State.Feeding:
		_seal(true)
		_stage = Stage.Fight
		return

	# The wall stays down for now: it's the far side of the walk, and raising it here would slam it
	# shut in front of a player still on the wrong side of it.
	_stage = Stage.Approach
	_stage_timer = approach_timeout
	_walk_direction = 0.0
	GameInputEvents.take_scripted_control()
	set_physics_process(true)


func _physics_process(delta : float) -> void:
	match _stage:
		Stage.Approach:
			_run_approach(delta)
		Stage.Feeding:
			_run_feeding(delta)
		Stage.Alerting:
			_run_alerting()


# Steered through movement_input() rather than by writing velocity: the player walks under their
# own controller, so the run animation, the gravity and the ground under them all behave exactly as
# they do when it's the player holding the stick.
func _run_approach(delta : float) -> void:
	var player = PlayerManager.player
	if not is_instance_valid(player) or mark == null:
		_start_feeding_beat()
		return

	_stage_timer -= delta
	var offset : float = mark.global_position.x - player.global_position.x
	var direction : float = signf(offset)
	if _walk_direction == 0.0:
		_walk_direction = direction

	# Overshooting counts as arrived too - a walk stopped only by the tolerance window would turn
	# around and pace back and forth across the mark when momentum carried them past it.
	var arrived : bool = absf(offset) <= arrival_tolerance or direction != _walk_direction
	if arrived or _stage_timer <= 0.0:
		_start_feeding_beat()
		return

	GameInputEvents.set_scripted_movement(direction)


# On the mark: the way back closes, and the coyote gets its beat over the carcass before it notices
# anyone is stood behind it.
func _start_feeding_beat() -> void:
	_stage = Stage.Feeding
	_stage_timer = feeding_beat
	GameInputEvents.set_scripted_movement(0.0)
	_seal(true)
	if is_instance_valid(coyote):
		coyote.feed()


func _run_feeding(delta : float) -> void:
	_stage_timer -= delta
	if _stage_timer > 0.0:
		return

	if not is_instance_valid(coyote):
		_start_fight()
		return
	_stage = Stage.Alerting
	coyote.spot_player()


# The controls come back the moment the coyote is done looking up and actually comes at them.
# Handing them over any earlier would let the player leave mid-telegraph, which is the one read the
# whole approach exists to give them.
func _run_alerting() -> void:
	if not is_instance_valid(coyote) or coyote.current_state != CactusCoyote.State.Alerted:
		_start_fight()


func _start_fight() -> void:
	_stage = Stage.Fight
	set_physics_process(false)
	GameInputEvents.release_scripted_control()


# Losing the fight has to hand the encounter back intact. The wall is up and the trigger has
# already spent itself by this point, so without this a respawn at the campfire outside would leave
# the player shut out of an arena they can no longer open - the coyote sealed in, half-dead, with
# nothing left to set it on them.
func _on_player_died() -> void:
	if GameStateManager.has_driven_off_coyote:
		return
	# Whatever else is true of the encounter, a player who died mid-approach must not respawn with
	# their controls still taken off them.
	_start_fight()
	if not is_instance_valid(coyote) or coyote.current_state == CactusCoyote.State.Flee:
		return

	_stage = Stage.Waiting
	_seal(false)
	coyote.reset_to_feeding()
	set_deferred("monitoring", true)


func _on_coyote_fled() -> void:
	# Burned on the coyote actually being run off, not on the fight starting - this one can be
	# lost, and a player who dies partway through should find it waiting for them, not already
	# spent.
	GameStateManager.has_driven_off_coyote = true
	_start_fight()
	_seal(false)
	# DialogueBox extends MenuPopup, which sets InventoryManager.is_open while open - and every
	# GameInputEvents getter checks that - so opening it freezes player control for the closing
	# line without needing a separate input lock.
	dialogue_box.show_dialogue(speaker_name, dialogue_lines)


func _on_dialogue_closed() -> void:
	SceneManager.transition_to_scene_faded(exit_scene_key)


# The arena is down to a single wall on the left, sat as a plain child of the zone rather than
# under a Walls node - so its walls are however many StaticBody2D children it has.
func _wall_bodies() -> Array[Node]:
	var bodies : Array[Node] = []
	for child in get_children():
		if child is StaticBody2D:
			bodies.append(child)
	return bodies


func _seal(sealed : bool) -> void:
	for wall in _wall_bodies():
		for shape in wall.get_children():
			if shape is CollisionShape2D:
				# Deferred, not assigned outright: sealing can be driven from a physics callback,
				# and the physics server refuses to enable a shape mid-query-flush ("Can't change
				# this state while flushing queries"). Assigning directly flips the node's own flag
				# - so it inspects as sealed - while the server never gets the shape and the player
				# walks straight back out through it.
				shape.set_deferred("disabled", not sealed)
	_clamp_camera(sealed)


# Pens the camera in with the player for the fight, and hands the level's own framing back after.
# Driven off the wall shapes rather than hand-entered numbers so moving a wall in the editor moves
# the limit with it.
func _clamp_camera(sealed : bool) -> void:
	if not is_instance_valid(camera):
		return

	if not sealed:
		camera.limit_left = _open_limit_left
		camera.limit_right = _open_limit_right
		return

	var faces := _arena_faces()
	var left := faces.x
	var right := faces.y

	# Walled on both sides and narrower than the camera sees at this zoom: Godot's Camera2D applies
	# the left limit first and then lets the right one override it, so limits that tight would pin
	# the arena against the right edge of the screen with open ground showing past the left wall.
	# Widening symmetrically locks the camera dead centre on it instead. With one wall standing
	# there is nothing to centre on - that side stops at the wall, the other keeps the level's own
	# limit.
	if left != -INF and right != INF:
		var view_width : float = camera.get_viewport_rect().size.x / camera.zoom.x
		if right - left < view_width:
			var centre : float = (left + right) * 0.5
			left = centre - view_width * 0.5
			right = centre + view_width * 0.5

	camera.limit_left = int(round(left)) if left != -INF else _open_limit_left
	camera.limit_right = int(round(right)) if right != INF else _open_limit_right


# The inner faces of the walls, as x = left and y = right. Either stays infinite when nothing on
# that side could be measured, which is the ordinary case now that only the left wall is left.
func _arena_faces() -> Vector2:
	var left := -INF
	var right := INF
	for wall in _wall_bodies():
		for shape in wall.get_children():
			if not (shape is CollisionShape2D and shape.shape is RectangleShape2D):
				continue
			var half : float = shape.shape.size.x * 0.5 * absf(shape.global_scale.x)
			var centre : float = shape.global_position.x
			# Sided off the zone's own centre rather than by node name, so the walls stay plain
			# children the way _seal() treats them.
			if centre < global_position.x:
				left = maxf(left, centre + half)
			else:
				right = minf(right, centre - half)

	return Vector2(left, right)

extends NodeState

@export var character_body_2d : CharacterBody2D
@export var grapple_hook : Node2D
@export var dash_state : Node

@export_category("Run")
@export var run_speed : int = 350
@export var max_horizontal_speed : int = 300
@export var slow_down_speed : int = 1700

@export_category("Crouch")
# Grounded + crouch held is the same scope lower_body_controller.gd uses for the crouch pose and
# collision shrink - matching it here is what actually makes crouch-walking slower instead of just
# shorter.
@export var crouch_speed_scale : float = 0.5

@export_category("Jump")
@export var jump_height : float = -375
@export var jump_horizontal_speed : int = 425
@export var max_jump_horizontal_speed : int = 225
@export var max_jump_count : int = 2
@export var jump_gravity : int = 1000

@export_category("Fall")
@export var fall_gravity : int = 700
@export var fall_horizontal_speed : int = 200
@export var max_fall_horizontal_speed : int = 200
@export var coyote_time : float = 0.1

@export_category("Air Control")
@export var air_deceleration : float = 1800

const ONE_WAY_PLATFORM_LAYER : int = 8
const FOOTSTEP_INTERVAL := 0.22

var current_jump_count : int = 0
var coyote_remaining : float = 0.0
var footstep_timer : float = 0.0

var footstep_dust_effect = preload("res://player/effects/footstep_dust_effect.tscn")


func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	# captured before any movement this frame, so it reflects the floor state move_and_slide()
	# left behind last frame - used below to detect the leaving-ground and landing edges
	var was_on_floor : bool = character_body_2d.is_on_floor()
	var direction : float = GameInputEvents.movement_input()

	# gravity - heavier while an active jump is in progress (rise or its own descent), lighter and
	# floatier if merely having walked off a ledge, matching the original separate Jump/Fall
	# states' distinct tuning
	var gravity : int = jump_gravity if current_jump_count > 0 else fall_gravity
	character_body_2d.velocity.y += gravity * delta

	# coyote time: stays freshly armed while grounded, so the window starts counting down the
	# instant the floor disappears without a jump having been thrown
	if was_on_floor and current_jump_count == 0:
		coyote_remaining = coyote_time
	elif coyote_remaining > 0.0:
		coyote_remaining -= delta

	# jump trigger - a grounded or coyote jump always resets the count first so it gets the full
	# multi-jump allowance; otherwise this is a mid-air multi-jump, allowed while under the cap
	if GameInputEvents.jump_input():
		if was_on_floor or coyote_remaining > 0.0:
			current_jump_count = 0
			character_body_2d.velocity.y = jump_height
			current_jump_count += 1
			coyote_remaining = 0.0
			spawn_dust()
		elif current_jump_count < _effective_max_jump_count():
			character_body_2d.velocity.y = jump_height
			current_jump_count += 1

	# horizontal movement
	if was_on_floor:
		var speed_scale : float = crouch_speed_scale if GameInputEvents.crouch_input() else 1.0
		if direction:
			character_body_2d.velocity.x += direction * run_speed * speed_scale
			var max_speed : float = max_horizontal_speed * speed_scale
			character_body_2d.velocity.x = clamp(character_body_2d.velocity.x, -max_speed, max_speed)
		else:
			character_body_2d.velocity.x = move_toward(character_body_2d.velocity.x, 0, slow_down_speed)
	else:
		var h_speed : int = jump_horizontal_speed if current_jump_count > 0 else fall_horizontal_speed
		var max_h_speed : int = max_jump_horizontal_speed if current_jump_count > 0 else max_fall_horizontal_speed
		if direction != 0:
			character_body_2d.velocity.x += direction * h_speed
			character_body_2d.velocity.x = clamp(character_body_2d.velocity.x, -max_h_speed, max_h_speed)
		else:
			character_body_2d.velocity.x = move_toward(character_body_2d.velocity.x, 0, air_deceleration * delta)

	# ignore one-way platforms entirely while rising, so a jump that doesn't quite clear one can't
	# get caught straddling its underside. Re-enabled once no longer ascending so landing on top
	# still works normally on the way down.
	character_body_2d.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, character_body_2d.velocity.y >= 0.0)

	character_body_2d.move_and_slide()

	# landing - checked after move_and_slide() so it reflects this frame's actual floor contact.
	# Gated on velocity.y >= 0.0 (not just is_on_floor()) for the same reason as the one-way-
	# platform mask above: a platform grazed from below while still rising can briefly report
	# is_on_floor() at the corner, which would otherwise reset the jump count mid-ascent and hand
	# back a free extra jump. The dust spawn is further gated to the falling-to-grounded edge so
	# it doesn't refire every frame spent standing.
	if character_body_2d.is_on_floor() and character_body_2d.velocity.y >= 0.0:
		if not was_on_floor:
			spawn_dust()
		current_jump_count = 0
		coyote_remaining = 0.0

	# footsteps (grounded + moving only); resets on every stop so a fresh walk always starts a
	# full interval away from its first step, matching how re-entering Run used to behave
	if character_body_2d.is_on_floor() and direction != 0:
		footstep_timer -= delta
		if footstep_timer <= 0:
			footstep_timer = FOOTSTEP_INTERVAL
			spawn_dust()
	else:
		footstep_timer = FOOTSTEP_INTERVAL

	# transitioning states

	if AbilityManager.is_unlocked("grapple_hook") and GameInputEvents.grapple_input() and grapple_hook.find_anchor(character_body_2d.global_position) != null:
		transition.emit("Grapple")
		return

	if AbilityManager.is_unlocked("dash") and dash_state.can_dash() and GameInputEvents.dash_input():
		transition.emit("Dash")


func enter():
	if character_body_2d.is_on_floor():
		current_jump_count = 0
	coyote_remaining = 0.0
	footstep_timer = FOOTSTEP_INTERVAL


func exit():
	pass


func spawn_dust():
	var dust = footstep_dust_effect.instantiate() as Node2D
	dust.global_position = character_body_2d.global_position
	character_body_2d.get_parent().add_child(dust)


func _effective_max_jump_count() -> int:
	if AbilityManager.is_unlocked("double_jump"):
		return max_jump_count
	return 1

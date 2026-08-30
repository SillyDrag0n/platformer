extends Node

# Everything below the hip: which AnimationPlayer clip is playing and which way the legs face.
# The upper body (arms/head aiming at the mouse/stick) is driven independently by
# upper_body_controller.gd, since aim direction can't be baked into a keyframed clip the way a
# walk cycle can.

@export var character_body_2d : CharacterBody2D
@export var state_machine : NodeFiniteStateMachine
@export var animation_player : AnimationPlayer
@export var leg_targets : Node2D
@export var leg_r_ik : SoupTwoBoneIK
@export var leg_l_ik : SoupTwoBoneIK
@export var hip : Bone2D
# Torso is a flat sprite under a separate "Body" node, not part of the Bones/Skeleton2D chain -
# nothing was ever making it follow Hip's own bob/drop/lean, in ANY clip (idle/walk's subtle bob
# included, not just crouch - crouch just made the disconnect obvious since its Hip drop is much
# bigger). Tracking it here in _physics_process (see below) fixes that for every pose, procedural
# or clip-based, in one place instead of needing a Torso keyframe track per clip.
@export var body : Node2D

# Give the procedural poses below their own timers to read progress from, instead of duplicating
# hurt/dash duration constants here - Dash/Hurt already own that timing.
@export var dash_state : Node
@export var hurt_state : Node

@export_category("Crouch Pose")
# Applied as an extra Hip offset on top of whichever base clip (idle or walk) play_normal_clip()
# already picked, rather than being its own separate clip - the old dedicated "crouch" clip
# (player.tscn) is unused now. This is what lets crouching combine with walking (to duck under
# gunfire mid-stride, for example) instead of only working while standing still: idle/walk keep
# playing normally, legs and all, just from a lower Hip height. FootTargets are left wherever
# idle/walk already put them, so SoupTwoBoneIK bends the knees more automatically to close the
# shorter reach, same as every other Hip-drop pose here.
@export var crouch_hip_drop : float = 13.0

@export_category("Crouch Collision")
@export var collision_shape : CollisionShape2D
@export var hurtbox_collision_shape : CollisionShape2D
# Matched to crouch_hip_drop above by default so the hitbox shrinks by roughly the same amount
# the character visually appears to shrink - kept as its own separate tunable rather than reusing
# crouch_hip_drop directly, since the "right" collision shrink and the "right" visual drop aren't
# guaranteed to be the same number once someone starts tuning either one.
@export var crouch_collision_shrink : float = 13.0

@export_category("Leg Sprites")
# flip_h'd + offset-mirrored to match facing, same pattern as upper_body_controller.gd's
# head_sprite - the IK solve only rotates these bones, it never mirrors the texture's own
# left/right asymmetry, so the sprites need their own explicit flip.
@export var leg_r_sprite : Sprite2D
@export var shin_r_sprite : Sprite2D
@export var foot_r_sprite : Sprite2D
@export var leg_l_sprite : Sprite2D
@export var shin_l_sprite : Sprite2D
@export var foot_l_sprite : Sprite2D

@export_category("Walk Cycle")
@export var walk_speed_reference : float = 300.0
@export var min_walk_speed_scale : float = 0.5

@export_category("Footsteps")
@export var footstep_player : AudioStreamPlayer2D
@export var footstep_sounds : Array[AudioStream] = []
# Local times (seconds) within the "walk" clip where a foot actually plants - matches that clip's
# own Hip-bob keyframes (see player.tscn's "walk" Animation resource), not just an even split of
# its length, so the sound lines up with the pose instead of an arbitrary fraction of the cycle.
@export var footstep_times : PackedFloat32Array = [0.15, 0.45]

@export_category("Dash")
@export var dash_speed_scale : float = 1.8

# Procedural poses (Hurt/Dash/Grapple): computed live each frame from physics state, the same
# way upper_body_controller.gd drives the arms/head, instead of hand-keyframed clips. All offsets
# below are defined as a fixed local-space vector on FootR/FootL Target, so leg_targets' existing
# facing-mirror (see update_facing()) flips them for free - only Hip (outside that mirrored group)
# needs an explicit facing multiplier.
@export_category("Dash Pose")
@export var dash_hip_pushback : float = 4.0
@export var dash_hip_drop : float = 3.0
@export var dash_back_leg_extend : float = 10.0
@export var dash_back_leg_kick_degrees : float = -20.0
@export var dash_front_leg_tuck : float = 6.0
@export var dash_front_leg_kick_degrees : float = 15.0

@export_category("Hurt Pose")
@export var hurt_hip_kick : float = 3.0
@export var hurt_leg_stagger : float = 7.0
@export var hurt_leg_kick_degrees : float = 18.0

@export_category("Grapple Pose")
@export var grapple_swing_reference_speed : float = 300.0
@export var grapple_trail_distance : float = 8.0
@export var grapple_trail_kick_degrees : float = 22.0
@export var grapple_climb_tuck : float = 5.0

var facing : float = 1.0
var _leg_sprites : Array[Sprite2D] = []
var _leg_sprite_rest_offsets : Array[Vector2] = []

var _foot_r_target : Node2D
var _foot_l_target : Node2D
var _foot_r_lookat : Node2D
var _foot_l_lookat : Node2D
var _hip_rest_position : Vector2
var _body_rest_position : Vector2
var _foot_r_target_rest : Transform2D
var _foot_l_target_rest : Transform2D
var _foot_r_lookat_rest : Transform2D
var _foot_l_lookat_rest : Transform2D
var _leg_r_bone_rest_position : Vector2
var _leg_l_bone_rest_position : Vector2
var _leg_r_bone_rest_scale : Vector2
var _leg_l_bone_rest_scale : Vector2
var _collision_shape_rest_height : float
var _collision_shape_rest_position : Vector2
var _hurtbox_collision_shape_rest_position : Vector2
# Full-height duplicate of the capsule, kept at rest size even after collision_shape's own copy
# gets shrunk every frame - used purely as a query shape in _has_room_to_stand(), never assigned
# to a CollisionShape2D.
var _stand_test_shape : Shape2D

# Tracks whether crouch collision was actually applied last frame, separate from raw input, so
# _has_room_to_stand() only has to run the moment crouch is released (not every grounded frame)
# and so a ceiling can hold the player crouched across frames where they're no longer holding the
# button. See apply_crouch_collision() below.
var _is_crouching : bool = false
# Which physics frame _is_crouching was last resolved on - see get_is_crouching(). Needed because
# normal_state.gd (StateMachine) and this node are siblings, so whichever one's _physics_process
# the engine happens to run first each tick would otherwise read the other's stale value from the
# previous frame instead of this frame's.
var _crouch_resolved_physics_frame : int = -1

# Duplicated from normal_state.gd's constant of the same name - a one-way platform should never
# block standing up (you can already stand under one), so it's excluded from the ceiling probe in
# _has_room_to_stand() regardless of which way character_body_2d.collision_mask's own copy of this
# bit happens to be toggled that frame (see normal_state.gd's rising/falling toggle).
const ONE_WAY_PLATFORM_LAYER : int = 8


func _ready() -> void:
	_leg_sprites = [leg_r_sprite, shin_r_sprite, foot_r_sprite, leg_l_sprite, shin_l_sprite, foot_l_sprite]
	for sprite in _leg_sprites:
		_leg_sprite_rest_offsets.append(sprite.offset)

	# Cached once here, before any clip has played, so the procedural poses below have a stable
	# neutral pose to offset from - reading these live later would pick up whatever mid-cycle
	# frame the last-playing clip happened to leave them at.
	_foot_r_target = leg_targets.get_node("FootR Target")
	_foot_l_target = leg_targets.get_node("FootL Target")
	_foot_r_lookat = _foot_r_target.get_node("Foot Lookat")
	_foot_l_lookat = _foot_l_target.get_node("Foot Lookat")
	_hip_rest_position = hip.position
	_body_rest_position = body.position
	_foot_r_target_rest = _foot_r_target.transform
	_foot_l_target_rest = _foot_l_target.transform
	_foot_r_lookat_rest = _foot_r_lookat.transform
	_foot_l_lookat_rest = _foot_l_lookat.transform
	_leg_r_bone_rest_position = leg_r_ik.joint_one_bone_node.position
	_leg_l_bone_rest_position = leg_l_ik.joint_one_bone_node.position
	_leg_r_bone_rest_scale = leg_r_ik.joint_one_bone_node.scale
	_leg_l_bone_rest_scale = leg_l_ik.joint_one_bone_node.scale

	# Duplicated so shrinking it at runtime doesn't mutate the shared CapsuleShape2D resource
	# every instance of this scene would otherwise point at.
	collision_shape.shape = collision_shape.shape.duplicate()
	_collision_shape_rest_height = collision_shape.shape.height
	_collision_shape_rest_position = collision_shape.position
	_hurtbox_collision_shape_rest_position = hurtbox_collision_shape.position

	# Captured here, before apply_crouch_collision() ever runs, so this copy is frozen at full
	# standing height regardless of what collision_shape's own shape gets shrunk to later.
	_stand_test_shape = collision_shape.shape.duplicate()


func _physics_process(delta : float) -> void:
	update_facing()

	var is_crouching : bool = get_is_crouching()

	var state_name : String = state_machine.current_node_state.name.to_lower()
	match state_name:
		"dead":
			# Plays once (non-looping clip) and then holds its final frame - play_clip()'s
			# current_animation guard means this only actually triggers .play() on the first frame
			# of the state, so the collapse isn't restarted every subsequent frame.
			play_clip("death", 1.0, delta)
		"hurt":
			animation_player.stop()
			apply_hurt_pose()
		"grapple":
			animation_player.stop()
			apply_grapple_pose()
		"dash":
			animation_player.stop()
			apply_dash_pose()
		_:
			play_normal_clip(delta)
			# Only meaningful for the normal (grounded movement/idle) branch - dash/hurt/grapple/dead
			# all have their own Hip handling above and were never crouch-able to begin with.
			apply_crouch_pose(is_crouching)

	# Runs after every branch above, clip-based or procedural, so Torso tracks whatever Hip ended
	# up doing this frame without needing its own track/logic per state.
	body.position = _body_rest_position + (hip.position - _hip_rest_position)

	apply_crouch_collision(is_crouching)


func play_normal_clip(delta : float) -> void:
	var direction : float = GameInputEvents.movement_input()
	var grounded : bool = character_body_2d.is_on_floor()

	if not grounded and character_body_2d.velocity.y < 0.0:
		play_clip("jump", 1.0, delta)
	elif not grounded:
		play_clip("fall", 1.0, delta)
	elif direction != 0.0:
		var speed_ratio : float = clampf(absf(character_body_2d.velocity.x) / walk_speed_reference, min_walk_speed_scale, 1.0)
		# Captured before advance() moves the clip forward - play_clip() resets position to 0 on
		# the frame "walk" starts (was some other clip last frame), which is the correct "before"
		# time to compare against for that frame too.
		var before_time : float = animation_player.current_animation_position if _current_clip_name == "walk" else 0.0
		play_clip("walk", speed_ratio, delta)
		_check_footsteps(before_time, animation_player.current_animation_position)
	else:
		play_clip("idle", 1.0, delta)


# AnimationPlayer is driven manually (see player.tscn's callback_mode_process = MANUAL) instead of
# its usual automatic idle-process ticking, and advance() is what actually steps it forward - so
# this is the ONLY thing writing to Hip/FootTargets/etc. for clip-based poses, at a fully
# predictable point in physics-process, once per physics frame. Without this, AnimationPlayer's
# own automatic per-idle-frame update would race code elsewhere in this file that also writes to
# Hip (apply_crouch_pose() below) - confirmed as the actual cause of a reported crouch "spasm":
# Hip visibly alternated between its crouched and un-crouched value frame to frame, since the two
# writers weren't ordered relative to each other.
#
# Guards on _current_clip_name (tracked here) rather than animation_player.current_animation,
# because advance() pushing a non-looping clip (death) past its own length clears
# current_animation to "" and is_playing() to false immediately, in the same call - automatic
# idle-process ticking just holds the final frame instead, so this difference only shows up once
# driven manually. Guarding on the engine's own current_animation looked identical to guarding on
# a locally-tracked name for every clip except that one, which is exactly why this didn't show up
# testing crouch (idle/walk/jump/fall never actually finish) - death alone would replay from frame
# 0 in an infinite loop the instant it reached its last frame, since "" != "death" re-triggers
# .play("death") right back at the guard.
var _current_clip_name : String = ""


func play_clip(clip_name : String, speed_scale : float, delta : float) -> void:
	if _current_clip_name != clip_name:
		animation_player.play(clip_name)
		_current_clip_name = clip_name
	animation_player.speed_scale = speed_scale
	animation_player.advance(delta)


# Ties footsteps to the walk clip's own timeline (scaled by speed_scale in play_normal_clip())
# rather than a fixed real-time interval, so a slow walk and a full sprint each get footsteps at
# the cadence the legs are actually moving at, for free.
func _check_footsteps(before_time : float, after_time : float) -> void:
	if footstep_player == null or footstep_sounds.is_empty():
		return
	var clip_length : float = animation_player.current_animation_length
	if clip_length <= 0.0:
		return
	for step_time in footstep_times:
		if _crossed_time(before_time, after_time, step_time):
			_play_footstep()


# True if playback advanced past step_time between two samples of the clip's position, including
# the case where it looped back to 0 in between (after_time < before_time).
func _crossed_time(before_time : float, after_time : float, step_time : float) -> bool:
	if after_time >= before_time:
		return before_time < step_time and after_time >= step_time
	return before_time < step_time or after_time >= step_time


func _play_footstep() -> void:
	footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_player.play()


# Legs mirror to face whichever way the character is actually moving. Falls back to velocity
# when there's no held input (e.g. during Dash, where movement is locked to dash_direction) and
# holds the last facing at a full stop, rather than snapping back to a default.
func update_facing() -> void:
	var direction : float = GameInputEvents.movement_input()
	if direction == 0.0 and absf(character_body_2d.velocity.x) > 1.0:
		direction = signf(character_body_2d.velocity.x)
	if direction != 0.0:
		facing = signf(direction)
	leg_targets.scale.x = facing
	leg_r_ik.joint_one_bone_node.position = Vector2(
		_leg_r_bone_rest_position.x * facing, _leg_r_bone_rest_position.y)
	leg_l_ik.joint_one_bone_node.position = Vector2(
		_leg_l_bone_rest_position.x * facing, _leg_l_bone_rest_position.y)
	leg_r_ik.joint_one_bone_node.scale = Vector2(
		_leg_r_bone_rest_scale.x * facing, _leg_r_bone_rest_scale.y)
	leg_l_ik.joint_one_bone_node.scale = Vector2(
		_leg_l_bone_rest_scale.x * facing, _leg_l_bone_rest_scale.y)
	# Keep the authored bend solution constant; SoupIK's determinant handling supplies the
	# mirrored bend when the leg branch has a negative horizontal scale.
	leg_r_ik.flip_bend_direction = true
	leg_l_ik.flip_bend_direction = true

	# The mirrored Bone2D branches already mirror their child textures and offsets. Applying
	# flip_h here as well would mirror the shin and foot artwork twice.
	for i in _leg_sprites.size():
		_leg_sprites[i].flip_h = false
		_leg_sprites[i].offset = _leg_sprite_rest_offsets[i]


# Lunge/skate silhouette that peaks mid-dash and eases back to neutral by the end, so it blends
# into whatever play_normal_clip() picks next instead of cutting off abruptly.
func apply_dash_pose() -> void:
	var progress : float = 1.0 - clampf(dash_state.dash_timer / dash_state.dash_duration, 0.0, 1.0)
	var pose_weight : float = sin(progress * PI)

	hip.position = _hip_rest_position + Vector2(-facing * dash_hip_pushback, dash_hip_drop) * pose_weight
	_set_leg_target(_foot_r_target, _foot_r_target_rest,
		Vector2(-dash_back_leg_extend, 0.0) * pose_weight, deg_to_rad(dash_back_leg_kick_degrees) * pose_weight)
	_set_leg_target(_foot_l_target, _foot_l_target_rest,
		Vector2(dash_front_leg_tuck, -2.0) * pose_weight, deg_to_rad(dash_front_leg_kick_degrees) * pose_weight)
	_reset_foot_lookats()


# Same ease shape as dash, driven by hurt_duration instead - a quick flinch/stagger rather than a
# dedicated hand-authored pose. Both legs kick the same way (a stumble, not a stride).
func apply_hurt_pose() -> void:
	var progress : float = 1.0 - clampf(hurt_state.hurt_timer / hurt_state.hurt_duration, 0.0, 1.0)
	var pose_weight : float = sin(progress * PI)

	hip.position = _hip_rest_position + Vector2(-facing * hurt_hip_kick, -hurt_hip_kick * 0.5) * pose_weight
	var stagger : Vector2 = Vector2(-hurt_leg_stagger, 0.0) * pose_weight
	var kick : float = deg_to_rad(hurt_leg_kick_degrees) * pose_weight
	_set_leg_target(_foot_r_target, _foot_r_target_rest, stagger, kick)
	_set_leg_target(_foot_l_target, _foot_l_target_rest, stagger, kick)
	_reset_foot_lookats()


# Legs trail behind the swing, angled by how fast the player is actually moving - reuses facing's
# own velocity-based fallback (see update_facing()) rather than re-deriving swing tangent/anchor
# math that grapple_state.gd already owns. Climbing (rope length changing) eases to a tucked hang
# instead of a wide trail.
func apply_grapple_pose() -> void:
	if GameInputEvents.climb_input() != 0.0:
		var tuck : Vector2 = Vector2(0.0, -grapple_climb_tuck)
		hip.position = _hip_rest_position + Vector2(0.0, -grapple_climb_tuck * 0.5)
		_set_leg_target(_foot_r_target, _foot_r_target_rest, tuck, 0.0)
		_set_leg_target(_foot_l_target, _foot_l_target_rest, tuck, 0.0)
	else:
		var swing_ratio : float = clampf(absf(character_body_2d.velocity.x) / grapple_swing_reference_speed, 0.0, 1.0)
		hip.position = _hip_rest_position + Vector2(-facing, 2.0) * swing_ratio
		var trail : Vector2 = Vector2(-grapple_trail_distance, 3.0) * swing_ratio
		var kick : float = deg_to_rad(grapple_trail_kick_degrees) * swing_ratio
		_set_leg_target(_foot_r_target, _foot_r_target_rest, trail, kick)
		_set_leg_target(_foot_l_target, _foot_l_target_rest, trail, kick)
	_reset_foot_lookats()


func _set_leg_target(target : Node2D, rest : Transform2D, offset : Vector2, rotation_offset : float) -> void:
	target.position = rest.origin + offset
	target.rotation = rest.get_rotation() + rotation_offset


# Foot Lookat isn't driven by any of the poses above - held at its captured rest transform so it
# doesn't drift from whatever mid-cycle frame the last-playing clip left it at (see _ready()).
func _reset_foot_lookats() -> void:
	_foot_r_lookat.transform = _foot_r_lookat_rest
	_foot_l_lookat.transform = _foot_l_lookat_rest


# Nudges Hip down on top of whatever idle/walk just set it to (see play_normal_clip(), called
# right before this every frame) rather than replacing it outright. Safe from accumulating only
# because play_clip()'s advance() call above freshly re-evaluates idle/walk's own curve into Hip
# every single physics frame before this runs - relying on that ordering is exactly what broke
# once AnimationPlayer's update and this addition weren't both happening deterministically inside
# the same function call chain (see the manual-advance comment on play_clip()).
func apply_crouch_pose(is_crouching : bool) -> void:
	if is_crouching:
		hip.position.y += crouch_hip_drop


# Resolves and caches whether the player is (or remains) crouched, once per physics frame -
# memoized on the frame number rather than recomputed unconditionally, because normal_state.gd
# (StateMachine, a sibling node) also calls this for its own crouch-speed scaling, and sibling
# nodes' _physics_process order isn't something to depend on: whichever of the two runs first in a
# given tick resolves and caches the value here, so the other reads back that same frame's result
# instead of the previous frame's.
#
# Grounded + crouch held, regardless of movement input, resolves true - deliberately NOT gated on
# standing still, so the hitbox actually shrinks while crouch-walking too, not just while
# stationary. Also stays true past crouch being released if _is_crouching was already true and
# there's no headroom to stand (_has_room_to_stand() only runs in that case, so a low ceiling can
# never be what forces a stand, only what forces continued crouching).
func get_is_crouching() -> bool:
	var current_frame := Engine.get_physics_frames()
	if current_frame == _crouch_resolved_physics_frame:
		return _is_crouching
	_crouch_resolved_physics_frame = current_frame
	_is_crouching = character_body_2d.is_on_floor() \
		and (GameInputEvents.crouch_input() or (_is_crouching and not _has_room_to_stand()))
	return _is_crouching


# Shrinks the ground-collision capsule from the top only (bottom edge stays put, feet don't sink
# into the floor) so crouching can actually fit under something shorter than standing height, not
# just look shorter. The hurtbox only translates, not shrinks, since the torso sprite itself
# doesn't compress when crouching (see the Torso-follows-Hip line above) - it just moves down with
# the rest of the upper body, so the hittable zone should move the same way, not change shape.
func apply_crouch_collision(is_crouching : bool) -> void:
	var shrink : float = crouch_collision_shrink if is_crouching else 0.0
	collision_shape.shape.height = _collision_shape_rest_height - shrink
	collision_shape.position = _collision_shape_rest_position + Vector2(0.0, shrink * 0.5)
	hurtbox_collision_shape.position = _hurtbox_collision_shape_rest_position + Vector2(0.0, shrink)


# Probes with the full-height capsule at its rest position/size (not collision_shape's own,
# currently-shrunk copy) to see if standing back up would immediately overlap something solid.
# Only called while _is_crouching is already true and crouch was just released (see the call site
# in _physics_process()), so this never runs on every grounded frame - just the one moment a stand
# attempt needs to be judged.
func _has_room_to_stand() -> bool:
	var space_state := character_body_2d.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _stand_test_shape
	query.transform = Transform2D(0.0, character_body_2d.global_position + _collision_shape_rest_position)
	# Excludes the one-way-platform bit regardless of its current toggle state (see
	# ONE_WAY_PLATFORM_LAYER's declaration above) - a one-way platform should never be the thing
	# keeping the player crouched.
	query.collision_mask = character_body_2d.collision_mask & ~(1 << (ONE_WAY_PLATFORM_LAYER - 1))
	query.exclude = [character_body_2d.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_shape(query, 1).is_empty()

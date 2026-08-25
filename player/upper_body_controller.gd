extends Node

# Everything above the hip: arms and head continuously aim at the mouse/stick and kick back
# when the gun fires. Runs independently of lower_body_controller.gd's keyframed walk cycle,
# since aim direction is live input and can't be pre-baked into a clip.

@export var character_body_2d : CharacterBody2D
@export var state_machine : NodeFiniteStateMachine
@export var gun : Node2D
@export var head_target : Node2D
@export var arm_r_target : Node2D
@export var arm_l_target : Node2D
@export var body : Node2D
@export var head_sprite : Sprite2D
# Read-only here - lower_body_controller.gd owns crouch/dash/hurt/grapple's Hip offsets. Without
# this, arm/head targets (and anything anchored off them, like Gun.gd's muzzle and the aim
# reticle) stay at a fixed height while the rest of the body visibly moves with Hip, since none of
# them were ever computed relative to Hip's current position - only their own fixed origins.
@export var hip : Bone2D

# Each target tracks aim direction as origin + aim_dir * radius. Defaults are approximated from
# the targets' original rest positions in player.tscn - first-pass values, meant to be tuned in
# the Inspector rather than exact anatomy.
@export_category("Head")
# aim_dir (below) is measured from character_body_2d's origin, near the feet - but the head bone
# sits ~19px higher, near actual head height. Since the head is a single rigid bone (no elbow-like
# joint to flex and hide the difference), leaving this at the feet instead of the head's own
# height turns that gap into a real, noticeable angle: the head visibly doesn't point at the
# cursor. (10, -18) matches Head Target's original rest position in player.tscn, right at head
# height.
@export var head_origin : Vector2 = Vector2(10, -18)
@export var head_radius : float = 27.0
# How far the head is allowed to turn away from whichever way the body currently faces, before
# it clamps rather than keeps rotating - keeps it from spinning past what a neck can actually do.
@export var head_max_turn_degrees : float = 60.0

@export_category("Right Arm (trigger hand)")
# Centered on the ArmR shoulder bone's own local position (relative to Hip), not the player's core
# origin - that keeps the hand target exactly arm_r_radius away from the actual shoulder no matter
# which way aim_dir points. With origin at ZERO, the target-to-shoulder distance swung wildly with
# aim angle instead (shoulder sits ~19px off the core origin already) and could collapse to just a
# few pixels, well inside what a 2-bone chain can hold stably - CCDIK had no good solution and kept
# flipping between wildly different elbow bends, which read as the arm snapping around at random.
@export var arm_r_origin : Vector2 = Vector2(-7, -18)
@export var arm_r_radius : float = 20.0

@export_category("Left Arm (support hand)")
# Same reasoning as arm_r_origin above, centered on the ArmL shoulder bone's own local position.
@export var arm_l_origin : Vector2 = Vector2(5, -17)
@export var arm_l_radius : float = 20.0

@export_category("Recoil")
@export var recoil_kick_distance : float = 6.0
@export var recoil_recovery_speed : float = 40.0

var recoil_offset : Vector2 = Vector2.ZERO
var body_facing : float = 1.0
var head_sprite_rest_position : Vector2
var hip_rest_position : Vector2


func _ready() -> void:
	gun.shot_fired.connect(_on_gun_shot_fired)
	# head_sprite.position (set in player.tscn) nudges the head texture off the Head bone's
	# origin to line it up with the neck - tuned by eye for the unflipped, right-facing pose. It
	# doesn't get touched by flip_h (that only mirrors the rendered texture, not the node's own
	# transform), so left uncorrected it drags that same rightward nudge along on the left side too.
	head_sprite_rest_position = head_sprite.position
	hip_rest_position = hip.position


func _process(delta : float) -> void:
	if state_machine.current_node_state.name.to_lower() == "dead":
		return

	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_recovery_speed * delta)

	var aim_dir : Vector2 = GameInputEvents.aim_input(character_body_2d.global_position)
	var max_turn : float = deg_to_rad(head_max_turn_degrees)

	# body_facing only flips once aim moves far enough that the CURRENT facing's head-turn cone
	# can no longer reach it - the character turns its head first, and only turns its whole body
	# around once looking further than that requires it. Re-deriving facing straight from
	# aim_dir's sign every frame (the previous version of this) made the cone chase aim_dir
	# exactly, which trivially "satisfied" any clamp and let the head reach all 360 degrees -
	# the reference angle has to be a stable value that persists across frames instead.
	var facing_angle : float = 0.0 if body_facing >= 0.0 else PI
	var offset : float = wrapf(aim_dir.angle() - facing_angle, -PI, PI)
	if absf(offset) > max_turn:
		body_facing = signf(aim_dir.x) if aim_dir.x != 0.0 else -body_facing
		facing_angle = 0.0 if body_facing >= 0.0 else PI
		offset = wrapf(aim_dir.angle() - facing_angle, -PI, PI)

	# Only the flat, boneless sprites (torso + head) flip here - the arm bone chains stay
	# unmirrored since their CCDIK joint constraints are defined in local bone space and were
	# tuned assuming a rightward-facing rig; mirroring that parent via negative scale would flip
	# which rotation direction those constraints allow and make the limbs bend wrong. The arms
	# already reach any aim direction correctly without mirroring, since their IK targets are
	# absolute positions.
	body.scale.x = body_facing
	head_sprite.flip_h = body_facing < 0.0
	head_sprite.position.x = head_sprite_rest_position.x * body_facing

	var head_dir : Vector2 = Vector2.from_angle(facing_angle + clampf(offset, -max_turn, max_turn))

	# head_sprite.flip_h (above) mirrors the drawn texture across its local vertical axis, but the
	# CCDIK bone underneath still rotates toward head_target in ordinary, unflipped space. Since
	# this rig's bones point along local +X at rest, mirroring the texture on top of that rotation
	# adds a flat 180° to whatever direction is actually rendered - so on the left side the target
	# has to be placed at the negated (mirrored) offset to cancel that out and still visually land
	# on head_dir. Left unmirrored, this is what made the head visually point opposite its aim
	# whenever the body faced left.
	var head_offset : Vector2 = head_dir * head_radius + recoil_offset * 0.3
	if body_facing < 0.0:
		head_offset = -head_offset

	# Whatever lower_body_controller.gd did to Hip this frame (crouch, dash lean, hurt kick,
	# grapple sway) - added on top so the arms/head/gun/reticle move with the rest of the body
	# instead of staying pinned at standing height.
	var hip_offset : Vector2 = hip.position - hip_rest_position

	head_target.position = head_origin + head_offset + hip_offset
	arm_r_target.position = arm_r_origin + aim_dir * arm_r_radius + recoil_offset + hip_offset
	arm_l_target.position = arm_l_origin + aim_dir * arm_l_radius + recoil_offset + hip_offset


func _on_gun_shot_fired() -> void:
	var aim_dir : Vector2 = GameInputEvents.aim_input(character_body_2d.global_position)
	recoil_offset = -aim_dir * recoil_kick_distance

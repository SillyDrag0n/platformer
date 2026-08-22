extends NodeState

@export var character_body_2d : CharacterBody2D
@export var grapple_hook : Node2D

@export_category("Grapple State")
@export var gravity : float = 700.0
@export var swing_force : float = 800.0
@export var max_swing_speed : float = 400.0
@export var pump_sustain_time : float = 0.3
@export var climb_speed : float = 150.0
@export var min_rope_length : float = 40.0
@export var release_jump_boost : float = 150.0

@export_category("Rope Climbing")
@export var swing_damping : float = 3.0
@export var max_climb_horizontal_speed : float = 10.0

var anchor : Node2D
var rope_length : float
var max_rope_length : float
var pump_direction : float = 0.0
var pump_time : float = 0.0


func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	if not is_instance_valid(anchor):
		transition.emit("Normal")
		return

	var anchor_position : Vector2 = anchor.global_position
	var to_player : Vector2 = character_body_2d.global_position - anchor_position
	var radial_dir : Vector2 = to_player.normalized() if to_player.length() > 0.0 else Vector2.DOWN
	var tangent_dir : Vector2 = radial_dir.rotated(-PI / 2.0)

	var velocity : Vector2 = character_body_2d.velocity
	velocity.y += gravity * delta

	# swinging: holding a direction only pumps for pump_sustain_time before running out, so a
	# single held key can only add a small, bounded amount of momentum. Building up real speed
	# requires releasing and switching sides to trigger a fresh pump, like actually swinging
	# left and right, instead of one held key rocketing the player up on its own.
	var direction : float = GameInputEvents.movement_input()
	if direction != 0.0:
		if sign(direction) != sign(pump_direction):
			pump_direction = direction
			pump_time = 0.0

		if pump_time < pump_sustain_time:
			velocity += tangent_dir * direction * swing_force * delta
			pump_time += delta
	else:
		pump_direction = 0.0
		pump_time = 0.0

	# cap the overall swing speed, whether it came from input or gravity picking up speed
	# on a long rope, so swinging never runs away
	var swing_speed : float = velocity.dot(tangent_dir)
	var clamped_swing_speed : float = clamp(swing_speed, -max_swing_speed, max_swing_speed)
	velocity += tangent_dir * (clamped_swing_speed - swing_speed)

	# climbing the rope: only changes its length once horizontal velocity is (almost) zero -
	# i.e. the swing has actually stopped moving sideways, not merely passing through a
	# vertical angle while still swinging fast. Otherwise, holding up/down damps the swing so
	# gravity settles it back toward vertical instead of locking the player in place.
	var climb : float = GameInputEvents.climb_input()
	if climb != 0.0:
		if abs(velocity.x) <= max_climb_horizontal_speed:
			rope_length = clamp(rope_length - climb * climb_speed * delta, min_rope_length, max_rope_length)
		else:
			var tangential_speed : float = velocity.dot(tangent_dir)
			var damped_speed : float = tangential_speed * exp(-swing_damping * delta)
			velocity += tangent_dir * (damped_speed - tangential_speed)

	# constrain the player to the rope length (position-based pendulum)
	var current_position : Vector2 = character_body_2d.global_position
	var predicted_position : Vector2 = current_position + velocity * delta
	var to_predicted : Vector2 = predicted_position - anchor_position
	if to_predicted.length() > 0.0:
		to_predicted = to_predicted.normalized() * rope_length
	var corrected_position : Vector2 = anchor_position + to_predicted

	character_body_2d.velocity = (corrected_position - current_position) / delta
	character_body_2d.move_and_slide()

	grapple_hook.update_rope_visual(anchor_position, character_body_2d.global_position)

	# transitioning states

	# jump releases the hook and keeps the swing momentum, plus a small upward boost
	if GameInputEvents.jump_input():
		character_body_2d.velocity.y -= release_jump_boost
		transition.emit("Normal")
		return

	# pressing grapple again lets go without a boost
	if GameInputEvents.grapple_input():
		transition.emit("Normal")
		return

	# landed on the ground while swinging
	if character_body_2d.is_on_floor():
		transition.emit("Normal")


func enter():
	anchor = grapple_hook.find_anchor(character_body_2d.global_position)
	if not is_instance_valid(anchor):
		return

	max_rope_length = grapple_hook.max_distance
	rope_length = clamp(character_body_2d.global_position.distance_to(anchor.global_position), min_rope_length, max_rope_length)
	pump_direction = 0.0
	pump_time = 0.0


func exit():
	anchor = null
	grapple_hook.hide_rope()

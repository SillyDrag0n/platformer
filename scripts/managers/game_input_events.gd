extends Node

# Fixed deadzone so a stick that isn't perfectly centered doesn't register as input on its own.
# Not sensitivity-dependent - a raw angle is so sensitive near dead center that tying deadzone
# size to "sensitivity" barely changed anything (a normal aiming push clears either extreme of
# that range immediately, so the slider only ever touched the imperceptible center wobble).
const AIM_DEADZONE := 0.2

# How fast last_aim_direction turns to follow the stick, in radians/second. This is what the
# "Aim Sensitivity" setting actually controls: low sensitivity turns slowly (aim lags behind a
# quick flick, feels heavy), high sensitivity turns almost instantly.
const AIM_TURN_SPEED_MIN := 5.0
const AIM_TURN_SPEED_MAX := 50.0

# 0 = least sensitive, 1 = most sensitive. Set by SettingsManager from the saved settings.
static var aim_sensitivity : float = 0.5

# Which device last produced aim-relevant input, so aim_input() knows whether to read the
# right stick or the mouse. Sticks self-center, so we also keep the last non-zero direction
# around to hold the reticle/aim steady while the stick is neutral instead of it snapping
# back to wherever the (possibly hidden/stale) mouse position is.
static var controller_active : bool = false
static var last_aim_direction : Vector2 = Vector2.RIGHT


# Player-action reads all go through here, so gating them in one place freezes movement,
# shooting, and every other player action while the inventory is open. inventory_input()
# itself is deliberately NOT gated, otherwise the menu could never be closed again.
static func is_input_locked() -> bool:
	return InventoryManager.is_open


func _input(event : InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		controller_active = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		controller_active = false


# Turns last_aim_direction toward the stick's current angle at a sensitivity-controlled rate.
# Runs exactly once per frame here (rather than inside aim_input(), which can be called several
# times a frame by different callers) so the turn rate stays correct regardless of how many
# places query the aim direction on a given frame.
func _process(delta : float) -> void:
	if is_input_locked() or not controller_active:
		return

	var stick : Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", AIM_DEADZONE)
	if stick.length() == 0.0:
		return

	var turn_speed := lerpf(AIM_TURN_SPEED_MIN, AIM_TURN_SPEED_MAX, clampf(aim_sensitivity, 0.0, 1.0))
	var new_angle := rotate_toward(last_aim_direction.angle(), stick.angle(), turn_speed * delta)
	last_aim_direction = Vector2.from_angle(new_angle)


# Movement (left stick / A-D) and aiming (right stick / mouse) are read independently, so the
# player can move and aim in different directions at the same time. `from_global` is only used
# for the mouse fallback (aim direction = mouse position relative to that point) - controller
# aim is a pure direction and ignores it entirely.
func aim_input(from_global : Vector2) -> Vector2:
	if is_input_locked():
		return last_aim_direction

	if controller_active:
		return last_aim_direction

	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return last_aim_direction
	var to_mouse : Vector2 = camera.get_global_mouse_position() - from_global
	if to_mouse.length() > 0.0:
		last_aim_direction = to_mouse.normalized()
	return last_aim_direction


static func movement_input() -> float:
	if is_input_locked():
		return 0.0
	var direction : float = Input.get_axis("move_left", "move_right")
	return direction


static func jump_input() -> bool:
	if is_input_locked():
		return false
	var jump_input : bool = Input.is_action_just_pressed("jump")
	return jump_input


static func shoot_input() -> bool:
	if is_input_locked():
		return false
	var shoot_input : bool = Input.is_action_pressed("shoot")
	return shoot_input


static func crouch_input() -> bool:
	if is_input_locked():
		return false
	var crouch_input : bool = Input.is_action_just_pressed("crouch")
	return crouch_input


static func fall_input() -> bool:
	if is_input_locked():
		return false
	var fall_input : bool = Input.is_action_just_pressed("force_fall")
	return fall_input


static func wall_cling_input() -> bool:
	if is_input_locked():
		return false
	var wall_cling_input : bool = Input.is_action_pressed("wall_cling")
	return wall_cling_input


static func reload_input() -> bool:
	if is_input_locked():
		return false
	var reload_input : bool = Input.is_action_just_pressed("reload")
	return reload_input


static func swap_weapon_input() -> bool:
	if is_input_locked():
		return false
	var swap_weapon_input : bool = Input.is_action_just_pressed("swap_weapon")
	return swap_weapon_input


static func inventory_input() -> bool:
	var inventory_input : bool = Input.is_action_just_pressed("inventory")
	return inventory_input


static func grapple_input() -> bool:
	if is_input_locked():
		return false
	var grapple_input : bool = Input.is_action_just_pressed("grapple")
	return grapple_input


static func climb_input() -> float:
	if is_input_locked():
		return 0.0
	var climb_input : float = Input.get_axis("force_fall", "climb_up")
	return climb_input


static func dash_input() -> bool:
	if is_input_locked():
		return false
	var dash_input : bool = Input.is_action_just_pressed("dash")
	return dash_input


static func deadeye_input() -> bool:
	if is_input_locked():
		return false
	var deadeye_input : bool = Input.is_action_pressed("deadeye")
	return deadeye_input

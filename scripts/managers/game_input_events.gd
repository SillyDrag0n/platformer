extends Node


# Player-action reads all go through here, so gating them in one place freezes movement,
# shooting, and every other player action while the inventory is open. inventory_input()
# itself is deliberately NOT gated, otherwise the menu could never be closed again.
static func is_input_locked() -> bool:
	return InventoryManager.is_open


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

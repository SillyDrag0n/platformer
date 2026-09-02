extends Node2D

signal shot_fired
# Emitted whenever the round count in the loaded weapon changes - a shot, a finished reload, or a
# swap to a weapon with a different magazine. The HUD's ammo readout (ui/ammo_display) listens for
# this instead of polling magazine_current every frame.
signal magazine_changed(current : int, capacity : int)

var bullet = preload("res://player/gun/bullet/bullet.tscn")
var muzzle_flash_effect = preload("res://player/gun/muzzle_flash_effect.tscn")

@export var default_weapon : WeaponItemData
@export var default_ammo : AmmoItemData

# The hand's IK target (upper_body_controller.gd's arm_r_target) - the muzzle tracks it directly
# each frame rather than rotating around Gun's own fixed pivot, so bullets spawn from the front of
# the hand the player actually sees instead of a separately-tuned circle that drifted from it.
@export var arm_r_target : Node2D
# Where the barrel tip sits relative to the grip (grip_point below), in the same unrotated local
# space as weapon_sprite.offset - x is forward along the aim direction, y is the perpendicular
# correction (negative = up when aiming right) for how far the tip sits off that straight line.
@export var muzzle_local_offset : Vector2 = Vector2(8.0, -2.0)
# ReloadUi is top_level (see player.tscn) so it doesn't spin along with Gun's rotation below -
# this is its fixed position relative to Gun's own (non-rotating) origin.
@export var reload_ui_offset : Vector2 = Vector2(-25.0, -75.0)

# --- Active reload (see WeaponUpgradeItemData, sold as the revolver's speed loader) ---
# Where the sweet spot is allowed to sit, as the same 1.0 -> 0.0 progress value the reload dial
# drains through. The dial fills clockwise from 12 o'clock, so 0.33 is 4 o'clock and 0.67 is 8
# o'clock: the bottom third of the ring, which the draining edge sweeps backwards through partway
# into every reload.
const ACTIVE_RELOAD_ZONE_START := 0.33
const ACTIVE_RELOAD_ZONE_END := 0.67

var active_slot : InventoryManager.WeaponSlot = InventoryManager.WeaponSlot.PRIMARY
var weapon : WeaponItemData
var ammo : AmmoItemData
var magazine_current : int

# This reload's sweet spot, covering progress values [start, start + width]. A width of 0 means
# none is armed - no upgrade fitted for the weapon in hand, or the window has already been used.
var _active_reload_window_start : float = 0.0
var _active_reload_window_width : float = 0.0
# One attempt per reload. Without this, mashing the reload key would walk into the window every
# single time and there would be no timing left to get right.
var _active_reload_spent : bool = false

@onready var muzzle = $Muzzle
@onready var weapon_sprite : Sprite2D = $Weapon
@onready var shoot_timer = $ShootTimer
@onready var reload_timer = $ReloadTimer
@onready var reload_ui = $ReloadUi
@onready var gun_shot_sound = $GunShot01
@onready var gun_reload_sound = $GunReload
@onready var gun_empty_sound = $GunEmpty
# The verdict on an active-reload attempt. Here with the rest of the gun's audio rather than in
# the reload dial, which stays purely visual - see player/gun/ui/gun_reload_ui.gd.
@onready var active_reload_hit_sound = $ActiveReloadHit
@onready var active_reload_miss_sound = $ActiveReloadMiss

@onready var player = get_parent()


func _ready():
	InventoryManager.equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	InventoryManager.equipped_ammo_changed.connect(_on_equipped_ammo_changed)
	InventoryManager.equipped_weapon_skin_changed.connect(_on_equipped_weapon_skin_changed)
	# Primary starts unequipped in InventoryManager itself - grant and equip the default weapon
	# there (rather than only falling back to it locally below) so InventoryManager stays the
	# accurate source of truth for what's equipped, matching what Gun.gd actually fires.
	if default_weapon != null and InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.PRIMARY) == null:
		InventoryManager.add_item(default_weapon)
		InventoryManager.equip_weapon(InventoryManager.WeaponSlot.PRIMARY, default_weapon)
	if default_ammo != null and InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.PRIMARY) == null:
		InventoryManager.add_item(default_ammo)
		InventoryManager.equip_ammo(InventoryManager.WeaponSlot.PRIMARY, default_ammo)
	_refresh_active_weapon()

func _process(_delta):
	# Recomputed first, before try_shoot(), so a bullet fired this frame spawns from this frame's
	# hand position rather than one left over from last frame.
	var aim_dir : Vector2 = GameInputEvents.aim_input(arm_r_target.global_position)
	weapon_sprite.global_position = arm_r_target.global_position
	# weapon_sprite.offset (tuned in the editor to seat the gun art in the hand) is in the sprite's
	# own local space, so it has to be rotated into world space by the current aim direction here -
	# muzzle/flash/bullets/aim reticle all derive their position from Muzzle below, so lining this
	# up keeps all of them seated on the gun art instead of the raw IK hand point.
	var grip_point : Vector2 = arm_r_target.global_position + weapon_sprite.offset.rotated(aim_dir.angle())
	muzzle.global_position = grip_point + muzzle_local_offset.rotated(aim_dir.angle())
	reload_ui.global_position = global_position + reload_ui_offset

	if GameInputEvents.reload_input():
		# With an active-reload window armed, a press during a running reload is the timing
		# attempt rather than a request to start over; without one this stays what it always was.
		if has_active_reload() and !reload_timer.is_stopped():
			_try_active_reload()
		else:
			reload()
	if GameInputEvents.swap_weapon_input():
		swap_weapon()
	if !reload_timer.is_stopped():
		reload_ui.set_value(reload_timer.time_left / reload_timer.wait_time)
	if player.is_shooting:
		try_shoot()

	# Points the gun sprite at the aim direction every frame, regardless of gameplay state -
	# matching how AimReticle already tracks aim unconditionally today. Gun's own transform no
	# longer drives the muzzle position (set above), so this is purely cosmetic now.
	rotation = aim_dir.angle()
	weapon_sprite.flip_v = aim_dir.x < 0.0

# --- Equipping ---
func swap_weapon():
	active_slot = InventoryManager.WeaponSlot.SECONDARY if active_slot == InventoryManager.WeaponSlot.PRIMARY else InventoryManager.WeaponSlot.PRIMARY
	_refresh_active_weapon()

# Resolves whichever weapon should currently be applied for active_slot, falling back to whichever
# slot still holds one (and from there to default_weapon) so the gun is never left without one -
# e.g. after swapping to an empty Secondary, or clearing a slot from the loadout screen. Ammo is
# refreshed alongside it since ammo is tracked per weapon slot and active_slot may change here.
func _refresh_active_weapon():
	var new_weapon = InventoryManager.get_equipped_weapon(active_slot)
	if new_weapon == null:
		# Falls through to whichever slot does hold something before default_weapon is reached
		# for. Either weapon slot can be cleared from the loadout screen now (as long as the other
		# is filled - see inventory_ui.gd's _open_weapon_picker), and jumping straight to the
		# default would arm a gun sitting in neither slot while the screen showed the one the
		# player actually left themselves.
		for fallback_slot in [InventoryManager.WeaponSlot.PRIMARY, InventoryManager.WeaponSlot.SECONDARY]:
			var slot_weapon = InventoryManager.get_equipped_weapon(fallback_slot)
			if slot_weapon != null:
				active_slot = fallback_slot
				new_weapon = slot_weapon
				break
	if new_weapon == null:
		# Nothing equipped anywhere - only reachable from a save that predates the rule above.
		active_slot = InventoryManager.WeaponSlot.PRIMARY
		new_weapon = default_weapon
	equip_weapon(new_weapon)
	_refresh_active_ammo()
	_refresh_weapon_skin()

func equip_weapon(new_weapon : WeaponItemData):
	if new_weapon == null:
		return
	weapon = new_weapon
	shoot_timer.wait_time = weapon.cooldown
	magazine_current = weapon.magazine_size
	magazine_changed.emit(magazine_current, weapon.magazine_size)


# Capacity of whatever is currently loaded, for anything drawing the magazine (see
# ui/ammo_display) - 0 rather than a crash in the window before a weapon is equipped.
func get_magazine_size() -> int:
	return weapon.magazine_size if weapon != null else 0

func _refresh_active_ammo():
	var new_ammo = InventoryManager.get_equipped_ammo(active_slot)
	ammo = new_ammo if new_ammo else default_ammo

# Weapon skins are equipped per-WeaponSlot rather than as a single global cosmetic slot, so this
# is resolved here (where active_slot already lives) instead of the generic cosmetics listener.
# Falls back to the weapon's own world_texture so the gun is visible even with no skin equipped.
func _refresh_weapon_skin():
	var skin : CosmeticItemData = InventoryManager.get_equipped_weapon_skin(active_slot)
	weapon_sprite.texture = skin.texture if skin else weapon.world_texture

func _on_equipped_weapon_changed(slot : InventoryManager.WeaponSlot, _new_weapon : WeaponItemData):
	if slot == active_slot:
		_refresh_active_weapon()

func _on_equipped_ammo_changed(slot : InventoryManager.WeaponSlot, _new_ammo : AmmoItemData):
	if slot == active_slot:
		_refresh_active_ammo()

func _on_equipped_weapon_skin_changed(slot : InventoryManager.WeaponSlot, _cosmetic : CosmeticItemData):
	if slot == active_slot:
		_refresh_weapon_skin()


# --- Fire attempt ---
func try_shoot() -> bool:
	if player.dynamite_thrower.held_dynamite != null:
		return false
	if shoot_timer.is_stopped() and reload_timer.is_stopped():
		if magazine_current > 0:
			magazine_current -= 1
			magazine_changed.emit(magazine_current, get_magazine_size())
			shoot()
			shoot_timer.start()
			if magazine_current == 0:
				reload()
			return true
		gun_empty_sound.play()
		return false
	return false

func shoot():
	var shootdirection : Vector2 = GameInputEvents.aim_input(muzzle.global_position)
	var pellet_count : int = max(weapon.pellet_count, 1)
	var spread_rad : float = deg_to_rad(weapon.spread_angle_degrees)

	for i in range(pellet_count):
		var angle_offset : float = 0.0
		if pellet_count > 1:
			angle_offset = lerp(-spread_rad / 2.0, spread_rad / 2.0, float(i) / float(pellet_count - 1))
		_fire_bullet(shootdirection.rotated(angle_offset))

	shot_fired.emit()
	gun_shot_sound.play()

	var flash_instance = muzzle_flash_effect.instantiate() as Node2D
	flash_instance.global_position = muzzle.global_position
	flash_instance.rotation = shootdirection.angle()
	ProjectileLayer.spawn(flash_instance)

func _fire_bullet(direction : Vector2):
	var bullet_instance = bullet.instantiate() as Node2D
	ProjectileLayer.spawn(bullet_instance)

	bullet_instance.direction = direction
	bullet_instance.rotation = direction.angle()
	bullet_instance.global_position = muzzle.global_position
	bullet_instance.speed = int(round(weapon.bullet_speed * (ammo.speed_modifier if ammo else 1.0)))
	bullet_instance.damage_amount = int(round(weapon.bullet_damage * (ammo.damage_modifier if ammo else 1.0)))

# Whether asking for a reload right now would do anything. Two ways it would not.
#
# A cylinder that is already full has nothing to put in it, and running the whole animation and
# dial to load six rounds into a gun holding six is just a way to waste the time.
#
# And a reload already under way must not be started over. reload() restarts the timer and builds
# the dial again from the top, so holding the reload key down kept the meter pinned near full and
# the empty click never came; with the speed loader fitted it also rerolled the sweet spot on
# every press, which turned a window the player had missed into one they could simply ask for
# again. try_shoot()'s own auto-reload on the last round is unaffected: the cylinder is empty and
# nothing is running by the time it gets here.
func can_reload() -> bool:
	return weapon != null and reload_timer.is_stopped() \
		and magazine_current < weapon.magazine_size


func reload():
	if not can_reload():
		return
	reload_timer.start()
	_arm_active_reload()
	reload_ui.begin(_active_reload_window_start, _active_reload_window_width)
	if !gun_reload_sound.playing:
		gun_reload_sound.play()

func _on_reload_timer_timeout() -> void:
	_finish_reload(false)

func _finish_reload(via_active_reload : bool) -> void:
	reload_timer.stop()
	_active_reload_window_width = 0.0
	magazine_current = weapon.magazine_size
	magazine_changed.emit(magazine_current, weapon.magazine_size)
	if via_active_reload:
		reload_ui.flash_window_hit()
		active_reload_hit_sound.play()
	else:
		reload_ui.finish()


# --- Active reload ---
# How wide a sweet spot the weapon in hand gets, as a fraction of its reload. Upgrades are simply
# owned items rather than something filling an equip slot (see WeaponUpgradeItemData), and each
# one names the weapon it was made for, so the revolver's speed loader does nothing while the
# shotgun is out.
func get_active_reload_window() -> float:
	if weapon == null:
		return 0.0
	for upgrade in InventoryManager.get_owned_items_by_type(WeaponUpgradeItemData):
		if upgrade.target_weapon == weapon:
			return upgrade.active_reload_window
	return 0.0

# Rolls a fresh position for the window on every reload, so the timing has to be read off the dial
# each time rather than memorised once. Clamped to the zone so a wide window can't spill out of
# the bottom of the ring into the part of the sweep the player never gets a look at.
func _arm_active_reload() -> void:
	_active_reload_spent = false
	_active_reload_window_width = clampf(get_active_reload_window(), 0.0, \
		ACTIVE_RELOAD_ZONE_END - ACTIVE_RELOAD_ZONE_START)
	_active_reload_window_start = randf_range(ACTIVE_RELOAD_ZONE_START, \
		ACTIVE_RELOAD_ZONE_END - _active_reload_window_width)

func has_active_reload() -> bool:
	return _active_reload_window_width > 0.0

func is_inside_active_reload_window(progress : float) -> bool:
	return has_active_reload() and progress >= _active_reload_window_start \
		and progress <= _active_reload_window_start + _active_reload_window_width

# Hitting the window finishes the reload on the spot. Missing it only costs the attempt - the
# reload still runs out its clock exactly as it would have, rather than being restarted or
# lengthened as a punishment.
func _try_active_reload() -> void:
	if _active_reload_spent:
		return
	_active_reload_spent = true
	if is_inside_active_reload_window(reload_timer.time_left / reload_timer.wait_time):
		_finish_reload(true)
	else:
		reload_ui.mark_window_missed()
		active_reload_miss_sound.play()

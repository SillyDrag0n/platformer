extends Resource
class_name SettingsDataResource

@export var window_mode : int = 0
@export var window_mode_index : int = 1
@export var resolution : Vector2i = Vector2i(1920, 1080)
@export var resolution_index : int = 6
@export var max_fps : int = 0
@export var max_fps_index : int = 0
@export var vsync_enabled : bool = true

# Bus name (String) -> linear volume 0..1, one entry per mixer track (see
# SettingsManager.VOLUME_BUSES). A dictionary rather than a field per bus so adding a category to
# the mixer doesn't mean touching this file, SettingsManager and the settings screen's save
# round-trip all at once. Missing entries read as full volume.
@export var bus_volumes : Dictionary = {}

# Superseded by bus_volumes above. Kept exported so a settings file written before the game had a
# mixer still parses, and migrated into the Master entry once on load - see
# SettingsManager._migrate_legacy_master_volume().
@export var master_volume : float = 1.0

@export var aim_sensitivity : float = 0.5
@export var ui_scale : float = 1.0
@export var language_code : String = "en"
@export var language_index : int = 0

# action name (String) -> InputEvent override, or `false` for an action explicitly left unbound
# (e.g. after its key was taken over by another rebound action). Actions with no entry here keep
# using project.godot's default binding.
@export var custom_bindings : Dictionary = {}

# Same idea as custom_bindings, but for the action's controller (joypad button) slot instead of
# its keyboard/mouse slot - the two are rebound independently.
@export var custom_joypad_bindings : Dictionary = {}

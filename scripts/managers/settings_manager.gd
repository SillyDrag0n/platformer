extends Node

var settings_data : SettingsDataResource

#		%APPDATA%\Godot\app_userdata\Chronobot\game_data
var save_settings_path = "user://game_data/"
var save_file_name = "settings_data.tres"

var available_languages : Array[String] = ["en", "de"]

# The mixer's tracks, in the order they appear on the settings screen, and the tags every sound in
# the game is routed through (see default_bus_layout.tres). Master scales the lot; the rest let a
# player turn the music down without losing the gunshots, or mute menu blips without muting the
# game. Adding a category means adding a bus to the layout and a name here - nothing else.
const VOLUME_BUSES : Array[StringName] = [&"Master", &"Music", &"SFX", &"UI"]

# Keyboard/mouse actions exposed for rebinding in the settings screen. Controller bindings (and
# the joypad-axis-only aim_* actions) are left alone - this only ever touches the InputEventKey /
# InputEventMouseButton slot of each of these actions.
const REBINDABLE_ACTIONS : Array[String] = [
	"move_left", "move_right", "jump", "shoot", "crouch", "force_fall", "wall_cling",
	"reload", "swap_weapon", "dash", "deadeye", "use_utility", "cycle_utility",
	"interact", "inventory", "grapple", "climb_up", "pause",
]

# Of the above, these are only ever bound to a joypad *axis* by default (stick/trigger motion),
# not a button - there's no single "press a button" gesture to rebind them to, so the Controls
# tab only offers a keyboard/mouse rebind for these and leaves their controller stick untouched.
const AXIS_ONLY_ACTIONS : Array[String] = [
	"move_left", "move_right", "force_fall", "swap_weapon", "deadeye", "climb_up",
]


func _ready() -> void:
	load_settings()


func load_settings():
	if !DirAccess.dir_exists_absolute(save_settings_path):
		DirAccess.make_dir_absolute(save_settings_path)
	
	if ResourceLoader.exists(save_settings_path + save_file_name):
		settings_data = ResourceLoader.load(save_settings_path + save_file_name)
	
	if settings_data == null:
		settings_data = SettingsDataResource.new()
	
	if settings_data != null:
		set_window_mode(settings_data.window_mode, settings_data.window_mode_index)
		set_resolution(settings_data.resolution, settings_data.resolution_index)
		set_max_fps(settings_data.max_fps, settings_data.max_fps_index)
		set_vsync_enabled(settings_data.vsync_enabled)
		_migrate_legacy_master_volume()
		_apply_bus_volumes()
		set_aim_sensitivity(settings_data.aim_sensitivity)
		set_ui_scale(settings_data.ui_scale)
		set_language(settings_data.language_code, settings_data.language_index)
		_apply_custom_bindings()


func set_window_mode(window_mode : int, window_mode_index : int):
	match window_mode:
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	settings_data.window_mode = window_mode
	settings_data.window_mode_index = window_mode_index


func set_resolution(resolution : Vector2i, resolution_index : int):
	DisplayServer.window_set_size(resolution)
	settings_data.resolution = resolution
	settings_data.resolution_index = resolution_index


func set_max_fps(max_fps : int, max_fps_index : int):
	Engine.max_fps = max_fps
	settings_data.max_fps = max_fps
	settings_data.max_fps_index = max_fps_index


func set_vsync_enabled(vsync_enabled : bool):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	settings_data.vsync_enabled = vsync_enabled


# Sets one mixer track's volume, 0..1. Unknown bus names are a warning rather than a crash: the
# names live in two places (VOLUME_BUSES and default_bus_layout.tres) and a layout that has lost a
# bus should cost the player that one slider, not the whole settings screen.
func set_bus_volume(bus_name : StringName, linear_volume : float) -> void:
	var volume : float = clampf(linear_volume, 0.0, 1.0)
	settings_data.bus_volumes[String(bus_name)] = volume

	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("SettingsManager: no '%s' audio bus - check default_bus_layout.tres." % bus_name)
		return
	# linear_to_db(0.0) is -inf, which the audio server won't take; the bottom of the slider has to
	# mean silence rather than an error.
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume) if volume > 0.0 else -80.0)


func get_bus_volume(bus_name : StringName) -> float:
	return settings_data.bus_volumes.get(String(bus_name), 1.0)


func _apply_bus_volumes() -> void:
	for bus_name in VOLUME_BUSES:
		set_bus_volume(bus_name, get_bus_volume(bus_name))


# A settings file written before the game had a mixer only knows about master_volume. Moved into
# the Master entry once, so a player who had turned the game down doesn't get it back at full
# volume the first time they launch a build with the mixer in it.
func _migrate_legacy_master_volume() -> void:
	if not settings_data.bus_volumes.has("Master"):
		settings_data.bus_volumes["Master"] = settings_data.master_volume


func set_aim_sensitivity(aim_sensitivity : float):
	GameInputEvents.aim_sensitivity = aim_sensitivity
	settings_data.aim_sensitivity = aim_sensitivity


func set_ui_scale(ui_scale : float) -> void:
	settings_data.ui_scale = ui_scale


# Scales an entire menu screen uniformly around the viewport's center, so bumping UI Scale makes
# it bigger without drifting off-center - CanvasLayer has no anchor/pivot system of its own like
# Control does, so the centering has to be done by hand via `offset` (the standard "scale around
# point P" formula: offset = P * (1 - scale) keeps P itself fixed under the transform). Call once
# from a screen's _ready(); the settings screen also calls it again on slider change for a live
# preview instead of needing a persistent signal connection (which would outlive short-lived
# popup screens like this one and Pause).
func apply_ui_scale(canvas_layer : CanvasLayer) -> void:
	var viewport_center : Vector2 = canvas_layer.get_viewport().get_visible_rect().size / 2.0
	var scale_value : float = settings_data.ui_scale
	canvas_layer.scale = Vector2(scale_value, scale_value)
	canvas_layer.offset = viewport_center * (1.0 - scale_value)


func set_language(language_code : String, language_index : int):
	TranslationServer.set_locale(language_code)
	settings_data.language_code = language_code
	settings_data.language_index = language_index


func get_settings() -> SettingsDataResource:
	return settings_data


# Human-readable label for whatever's currently bound to the action's keyboard/mouse slot, for
# display on the settings screen's rebind buttons.
func get_binding_display_text(action_name : String) -> String:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
		if event is InputEventMouseButton:
			return _mouse_button_display_name(event.button_index)
	return "Unbound"


func _mouse_button_display_name(button_index : int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT: return "Mouse Left"
		MOUSE_BUTTON_RIGHT: return "Mouse Right"
		MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
		_: return "Mouse %d" % button_index


func is_joypad_rebindable(action_name : String) -> bool:
	return not AXIS_ONLY_ACTIONS.has(action_name)


# Human-readable label for whatever's currently bound to the action's joypad button slot.
func get_joypad_binding_display_text(action_name : String) -> String:
	if not is_joypad_rebindable(action_name):
		return "-"
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return _joypad_button_display_name(event.button_index)
	return "Unbound"


func _joypad_button_display_name(button_index : int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A / Cross"
		JOY_BUTTON_B: return "B / Circle"
		JOY_BUTTON_X: return "X / Square"
		JOY_BUTTON_Y: return "Y / Triangle"
		JOY_BUTTON_BACK: return "Back / Select"
		JOY_BUTTON_GUIDE: return "Guide"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return "LB / L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB / R1"
		JOY_BUTTON_DPAD_UP: return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
		_: return "Button %d" % button_index


func _clear_joypad_binding(action_name : String) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventJoypadButton:
			InputMap.action_erase_event(action_name, existing_event)


# Only InputEventKey/InputEventMouseButton ever occupy this slot (see REBINDABLE_ACTIONS) -
# leaves any controller binding on the action untouched.
func _clear_primary_binding(action_name : String) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey or existing_event is InputEventMouseButton:
			InputMap.action_erase_event(action_name, existing_event)


func _same_binding(a : InputEvent, b : InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


# Rebinds action_name to event, and steals that same key/button away from any other rebindable
# action currently using it (left unbound rather than swapped, so two actions never silently
# share one key).
func rebind_action(action_name : String, event : InputEvent) -> void:
	for other_action in REBINDABLE_ACTIONS:
		if other_action == action_name:
			continue
		for other_event in InputMap.action_get_events(other_action):
			if _same_binding(other_event, event):
				InputMap.action_erase_event(other_action, other_event)
				settings_data.custom_bindings[other_action] = false

	_clear_primary_binding(action_name)
	InputMap.action_add_event(action_name, event)
	settings_data.custom_bindings[action_name] = event


# Same idea as rebind_action(), but for the controller button slot.
func rebind_action_joypad(action_name : String, event : InputEventJoypadButton) -> void:
	for other_action in REBINDABLE_ACTIONS:
		if other_action == action_name:
			continue
		for other_event in InputMap.action_get_events(other_action):
			if other_event is InputEventJoypadButton and other_event.button_index == event.button_index:
				InputMap.action_erase_event(other_action, other_event)
				settings_data.custom_joypad_bindings[other_action] = false

	_clear_joypad_binding(action_name)
	InputMap.action_add_event(action_name, event)
	settings_data.custom_joypad_bindings[action_name] = event


# Drops every custom binding (keyboard/mouse and controller) and restores project.godot's
# defaults for all actions.
func reset_bindings() -> void:
	settings_data.custom_bindings.clear()
	settings_data.custom_joypad_bindings.clear()
	InputMap.load_from_project_settings()


func _apply_custom_bindings() -> void:
	for action_name in settings_data.custom_bindings:
		if not InputMap.has_action(action_name):
			continue
		_clear_primary_binding(action_name)
		var override_event = settings_data.custom_bindings[action_name]
		if override_event is InputEvent:
			InputMap.action_add_event(action_name, override_event)

	for action_name in settings_data.custom_joypad_bindings:
		if not InputMap.has_action(action_name):
			continue
		_clear_joypad_binding(action_name)
		var override_joypad_event = settings_data.custom_joypad_bindings[action_name]
		if override_joypad_event is InputEvent:
			InputMap.action_add_event(action_name, override_joypad_event)


func save_settings():
	ResourceSaver.save(settings_data, save_settings_path + save_file_name)



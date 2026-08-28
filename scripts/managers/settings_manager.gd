extends Node

var settings_data : SettingsDataResource

#		%APPDATA%\Godot\app_userdata\Chronobot\game_data
var save_settings_path = "user://game_data/"
var save_file_name = "settings_data.tres"

var available_languages : Array[String] = ["en", "de"]

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
		set_master_volume(settings_data.master_volume)
		set_aim_sensitivity(settings_data.aim_sensitivity)
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


func set_master_volume(master_volume : float):
	var master_bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(master_volume))
	settings_data.master_volume = master_volume


func set_aim_sensitivity(aim_sensitivity : float):
	GameInputEvents.aim_sensitivity = aim_sensitivity
	settings_data.aim_sensitivity = aim_sensitivity


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



extends Node

var settings_data : SettingsDataResource

#		%APPDATA%\Godot\app_userdata\Chronobot\game_data
var save_settings_path = "user://game_data/"
var save_file_name = "settings_data.tres"

var available_languages : Array[String] = ["en", "de"]


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


func save_settings():
	ResourceSaver.save(settings_data, save_settings_path + save_file_name)



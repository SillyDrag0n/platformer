extends CanvasLayer

@onready var window_mode_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/WindowModeOptionButton
@onready var resolution_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ResolutionOptionButton
@onready var max_fps_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MaxFpsOptionButton
@onready var vsync_check_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/VSyncCheckButton
@onready var master_volume_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MasterVolumeSlider
@onready var aim_sensitivity_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/AimSensitivitySlider

var window_modes : Dictionary = {"Fullscreen" : DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
								 "Window" : DisplayServer.WINDOW_MODE_WINDOWED,
								 "Window Maximized" : DisplayServer.WINDOW_MODE_MAXIMIZED }

var resolutions : Dictionary = {"320x180" : Vector2i(320, 180),
								"480x270" : Vector2i(480, 270),
								"640x360" : Vector2i(640, 360),
								"854x480" : Vector2i(640, 360),
								"1280x720" : Vector2i(1280, 720)}

var max_fps_options : Dictionary = {"Unlimited" : 0,
									"30" : 30,
									"60" : 60,
									"120" : 120,
									"144" : 144,
									"240" : 240}


func _ready():
	for window_mode in window_modes:
		window_mode_option_button.add_item(window_mode)

	for resolution in resolutions:
		resolution_option_button.add_item(resolution)

	for max_fps_option in max_fps_options:
		max_fps_option_button.add_item(max_fps_option)

	initialise_controls()
	window_mode_option_button.grab_focus()


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu_button_pressed()
		get_viewport().set_input_as_handled()


func initialise_controls():
	SettingsManager.load_settings()
	var settings_data : SettingsDataResource = SettingsManager.get_settings()
	window_mode_option_button.selected = settings_data.window_mode_index
	resolution_option_button.selected = settings_data.resolution_index
	max_fps_option_button.selected = settings_data.max_fps_index
	vsync_check_button.button_pressed = settings_data.vsync_enabled
	master_volume_slider.value = settings_data.master_volume * 100.0
	aim_sensitivity_slider.value = settings_data.aim_sensitivity * 100.0


func _on_window_mode_option_button_item_selected(index):
	var window_mode = window_modes.get(window_mode_option_button.get_item_text(index)) as int
	SettingsManager.set_window_mode(window_mode, index)


func _on_resolution_option_button_item_selected(index):
	var resolution = resolutions.get(resolution_option_button.get_item_text(index)) as Vector2i
	SettingsManager.set_resolution(resolution, index)


func _on_max_fps_option_button_item_selected(index):
	var max_fps = max_fps_options.get(max_fps_option_button.get_item_text(index)) as int
	SettingsManager.set_max_fps(max_fps, index)


func _on_v_sync_check_button_toggled(toggled_on):
	SettingsManager.set_vsync_enabled(toggled_on)


func _on_master_volume_slider_value_changed(value):
	SettingsManager.set_master_volume(value / 100.0)


func _on_aim_sensitivity_slider_value_changed(value):
	SettingsManager.set_aim_sensitivity(value / 100.0)


func _on_main_menu_button_pressed():
	SettingsManager.save_settings()
	queue_free()

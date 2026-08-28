extends CanvasLayer

const ControlBindingRowScene = preload("res://ui/screens/control_binding_row.tscn")

@onready var window_mode_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/WindowModeOptionButton
@onready var resolution_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/ResolutionOptionButton
@onready var max_fps_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/MaxFpsOptionButton
@onready var vsync_check_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/VSyncCheckButton
@onready var master_volume_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/MasterVolumeSlider
@onready var aim_sensitivity_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/AimSensitivitySlider
@onready var ui_scale_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/UiScaleSlider
@onready var language_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/LanguageOptionButton
@onready var controls_list = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/VBoxContainer
@onready var reset_controls_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/VBoxContainer/ResetControlsButton

var window_modes : Dictionary = {"Fullscreen" : DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
								 "Window" : DisplayServer.WINDOW_MODE_WINDOWED,
								 "Window Maximized" : DisplayServer.WINDOW_MODE_MAXIMIZED }

var resolutions : Dictionary = {"320x180" : Vector2i(320, 180),
								"480x270" : Vector2i(480, 270),
								"640x360" : Vector2i(640, 360),
								"854x480" : Vector2i(854, 480),
								"1280x720" : Vector2i(1280, 720),
								"1600x900" : Vector2i(1600, 900),
								"1920x1080" : Vector2i(1920, 1080)}

var max_fps_options : Dictionary = {"Unlimited" : 0,
									"30" : 30,
									"60" : 60,
									"120" : 120,
									"144" : 144,
									"240" : 240}

# Language names are shown in their own language rather than translated,
# so "de" always reads "Deutsch" no matter which locale is active.
var language_display_names : Dictionary = {"en" : "English",
											"de" : "Deutsch"}


func _ready():
	for window_mode in window_modes:
		window_mode_option_button.add_item(window_mode)

	for resolution in resolutions:
		resolution_option_button.add_item(resolution)

	for max_fps_option in max_fps_options:
		max_fps_option_button.add_item(max_fps_option)

	for language_code in SettingsManager.available_languages:
		language_option_button.add_item(language_display_names[language_code])

	initialise_controls()
	_populate_control_bindings()
	SettingsManager.apply_ui_scale(self)
	window_mode_option_button.grab_focus()


func _unhandled_input(event : InputEvent) -> void:
	# A rebind row mid-capture should swallow Escape itself (to cancel listening) rather than
	# have it bubble up here and close the whole settings screen.
	if _is_any_control_row_listening():
		return
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
	ui_scale_slider.value = settings_data.ui_scale * 100.0
	language_option_button.selected = settings_data.language_index


func _populate_control_bindings() -> void:
	for action_name in SettingsManager.REBINDABLE_ACTIONS:
		var row = ControlBindingRowScene.instantiate()
		controls_list.add_child(row)
		controls_list.move_child(row, reset_controls_button.get_index())
		row.set_action(action_name, action_name.capitalize())
		row.rebind_requested.connect(_on_control_rebind_requested)


func _is_any_control_row_listening() -> bool:
	for row in controls_list.get_children():
		if row.has_method("is_currently_listening") and row.is_currently_listening():
			return true
	return false


func _on_control_rebind_requested(_action_name : String) -> void:
	for row in controls_list.get_children():
		if row.has_method("refresh"):
			row.refresh()


func _on_reset_controls_button_pressed() -> void:
	SettingsManager.reset_bindings()
	for row in controls_list.get_children():
		if row.has_method("refresh"):
			row.refresh()


func _on_window_mode_option_button_item_selected(index):
	var window_mode = window_modes.values()[index] as int
	SettingsManager.set_window_mode(window_mode, index)


func _on_resolution_option_button_item_selected(index):
	var resolution = resolutions.get(resolution_option_button.get_item_text(index)) as Vector2i
	SettingsManager.set_resolution(resolution, index)


func _on_max_fps_option_button_item_selected(index):
	var max_fps = max_fps_options.values()[index] as int
	SettingsManager.set_max_fps(max_fps, index)


func _on_v_sync_check_button_toggled(toggled_on):
	SettingsManager.set_vsync_enabled(toggled_on)


func _on_master_volume_slider_value_changed(value):
	SettingsManager.set_master_volume(value / 100.0)


func _on_aim_sensitivity_slider_value_changed(value):
	SettingsManager.set_aim_sensitivity(value / 100.0)


func _on_ui_scale_slider_value_changed(value):
	SettingsManager.set_ui_scale(value / 100.0)
	SettingsManager.apply_ui_scale(self)


func _on_language_option_button_item_selected(index):
	var language_code = SettingsManager.available_languages[index]
	SettingsManager.set_language(language_code, index)


func _on_main_menu_button_pressed():
	SettingsManager.save_settings()
	queue_free()

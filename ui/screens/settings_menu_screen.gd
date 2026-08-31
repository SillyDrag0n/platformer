extends CanvasLayer

const ControlBindingRowScene = preload("res://ui/screens/control_binding_row.tscn")

@onready var window_mode_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/WindowModeOptionButton
@onready var resolution_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/ResolutionOptionButton
@onready var max_fps_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/MaxFpsOptionButton
@onready var vsync_check_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/VSyncCheckButton
@onready var master_volume_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/MasterVolumeSlider
@onready var music_volume_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/MusicVolumeSlider
@onready var sfx_volume_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/SFXVolumeSlider
@onready var ui_volume_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/UIVolumeSlider
@onready var aim_sensitivity_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/AimSensitivitySlider
@onready var ui_scale_slider = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/UiScaleSlider
@onready var language_option_button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/General/LanguageOptionButton
@onready var tab_container : TabContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var controls_scroll_container = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls
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
	_connect_scroll_follow(reset_controls_button)
	SettingsManager.apply_ui_scale(self)
	_grab_default_focus()


func _process(_delta):
	if _is_any_control_row_listening():
		return
	if Input.is_action_just_pressed("tab_left"):
		_cycle_tab(-1)
	elif Input.is_action_just_pressed("tab_right"):
		_cycle_tab(1)


func _unhandled_input(event : InputEvent) -> void:
	# A rebind row mid-capture should swallow Escape itself (to cancel listening) rather than
	# have it bubble up here and close the whole settings screen.
	if _is_any_control_row_listening():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu_button_pressed()
		get_viewport().set_input_as_handled()


# TabContainer's built-in tab bar only takes keyboard/gamepad focus if the player navigates to
# it directly, which never happens here since default focus lands on the tab's content - so tab
# switching gets its own dedicated input, same as the inventory screen (see inventory_ui.gd).
func _cycle_tab(direction : int) -> void:
	var tab_count := tab_container.get_tab_count()
	if tab_count == 0:
		return
	tab_container.current_tab = wrapi(tab_container.current_tab + direction, 0, tab_count)
	_grab_default_focus.call_deferred()


# Focuses the first focusable control inside whichever tab is currently showing - called on
# open and on every tab switch, since the previously-focused control is very likely to be
# inside a now-hidden tab otherwise, leaving gamepad/keyboard navigation stuck.
func _grab_default_focus() -> void:
	var current_tab_control := tab_container.get_current_tab_control()
	if current_tab_control == null:
		return
	var focusable := _find_first_focusable(current_tab_control)
	if focusable:
		focusable.grab_focus()


func _find_first_focusable(node : Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_first_focusable(child)
		if found:
			return found
	return null


func initialise_controls():
	SettingsManager.load_settings()
	var settings_data : SettingsDataResource = SettingsManager.get_settings()
	window_mode_option_button.selected = settings_data.window_mode_index
	resolution_option_button.selected = settings_data.resolution_index
	max_fps_option_button.selected = settings_data.max_fps_index
	vsync_check_button.button_pressed = settings_data.vsync_enabled
	# One slider per mixer track (see SettingsManager.VOLUME_BUSES), all read back the same way.
	master_volume_slider.value = SettingsManager.get_bus_volume(&"Master") * 100.0
	music_volume_slider.value = SettingsManager.get_bus_volume(&"Music") * 100.0
	sfx_volume_slider.value = SettingsManager.get_bus_volume(&"SFX") * 100.0
	ui_volume_slider.value = SettingsManager.get_bus_volume(&"UI") * 100.0
	aim_sensitivity_slider.value = settings_data.aim_sensitivity * 100.0
	ui_scale_slider.value = settings_data.ui_scale * 100.0
	language_option_button.selected = settings_data.language_index


func _populate_control_bindings() -> void:
	var rows : Array = []
	for action_name in SettingsManager.REBINDABLE_ACTIONS:
		var row = ControlBindingRowScene.instantiate()
		controls_list.add_child(row)
		controls_list.move_child(row, reset_controls_button.get_index())
		row.set_action(action_name, action_name.capitalize())
		row.rebind_requested.connect(_on_control_rebind_requested)
		_connect_scroll_follow(row.bind_button)
		_connect_scroll_follow(row.joypad_bind_button)
		rows.append(row)
	_wire_control_row_focus_neighbors(rows)


# ScrollContainer does not scroll to a focused child on its own, so each focusable control below
# the fold has to ask it to explicitly once it is focused.
func _connect_scroll_follow(control : Control) -> void:
	control.focus_entered.connect(controls_scroll_container.ensure_control_visible.bind(control))


# The rows live in a ScrollContainer, so Godot's automatic (spatial) focus search can jump
# straight to MainMenuButton instead of the next row once that row is scrolled out of view -
# a not-yet-visible row is still farther away than MainMenuButton is. Chaining focus_neighbor_top/
# bottom explicitly keeps "down" moving through the list until the actual last row is reached,
# with _connect_scroll_follow() bringing each newly focused row into view along the way.
func _wire_control_row_focus_neighbors(rows : Array) -> void:
	for i in rows.size():
		var row = rows[i]
		var next_row = rows[i + 1] if i + 1 < rows.size() else null
		if next_row:
			row.bind_button.focus_neighbor_bottom = row.bind_button.get_path_to(next_row.bind_button)
			row.joypad_bind_button.focus_neighbor_bottom = row.joypad_bind_button.get_path_to(next_row.joypad_bind_button)
			next_row.bind_button.focus_neighbor_top = next_row.bind_button.get_path_to(row.bind_button)
			next_row.joypad_bind_button.focus_neighbor_top = next_row.joypad_bind_button.get_path_to(row.joypad_bind_button)
		else:
			row.bind_button.focus_neighbor_bottom = row.bind_button.get_path_to(reset_controls_button)
			row.joypad_bind_button.focus_neighbor_bottom = row.joypad_bind_button.get_path_to(reset_controls_button)
			reset_controls_button.focus_neighbor_top = reset_controls_button.get_path_to(row.bind_button)


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
	SettingsManager.set_bus_volume(&"Master", value / 100.0)


func _on_music_volume_slider_value_changed(value):
	SettingsManager.set_bus_volume(&"Music", value / 100.0)


func _on_sfx_volume_slider_value_changed(value):
	SettingsManager.set_bus_volume(&"SFX", value / 100.0)


func _on_ui_volume_slider_value_changed(value):
	SettingsManager.set_bus_volume(&"UI", value / 100.0)


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

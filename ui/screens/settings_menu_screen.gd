extends CanvasLayer

const ControlBindingRowScene = preload("res://ui/screens/control_binding_row.tscn")

# The General tab is a list of labelled rows - "Window Mode" on the left, the control that sets it
# on the right - grouped under section headings. The three option buttons at the top of it used to
# carry no label at all, so a player was reading "Windowed", "1920x1080" and "60" stacked in a
# column with nothing to say which was which.
const GENERAL := "MarginContainer/PanelContainer/CardMargin/Body/TabContainer/General/GeneralList/"

@onready var window_mode_option_button = get_node(GENERAL + "WindowModeRow/WindowModeOptionButton")
@onready var resolution_option_button = get_node(GENERAL + "ResolutionRow/ResolutionOptionButton")
@onready var max_fps_option_button = get_node(GENERAL + "MaxFpsRow/MaxFpsOptionButton")
@onready var vsync_check_button = get_node(GENERAL + "VSyncRow/VSyncCheckButton")
@onready var master_volume_slider = get_node(GENERAL + "MasterVolumeRow/MasterVolumeSlider")
@onready var music_volume_slider = get_node(GENERAL + "MusicVolumeRow/MusicVolumeSlider")
@onready var sfx_volume_slider = get_node(GENERAL + "SFXVolumeRow/SFXVolumeSlider")
@onready var ui_volume_slider = get_node(GENERAL + "UIVolumeRow/UIVolumeSlider")
@onready var aim_sensitivity_slider = get_node(GENERAL + "AimSensitivityRow/AimSensitivitySlider")
@onready var ui_scale_slider = get_node(GENERAL + "UiScaleRow/UiScaleSlider")
@onready var language_option_button = get_node(GENERAL + "LanguageRow/LanguageOptionButton")

# A slider with no number beside it only says "somewhere around here" - each one gets its own
# readout, kept in step by _refresh_slider_readouts().
@onready var master_volume_value : Label = get_node(GENERAL + "MasterVolumeRow/MasterVolumeValue")
@onready var music_volume_value : Label = get_node(GENERAL + "MusicVolumeRow/MusicVolumeValue")
@onready var sfx_volume_value : Label = get_node(GENERAL + "SFXVolumeRow/SFXVolumeValue")
@onready var ui_volume_value : Label = get_node(GENERAL + "UIVolumeRow/UIVolumeValue")
@onready var aim_sensitivity_value : Label = get_node(GENERAL + "AimSensitivityRow/AimSensitivityValue")
@onready var ui_scale_value : Label = get_node(GENERAL + "UiScaleRow/UiScaleValue")

@onready var tab_container : TabContainer = $MarginContainer/PanelContainer/CardMargin/Body/TabContainer
@onready var general_scroll : ScrollContainer = $MarginContainer/PanelContainer/CardMargin/Body/TabContainer/General
@onready var controls_scroll_container = $MarginContainer/PanelContainer/CardMargin/Body/TabContainer/Controls
@onready var controls_list = $MarginContainer/PanelContainer/CardMargin/Body/TabContainer/Controls/VBoxContainer
@onready var reset_controls_button = $MarginContainer/PanelContainer/CardMargin/Body/TabContainer/Controls/VBoxContainer/ResetControlsButton
@onready var main_menu_button : Button = $MarginContainer/PanelContainer/CardMargin/Body/MainMenuButton

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
	_connect_scroll_follow(reset_controls_button, controls_scroll_container)
	_wire_general_focus_neighbors()
	_refresh_slider_readouts()
	SettingsManager.apply_ui_scale(self)
	# Deferred so the containers have been laid out first. Grabbing focus straight away raises
	# focus_entered while every rect is still zero-sized, and the scroll-follow above answers it by
	# scrolling the list to a position computed against nothing - which opened the General tab a
	# little way down, with its first section heading cut off the top.
	_grab_default_focus.call_deferred()


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
	_point_main_menu_button_back_into(current_tab_control)
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
		_connect_scroll_follow(row.bind_button, controls_scroll_container)
		_connect_scroll_follow(row.joypad_bind_button, controls_scroll_container)
		rows.append(row)
	_wire_control_row_focus_neighbors(rows)


# ScrollContainer does not scroll to a focused child on its own, so each focusable control below
# the fold has to ask it to explicitly once it is focused. Both tabs are lists that outrun their
# own height now, so this takes the container the control actually lives in.
func _connect_scroll_follow(control : Control, scroll : ScrollContainer) -> void:
	control.focus_entered.connect(scroll.ensure_control_visible.bind(control))


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


# The General tab is the same shape of list as the Controls tab and had the same problem: it
# outruns its own height, so Godot's spatial focus search would give up on the rows still below the
# fold - an off-screen row sits farther from the focused control than MainMenuButton does - and drop
# focus out of the list entirely. Chaining the rows top-to-bottom keeps "down" walking the list, and
# _connect_scroll_follow() scrolls each newly focused row into view on the way.
func _wire_general_focus_neighbors() -> void:
	var rows := _focusable_descendants(general_scroll)
	for i in rows.size():
		_connect_scroll_follow(rows[i], general_scroll)
		if i + 1 < rows.size():
			rows[i].focus_neighbor_bottom = rows[i].get_path_to(rows[i + 1])
			rows[i + 1].focus_neighbor_top = rows[i + 1].get_path_to(rows[i])
	# Only the real last row hands focus on to the button below the card.
	if not rows.is_empty():
		rows[-1].focus_neighbor_bottom = rows[-1].get_path_to(main_menu_button)


# MainMenuButton sits under the TabContainer rather than inside a tab, so its way back up depends on
# which tab is showing - a fixed neighbour would point into the hidden tab half the time, and focus
# does not move to a control that cannot take it. Re-pointed on open and on every tab switch.
func _point_main_menu_button_back_into(tab : Control) -> void:
	var rows := _focusable_descendants(tab)
	if rows.is_empty():
		return
	main_menu_button.focus_neighbor_top = main_menu_button.get_path_to(rows[-1])


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
	master_volume_value.text = _percent(value)


func _on_music_volume_slider_value_changed(value):
	SettingsManager.set_bus_volume(&"Music", value / 100.0)
	music_volume_value.text = _percent(value)


func _on_sfx_volume_slider_value_changed(value):
	SettingsManager.set_bus_volume(&"SFX", value / 100.0)
	sfx_volume_value.text = _percent(value)


func _on_ui_volume_slider_value_changed(value):
	SettingsManager.set_bus_volume(&"UI", value / 100.0)
	ui_volume_value.text = _percent(value)


func _on_aim_sensitivity_slider_value_changed(value):
	SettingsManager.set_aim_sensitivity(value / 100.0)
	aim_sensitivity_value.text = _percent(value)


func _on_ui_scale_slider_value_changed(value):
	SettingsManager.set_ui_scale(value / 100.0)
	SettingsManager.apply_ui_scale(self)
	ui_scale_value.text = _percent(value)


func _on_language_option_button_item_selected(index):
	var language_code = SettingsManager.available_languages[index]
	SettingsManager.set_language(language_code, index)


func _on_main_menu_button_pressed():
	SettingsManager.save_settings()
	queue_free()


# --- Slider readouts ---

# Every focusable control under a node, in the order they are laid out - used to hand each row of
# the General tab to its scroll container.
func _focusable_descendants(node : Node) -> Array[Control]:
	var found : Array[Control] = []
	for child in node.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			found.append(child)
		found.append_array(_focusable_descendants(child))
	return found


# Called once on open, after initialise_controls() has put the saved values into the sliders. The
# value_changed handlers keep each readout in step from then on, but setting a slider to the value
# it already holds raises nothing, so the opening pass cannot rely on them.
func _refresh_slider_readouts() -> void:
	master_volume_value.text = _percent(master_volume_slider.value)
	music_volume_value.text = _percent(music_volume_slider.value)
	sfx_volume_value.text = _percent(sfx_volume_slider.value)
	ui_volume_value.text = _percent(ui_volume_slider.value)
	aim_sensitivity_value.text = _percent(aim_sensitivity_slider.value)
	ui_scale_value.text = _percent(ui_scale_slider.value)


func _percent(value : float) -> String:
	return "%d%%" % roundi(value)

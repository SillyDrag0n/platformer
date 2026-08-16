extends Control

func _ready():
	connect_region_buttons()
	_grab_default_focus()

func connect_region_buttons():
	for button in $RegionContainer.get_children():
		if button.has_signal("region_selected"):
			button.region_selected.connect(_on_region_selected)

func _grab_default_focus():
	for button in $RegionContainer.get_children():
		if button is Button and not button.disabled:
			button.grab_focus()
			return

func _on_region_selected(region_id):
	GameStateManager.current_region = region_id
	get_tree().change_scene_to_file("res://ui/notice_board/region_map.tscn")

func _on_return_button_pressed():
	SceneManager.transition_to_scene_faded("Hub")
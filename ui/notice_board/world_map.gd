extends Control

func _ready():
	connect_region_buttons()
	
func connect_region_buttons():
	for button in $RegionContainer.get_children():
		if button.has_signal("region_selected"):
			button.region_selected.connect(_on_region_selected)

func _on_region_selected(region_id):
	GameStateManager.current_region = region_id
	get_tree().change_scene_to_file("res://ui/notice_board/region_map.tscn")
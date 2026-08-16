extends Control

func _ready():
	spawn_bounties()

func spawn_bounties():
	var bounties = GameStateManager.get_bounties_for_region(GameStateManager.current_region)
	var first_poster : Node = null

	for bounty in bounties:
		if GameStateManager.is_bounty_unlocked(bounty.id):
			var poster = spawn_poster(bounty)
			if first_poster == null:
				first_poster = poster

	if first_poster:
		first_poster.grab_focus_button()

func spawn_poster(bounty) -> Node:
	var poster_scene = preload("res://ui/notice_board/notice_board_bounty.tscn")
	var poster = poster_scene.instantiate()

	$BountyContainer.add_child(poster)
	poster.position = bounty["map_position"]
	poster.setup(bounty)

	poster.bounty_selected.connect(_on_bounty_selected)
	return poster

func _on_bounty_selected(bounty):
		GameStateManager.set_active_bounty(bounty)
		GameStateManager.load_active_bounty_level()

func _on_return_button_pressed():
	get_tree().change_scene_to_file("res://ui/notice_board/world_map.tscn")

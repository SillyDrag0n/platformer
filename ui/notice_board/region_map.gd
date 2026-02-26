extends Control

var selected_bounty: BountyData

func _ready():
	spawn_bounties()

func spawn_bounties():
	var bounties = GameStateManager.get_bounties_for_region(GameStateManager.current_region)

	for bounty in bounties:
		if GameStateManager.is_bounty_unlocked(bounty.id):
			spawn_poster(bounty)

func spawn_poster(bounty):
	var poster_scene = preload("res://ui/notice_board/notice_board_bounty.tscn")
	var poster = poster_scene.instantiate()

	$BountyContainer.add_child(poster)
	poster.position = bounty["map_position"]
	poster.setup(bounty)

	poster.bounty_selected.connect(_on_bounty_selected)

func _on_bounty_selected(bounty):
	selected_bounty = bounty

func _on_confirm_pressed():
	if selected_bounty != null:
		GameStateManager.set_active_bounty(selected_bounty)
		GameStateManager.load_active_bounty_level()

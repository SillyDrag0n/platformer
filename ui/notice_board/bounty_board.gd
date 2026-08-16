extends Control

const POSTER_SCENE := preload("res://ui/notice_board/notice_board_bounty.tscn")

@onready var poster_grid: GridContainer = $ScrollContainer/PosterGrid
@onready var inspect_panel = $BountyInspectPanel

var _focused_poster: Node = null

func _ready() -> void:
	inspect_panel.closed.connect(_on_inspect_panel_closed)
	spawn_bounties()


func spawn_bounties() -> void:
	var bounties = GameStateManager.get_unlocked_bounties()
	var first_poster: Node = null

	for bounty in bounties:
		var poster = spawn_poster(bounty)
		if first_poster == null:
			first_poster = poster

	if first_poster:
		first_poster.grab_focus_button()


func spawn_poster(bounty) -> Node:
	var poster = POSTER_SCENE.instantiate()
	poster_grid.add_child(poster)
	poster.setup(bounty)
	poster.poster_pressed.connect(_on_poster_pressed.bind(poster))
	return poster


func _on_poster_pressed(bounty, poster: Node) -> void:
	_focused_poster = poster
	inspect_panel.open(bounty)


func _on_inspect_panel_closed() -> void:
	if _focused_poster:
		_focused_poster.grab_focus_button()


func _on_return_button_pressed() -> void:
	SceneManager.transition_to_scene_faded("Hub")

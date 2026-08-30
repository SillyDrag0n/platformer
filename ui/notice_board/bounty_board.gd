extends Control

const POSTER_SCENE := preload("res://ui/notice_board/notice_board_bounty.tscn")

@onready var poster_grid: GridContainer = $BoardFrame/ScrollContainer/PosterGrid
@onready var inspect_panel = $BountyInspectPanel
@onready var return_button: Button = $ReturnButton

var _focused_poster: Node = null

func _ready() -> void:
	inspect_panel.closed.connect(_on_inspect_panel_closed)
	inspect_panel.accepted.connect(_on_bounty_accepted)
	spawn_bounties()


func spawn_bounties() -> void:
	var posters : Array[Node] = []
	for bounty in GameStateManager.get_unlocked_bounties():
		posters.append(spawn_poster(bounty))

	_wire_focus_neighbours(posters)

	if not posters.is_empty():
		posters[0].grab_focus_button()
	else:
		# Nothing on the board - which happens before the first bounty is posted. Directional input
		# needs something already focused to move from, and Godot never picks a control on its own,
		# so without this a controller had no way off this screen at all: Return could only be
		# clicked. It's the only thing left to do on an empty board anyway.
		return_button.grab_focus()


# Godot's directional focus search works off geometry, and these posters give it a hard time: they
# sit inside a ScrollContainer, tilt at a random angle and bob a few pixels every frame. Wiring the
# grid by hand instead means the way out is always one press down from the bottom row, whatever the
# board is holding and wherever it is scrolled to - the same fix inventory_ui.gd applies to the
# item grid and name_entry_screen.gd to its keyboard.
func _wire_focus_neighbours(posters : Array[Node]) -> void:
	if posters.is_empty():
		return

	var columns : int = maxi(poster_grid.columns, 1)
	var buttons : Array[Button] = []
	for poster in posters:
		buttons.append(poster.get_focus_button())

	for i in buttons.size():
		var button : Button = buttons[i]
		if i % columns > 0:
			button.focus_neighbor_left = button.get_path_to(buttons[i - 1])
		if i % columns < columns - 1 and i + 1 < buttons.size():
			button.focus_neighbor_right = button.get_path_to(buttons[i + 1])
		if i >= columns:
			button.focus_neighbor_top = button.get_path_to(buttons[i - columns])

		# Anything on the bottom row drops to Return rather than nowhere.
		if i + columns < buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(buttons[i + columns])
		else:
			button.focus_neighbor_bottom = button.get_path_to(return_button)

	# And back up onto the board from the way out.
	var last_row_start : int = buttons.size() - 1 - (buttons.size() - 1) % columns
	return_button.focus_neighbor_top = return_button.get_path_to(buttons[last_row_start])


func spawn_poster(bounty) -> Node:
	var poster = POSTER_SCENE.instantiate()
	poster_grid.add_child(poster)
	# Slight random tilt so the grid reads as posters pinned by hand, not a spreadsheet.
	poster.rotation_degrees = randf_range(-4.0, 4.0)
	poster.setup(bounty)
	poster.poster_pressed.connect(_on_poster_pressed.bind(poster))
	return poster


# B / Escape leaves the board outright, the same gesture that backs out of the dossier. The Return
# button is still there, but a screen whose only way out is a focused button is one focus problem
# away from trapping a player who is not using a mouse.
func _unhandled_input(event : InputEvent) -> void:
	# The dossier answers this press itself while it is up, and marks it handled - so this only
	# ever sees a press made against the board.
	if inspect_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_return_button_pressed()


func _on_poster_pressed(bounty, poster: Node) -> void:
	_focused_poster = poster
	inspect_panel.open(bounty)


func _on_inspect_panel_closed() -> void:
	if _focused_poster:
		_focused_poster.grab_focus_button()


func _on_bounty_accepted(bounty: BountyData) -> void:
	# Rip the poster off the board only once the player commits to the bounty.
	if _focused_poster:
		await _focused_poster.tear_off()
	GameStateManager.set_active_bounty(bounty)
	GameStateManager.load_active_bounty_level()


func _on_return_button_pressed() -> void:
	SceneManager.transition_to_scene_faded("Hub")

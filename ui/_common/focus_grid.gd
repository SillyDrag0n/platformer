class_name FocusGrid

# Keyboard/gamepad focus wiring for grids of controls.
#
# Godot's directional focus search is a geometric heuristic, and it falls down in exactly the
# places this game puts controls: wide grids (the 10-column item bag, the name-entry keyboard),
# controls nested in a ScrollContainer, and bounty posters that tilt at a random angle and bob a
# few pixels every frame. Every screen that hit it ended up wiring focus_neighbor_* by hand, and
# four near-identical copies of that wiring is what this replaces.
#
# Nothing here is called before the controls are in the tree - get_path_to() needs both ends of
# each link to share one.


# Left/right along a single row, in order. Ends are left alone so they don't wrap.
static func link_row(controls : Array) -> void:
	for i in controls.size():
		if i > 0:
			controls[i].focus_neighbor_left = controls[i].get_path_to(controls[i - 1])
		if i < controls.size() - 1:
			controls[i].focus_neighbor_right = controls[i].get_path_to(controls[i + 1])


# Up/down along a single column, in order.
static func link_column(controls : Array) -> void:
	for i in controls.size():
		if i > 0:
			controls[i].focus_neighbor_top = controls[i].get_path_to(controls[i - 1])
		if i < controls.size() - 1:
			controls[i].focus_neighbor_bottom = controls[i].get_path_to(controls[i + 1])


# A row-major grid: `controls` laid out left-to-right, wrapping every `columns`.
#
# `above`/`below` are the controls the grid sits between on the screen - a Confirm button under
# the keyboard, the Return button under the bounty board. Every control on the near edge points at
# them, and they point back at that edge's first control, so a grid is never a dead end for a
# player who isn't using a mouse. That was a real trap on an empty bounty board: with the way out
# unreachable, Return could only be clicked.
static func wire_grid(controls : Array, columns : int, below : Control = null, above : Control = null) -> void:
	if controls.is_empty() or columns <= 0:
		return

	var row : Array = []
	for i in controls.size():
		row.append(controls[i])
		if row.size() == columns or i == controls.size() - 1:
			link_row(row)
			row = []

	for col in columns:
		var column : Array = []
		var i := col
		while i < controls.size():
			column.append(controls[i])
			i += columns
		link_column(column)

	var last_row_start : int = controls.size() - 1 - (controls.size() - 1) % columns
	if below != null:
		for i in range(last_row_start, controls.size()):
			controls[i].focus_neighbor_bottom = controls[i].get_path_to(below)
		below.focus_neighbor_top = below.get_path_to(controls[last_row_start])

	if above != null:
		for i in range(0, mini(columns, controls.size())):
			controls[i].focus_neighbor_top = controls[i].get_path_to(above)
		above.focus_neighbor_bottom = above.get_path_to(controls[0])

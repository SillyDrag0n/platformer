class_name AmmoDisplay
extends HBoxContainer

# Bottom-left HUD readout of what is still in the loaded weapon: one pip per round in the magazine,
# spent ones greyed out rather than dropped, so the weapon's full capacity stays readable at a
# glance - a revolver's six and a shotgun's two are very different things to be holding.
#
# Driven by Gun.magazine_changed rather than polling magazine_current every frame, and re-bound on
# PlayerManager.player_spawned since a respawn hands the level a brand new player (and gun).
#
# The pips are drawn rather than textured: there is no cartridge art in the project yet, and two
# stacked ColorRects (tip over case) read as a round at this size and re-tint in one line when it
# is spent.

const CASE_COLOR : Color = Color(0.839216, 0.639216, 0.258824)
const TIP_COLOR : Color = Color(0.678431, 0.427451, 0.156863)
const SPENT_CASE_COLOR : Color = Color(0.254902, 0.207843, 0.156863, 0.65)
const SPENT_TIP_COLOR : Color = Color(0.184314, 0.14902, 0.113725, 0.65)

@export var pip_size : Vector2 = Vector2(14, 40)

var _gun : Node = null
var _pips : Array[Control] = []


func _ready() -> void:
	PlayerManager.player_spawned.connect(_on_player_spawned)
	# The level's Player is usually earlier in the tree than its HUD, so by now that signal has
	# often already been and gone - pick up whoever is already standing there.
	bind_to_player(PlayerManager.player)


func _on_player_spawned(player) -> void:
	bind_to_player(player)


func bind_to_player(player) -> void:
	if is_instance_valid(_gun) and _gun.magazine_changed.is_connected(_on_magazine_changed):
		_gun.magazine_changed.disconnect(_on_magazine_changed)
	_gun = null

	var gun : Node = player.get_node_or_null("Gun") if is_instance_valid(player) else null
	if gun == null:
		set_magazine(0, 0)
		return

	_gun = gun
	gun.magazine_changed.connect(_on_magazine_changed)
	set_magazine(gun.magazine_current, gun.get_magazine_size())


func _on_magazine_changed(current : int, capacity : int) -> void:
	set_magazine(current, capacity)


func set_magazine(current : int, capacity : int) -> void:
	if capacity != _pips.size():
		_rebuild_pips(capacity)
	for i in _pips.size():
		_paint_pip(_pips[i], i < current)
	# Nothing to say while no weapon is loaded, rather than an empty gap in the corner.
	visible = capacity > 0


func _rebuild_pips(capacity : int) -> void:
	for pip in _pips:
		# Detached and freed outright rather than queued: the HBox would otherwise spend the rest
		# of the frame laying itself out around pips that are already on their way out. Safe to do
		# from inside the gun's signal - these are inert ColorRects, never the emitter.
		remove_child(pip)
		pip.free()
	_pips.clear()

	for i in capacity:
		var pip := _make_pip()
		add_child(pip)
		_pips.append(pip)


func _make_pip() -> Control:
	var pip := VBoxContainer.new()
	pip.custom_minimum_size = pip_size
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.add_theme_constant_override("separation", 0)

	var tip := ColorRect.new()
	tip.custom_minimum_size = Vector2(pip_size.x, roundf(pip_size.y * 0.35))
	pip.add_child(tip)

	var casing := ColorRect.new()
	casing.custom_minimum_size = Vector2(pip_size.x, pip_size.y - tip.custom_minimum_size.y)
	pip.add_child(casing)

	return pip


func _paint_pip(pip : Control, loaded : bool) -> void:
	var tip := pip.get_child(0) as ColorRect
	var casing := pip.get_child(1) as ColorRect
	tip.color = TIP_COLOR if loaded else SPENT_TIP_COLOR
	casing.color = CASE_COLOR if loaded else SPENT_CASE_COLOR

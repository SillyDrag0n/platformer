extends Node2D

# The wall coming down after a blast has opened it. Explosion erases a whole connected patch of
# breakable tiles at once (scripts/explosion.gd), and without this that reads as the wall having
# been deleted rather than destroyed - tiles simply stop being drawn, a frame after the fireball,
# with nothing left behind. This puts a puff of dust and falling rock where each of those tiles
# was, so what the player sees is the wall crumbling away where it stood.
#
# Script-only rather than a .tscn: it draws nothing of its own and only spawns rubble_puff.tscn, so
# a scene file here would be a second thing to keep in step for no gain.

const PUFF_SCENE : PackedScene = preload("res://levels/_common/breakable_rubble/rubble_puff.tscn")

# The crumble travels outward from the blast instead of going off everywhere at once: a long wall
# collapsing in a single frame reads as one flat pop, and the ripple is what sells the near end of
# it bringing the rest down. Capped so a patch running right across a level still finishes while
# the explosion it belongs to is on screen.
const WAVE_SPEED : float = 500.0
const MAX_DELAY : float = 0.5

# Past this many cells a patch is thinned rather than puffed cell by cell: the dust overlaps into
# one opaque sheet of it long before this, so the particles a big cave would otherwise cost buy
# nothing to look at.
const MAX_PUFFS : int = 40

# How long after the last puff goes out before the burst takes its children with it - long enough
# for that puff's own particles to finish, since they outlive the moment they were spawned at.
const SETTLE_TIME : float = 1.5

# {"position": Vector2, "delay": float}, soonest first.
var _pending : Array[Dictionary] = []
var _elapsed : float = 0.0


# `cell_positions` are the global positions of the tiles that were just erased, and `origin` is the
# blast that took them. Call before spawning: with no cells the burst has nothing to do and frees
# itself on the frame it arrives.
func setup(cell_positions : PackedVector2Array, origin : Vector2) -> void:
	for position in _thin(cell_positions):
		_pending.append({
			"position": position,
			"delay": minf(origin.distance_to(position) / WAVE_SPEED, MAX_DELAY),
		})
	_pending.sort_custom(func(a, b): return a["delay"] < b["delay"])


func _ready() -> void:
	if _pending.is_empty():
		queue_free()
		return
	# The cells the blast itself covered come out at zero delay, so they go on the same frame the
	# wall breaks rather than a frame behind it.
	_spawn_due()


func _process(delta : float) -> void:
	_elapsed += delta
	_spawn_due()


func _spawn_due() -> void:
	while not _pending.is_empty() and _pending[0]["delay"] <= _elapsed:
		_spawn_puff(_pending.pop_front()["position"])

	if _pending.is_empty():
		set_process(false)
		get_tree().create_timer(SETTLE_TIME).timeout.connect(queue_free)


func _spawn_puff(at : Vector2) -> void:
	var puff := PUFF_SCENE.instantiate() as Node2D
	add_child(puff)
	puff.global_position = at


static func _thin(cells : PackedVector2Array) -> PackedVector2Array:
	if cells.size() <= MAX_PUFFS:
		return cells

	# Evenly spaced through the list rather than the first MAX_PUFFS of it. The cells arrive in the
	# order the flood fill reached them, spreading outward from the blast, so taking every nth
	# leaves dust over the whole patch instead of a dense cluster at the entrance and nothing at
	# the far end of the wall.
	var kept := PackedVector2Array()
	var stride : float = float(cells.size()) / float(MAX_PUFFS)
	for i in MAX_PUFFS:
		kept.append(cells[int(i * stride)])
	return kept

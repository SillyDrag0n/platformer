class_name Ladder
extends Area2D

# A ladder the player climbs, placed in a level and dragged to whatever height it needs.
#
# Its origin is the TOP rung, and it hangs downward - the top is the end that matters, since it is
# what has to line up with the floor the player is climbing onto, while the bottom only has to
# reach the ground.
#
# The rails and the rungs are separate pieces of art. The rails are uniform down their length,
# so they stretch to any height a level wants; the rungs keep their own size and are repeated
# down them. One whole-ladder sprite stretched to fit would smear its rungs into stripes.
#
# It is an Area2D and nothing else - never a body. A ladder the player collided with would stop
# them walking past it, and the whole point is to be stood inside.

const RAILS : Texture2D = preload("res://levels/_common/ladder/ladder_rails.svg")
const RUNG : Texture2D = preload("res://levels/_common/ladder/ladder_rung.svg")

const GROUP := &"Climbable"

# The top of a ladder is level with the floor it serves, so a player stood on that floor is level
# with the top rung rather than inside the ladder. The grab box reaches up past the top rung by
# this much so they can press down and start climbing back down without hunting for the edge.
const TOP_REACH : float = 10.0

@export var height : float = 128.0:
	set(value):
		height = maxf(value, 1.0)
		_rebuild()

@export var width : float = 20.0:
	set(value):
		width = maxf(value, 4.0)
		_rebuild()

@export var rung_spacing : float = 14.0:
	set(value):
		rung_spacing = maxf(value, 4.0)
		_rebuild()

@onready var collision_shape : CollisionShape2D = $CollisionShape2D

# Tracked from the enter/exit signals rather than polled with get_overlapping_bodies(), which is a
# frame behind and reports nothing at all on the frame a level loads.
var _bodies : Array[Node2D] = []


func _ready() -> void:
	# Duplicated before it is resized, or a ladder set to a different height would write that
	# height into the shape resource every other ladder in the level is sharing.
	collision_shape.shape = collision_shape.shape.duplicate()
	_rebuild()


func _rebuild() -> void:
	queue_redraw()
	if collision_shape == null or collision_shape.shape == null:
		return
	collision_shape.shape.size = Vector2(width, height + TOP_REACH)
	collision_shape.position = Vector2(0.0, (height - TOP_REACH) * 0.5)


func _draw() -> void:
	var half : float = width * 0.5
	draw_texture_rect(RAILS, Rect2(-half, 0.0, width, height), false)

	# Rung art is kept in proportion to the ladder's width, so a wider ladder gets chunkier rungs
	# rather than the same thin ones stretched across a bigger gap.
	var rung_height : float = width * RUNG.get_height() / RUNG.get_width()

	# Spaced from the top down, so the top rung always sits exactly on the floor line the ladder
	# was placed against however odd the height works out.
	var y : float = 0.0
	while y <= height:
		draw_texture_rect(RUNG, Rect2(-half, y - rung_height * 0.5, width, rung_height), false)
		y += rung_spacing


# Where a climber's feet may go: the top rung down to the bottom one.
func top_y() -> float:
	return global_position.y


func bottom_y() -> float:
	return global_position.y + height * global_scale.y


func holds(body : Node2D) -> bool:
	return _bodies.has(body)


# The ladder `body` is currently stood inside, if any. Scanned on demand rather than pushed onto
# the player, so nothing about the player has to know ladders exist until it asks - and it is only
# ever asked on a frame where climb is actually being pressed.
static func at_body(body : Node2D) -> Ladder:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return null
	for ladder in body.get_tree().get_nodes_in_group(GROUP):
		if ladder is Ladder and ladder.holds(body):
			return ladder
	return null


func _on_body_entered(body : Node2D) -> void:
	if not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body : Node2D) -> void:
	_bodies.erase(body)

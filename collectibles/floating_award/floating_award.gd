class_name FloatingAward
extends Node2D

# The "+$5" that floats up when money is taken. It used to be a Label on the dollar itself, which
# put the number down in the dirt where the coin had rolled to - off to one side, behind the player
# as often as not, and drawn at whatever the pickup's own z-index was. It reads off the player's
# head now, which is where the player is already looking.
#
# It is spawned into the level rather than parented to the player, so it stays where it was earned
# and drifts behind a player who is still running - the same read as any hit number.

const SCENE : PackedScene = preload("res://collectibles/floating_award/floating_award.tscn")

# One number at a time. Two dollars taken in the same breath used to stack two labels on the same
# spot, drawn over each other and both saying "+$1"; the second adds to the first instead.
const GROUP := &"floating_award"

# Everything in a level is painted at or below the foreground layer's 70 (see any level's TileMap).
# A number that can end up behind a rock is not feedback.
const AWARD_Z : int = 100

# Up out of the player's own head, which is 33px of capsule above their origin.
const HEAD_CLEARANCE : float = 46.0

# How near the new number has to be to an existing one to be added to it rather than starting its
# own. About the height it is spawned at, so "the same breath, the same spot" merges and a coin
# taken across the clearing does not.
const MERGE_RADIUS : float = 48.0

const RISE : float = 26.0
const LIFETIME : float = 0.7

@onready var label : Label = $Label

var _amount : int = 0
var _tween : Tween


# Puts `amount` over `target`'s head, or adds it to the number already floating there. Named for
# what it does rather than `show()`, which is Node2D's own.
static func spawn(amount : int, target : Node2D) -> void:
	if amount == 0 or not is_instance_valid(target) or not target.is_inside_tree():
		return

	var spot := target.global_position + Vector2(0, -HEAD_CLEARANCE)
	var existing := _award_near(target.get_tree(), spot)
	if existing != null:
		existing.add(amount)
		return

	var award : FloatingAward = SCENE.instantiate()
	# Into the level beside the player, not onto the player - see the note at the top.
	target.get_parent().add_child(award)
	award.global_position = spot
	award.add(amount)


# The number already floating over this spot, if there is one. Distance-checked rather than just
# taking whichever is in the group: a player who takes a dollar, runs off and takes another inside
# the same second would otherwise have the second one added to a number left behind them.
static func _award_near(tree : SceneTree, spot : Vector2) -> FloatingAward:
	for award in tree.get_nodes_in_group(GROUP):
		if is_instance_valid(award) and award.global_position.distance_to(spot) <= MERGE_RADIUS:
			return award
	return null


func _ready() -> void:
	z_index = AWARD_Z
	add_to_group(GROUP)


func add(amount : int) -> void:
	_amount += amount
	label.text = tr("+$%d") % _amount
	_float_up()


# Restarted rather than left to run on from wherever it had got to: a merged total arriving on a
# number that was already half faded out would be the least readable moment of the whole effect.
func _float_up() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	modulate.a = 1.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position:y", position.y - RISE, LIFETIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(queue_free)

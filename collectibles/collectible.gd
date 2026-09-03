class_name Collectible
extends Node2D

# Money and the like, dropped by an enemy on death (see enemies/_common/enemy.gd) and picked up by
# walking over it. Where it lands and what it is drawn over are PickupDrop's business, and shared
# with the pickups that are not Collectibles; what the player sees on taking it is FloatingAward's,
# which puts the number over the player's head rather than down in the dirt where the coin was.

@export var award_amount : int = 1

@onready var animated_sprite_2d : AnimatedSprite2D = $AnimatedSprite2D
@onready var area : Area2D = $Area2D

# One pickup is one award. queue_free() only takes effect at the end of the frame, so without this
# a second overlap in the same frame - another body, or the player re-entering - could be paid for
# the same dollar twice.
var _collected := false


func _ready() -> void:
	PickupDrop.fall_to_ground(self)


func _on_area_2d_body_entered(body : Node2D) -> void:
	if _collected or body == null or not body.is_in_group("Player"):
		return
	_collected = true

	CollectibleManager.give_pickup_award(award_amount)
	PickupSound.play_for(self)
	FloatingAward.spawn(award_amount, body)
	# Nothing left here to watch float away, so the coin goes now rather than lingering as an
	# invisible node with a live shape in it.
	queue_free()

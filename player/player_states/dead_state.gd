extends NodeState

@export var character_body_2d : CharacterBody2D
@export var player : Node


func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	pass


func enter():
	# Terminal state - lower_body_controller.gd plays the "death" collapse clip once it sees this
	# state, and upper_body_controller.gd stops updating arm/head aim targets entirely (its own
	# "dead" guard), freezing them where they last were. player_death() delays the poof
	# effect/removal just long enough for the collapse to actually be seen before the player node
	# is gone, so there's nothing further for this state itself to drive.
	character_body_2d.velocity = Vector2.ZERO
	player.player_death()


func exit():
	pass

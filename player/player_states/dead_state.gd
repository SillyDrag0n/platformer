extends NodeState

@export var character_body_2d : CharacterBody2D
@export var player : Node


func on_process(delta : float):
	pass


func on_physics_process(delta : float):
	pass


func enter():
	# Terminal state - no dedicated death pose exists yet, so the last active frame just freezes
	# rather than looping something misleading like idle. player_death() queue_frees the whole
	# player shortly after this, so there's nothing further for this state to drive.
	character_body_2d.velocity = Vector2.ZERO
	player.player_death()


func exit():
	pass

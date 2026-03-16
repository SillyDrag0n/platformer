extends Node

@export var node_finite_state_machine : NodeFiniteStateMachine

func _on_arena_body_entered(body:Node2D) -> void:
	print("entered")
	if body.is_in_group("Player"):
		print("Move")
		node_finite_state_machine.transition_to("Move")

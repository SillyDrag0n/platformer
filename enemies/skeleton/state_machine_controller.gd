extends Node

@export var node_finite_state_machine : NodeFiniteStateMachine
@export var chase_timer : Timer

func _on_attack_range_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		node_finite_state_machine.transition_to("Attack")

func _on_attack_range_body_exited(body:Node2D) -> void:
	if body.is_in_group("Player"):
		node_finite_state_machine.transition_to("Aggro")

func _on_aggro_range_body_exited(body:Node2D) -> void:
	if body.is_in_group("Player"):
		node_finite_state_machine.transition_to("Chase")

func _on_aggro_range_body_entered(body:Node2D) -> void:
	if chase_timer.is_stopped() == false:
		chase_timer.stop()
	if body.is_in_group("Player"):
		node_finite_state_machine.transition_to("Aggro")

func _on_chase_timer_timeout() -> void:
	node_finite_state_machine.transition_to("Idle")

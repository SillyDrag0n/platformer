extends Node

@export var node_finite_state_machine : NodeFiniteStateMachine
@export var chase_timer : Timer

func _on_attack_range_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		node_finite_state_machine.transition_to("Attack")

func _on_attack_range_body_exited(body:Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	# A bandit already lining up a shot sees it through rather than being yanked out of the pose.
	# He pops up, aims for half a second and fires (see attack_state.gd) - and transitioning here
	# the instant the player stepped out of range cancelled that mid-aim, so a player who kept
	# moving was shot at by nobody: the bandit just fell in behind them and walked. The state is
	# told to chase once the shot has gone off instead.
	var current := node_finite_state_machine.current_node_state
	if current != null and current.name == "Attack" and not current.has_fired:
		current.chase_after_firing = true
		return

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

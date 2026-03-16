extends NodeState

@export var StateMachine: NodeFiniteStateMachine
@export var Boss: CharacterBody2D

func physics_update(_delta):
	var direction = (Boss.hover_target - Boss.global_position).normalized()
	Boss.velocity = direction * Boss.hover_speed
	
	if Boss.global_position.distance_to(Boss.hover_target) < 20:
		pick_new_hover_target()


func enter():
	pick_new_hover_target()


func pick_new_hover_target():
	Boss.hover_target = Vector2(
		randf_range(Boss.arena_left, Boss.arena_right),
		randf_range(Boss.arena_top, Boss.arena_bottom)
	)
	print(Boss.hover_target)
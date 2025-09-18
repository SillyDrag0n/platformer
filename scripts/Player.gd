extends CharacterBody2D

@export_subgroup("Nodes")
@export var input_component: InputComponent
@export var gravity_component: GravityComponent
@export var movement_component: MovementComponent
@export var jump_component: AdvancedJumpComponent
@export var animation_component: AnimationComponent

@onready var bullet_scene = preload("res://scenes/common/bullet/bullet.tscn")
var shoot_timer : Timer
const shoot_time = 0.25
var shoot_available : bool = true

func _process(delta):
	shoot()

func _physics_process(delta: float) -> void:
	player_falling(delta)
	gravity_component.handle_gravity(self, delta)
	movement_component.handle_horizontavl_movement(self, input_component.input_horizontal)
	jump_component.handle_jump(self, input_component.get_jump_input(), input_component.get_jump_input_released())
	animation_component.handle_move_animation(input_component.input_horizontal)
	animation_component.handle_jump_animation(jump_component.is_going_up, gravity_component.is_falling)

	move_and_slide()

## Handle shooting
func shoot():
	if Input.is_action_pressed("shoot"): 
		var bullet = bullet_scene.instantiate()
		bullet.position = position
		bullet.bullet_direction = (position - get_global_mouse_position()).normalized()
		bullet.rotation = get_global_mouse_position().angle()
		get_parent().add_child(bullet)	

func player_falling(delta):
	if !is_on_floor():
		velocity.y += 1000 * delta

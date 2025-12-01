extends NodeState

@export var animated_sprite_2d: AnimatedSprite2D
@export var chase_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func enter():
	animated_sprite_2d.play("chase")
	chase_timer.start()


func exit():
	animated_sprite_2d.stop()
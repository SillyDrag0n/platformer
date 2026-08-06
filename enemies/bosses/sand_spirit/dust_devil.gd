extends Node2D

@export var speed : int = 180
@export var damage_amount : int = 1
@export var life_time : float = 6.0

var direction : Vector2 = Vector2.ZERO

func _ready():
    if direction == Vector2.ZERO:
        direction = Vector2.DOWN
    rotation = direction.angle()
    $Timer.wait_time = life_time
    $Timer.start()

func _physics_process(delta):
    global_position += direction * speed * delta

func _on_timer_timeout():
    queue_free()

func get_damage_amount() -> int:
    return damage_amount

func _on_hurtbox_area_entered(_area: Area2D) -> void:
    queue_free()

func _on_hurtbox_body_entered(_body: Node2D) -> void:
    queue_free()

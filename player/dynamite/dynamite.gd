extends CharacterBody2D

enum State { HELD, THROWN, LANDED }

const Explosion = preload("res://scripts/explosion.gd")

# Fuse blink speeds up as time runs out - MAX_BLINK_INTERVAL right after lighting, MIN_BLINK_INTERVAL
# right before it goes off - so there's always a visible countdown, whether it's still in the
# player's hand or already thrown.
const FUSE_SPARK_COLOR := Color(1, 0.85, 0.2, 1)
const FUSE_WARNING_COLOR := Color(1, 0.1, 0.1, 1)
const MIN_BLINK_INTERVAL : float = 0.08
const MAX_BLINK_INTERVAL : float = 0.45

var state : State = State.HELD

var throw_speed : float = 500.0
var gravity : float = 1400.0
var explosion_damage : int = 4
var explosion_radius : float = 64.0

var _blink_elapsed : float = 0.0
var _blink_on : bool = false

@onready var fuse_timer : Timer = $FuseTimer
@onready var sprite : Sprite2D = $Sprite
@onready var fuse_spark : Polygon2D = $FuseSpark


func light_fuse(time : float) -> void:
	fuse_timer.wait_time = time
	fuse_timer.start()


func throw(direction : Vector2) -> void:
	state = State.THROWN
	velocity = direction * throw_speed


func _process(delta : float) -> void:
	if fuse_timer.is_stopped():
		return

	var fraction_remaining : float = fuse_timer.time_left / fuse_timer.wait_time
	var blink_interval : float = lerpf(MIN_BLINK_INTERVAL, MAX_BLINK_INTERVAL, fraction_remaining)

	_blink_elapsed += delta
	if _blink_elapsed < blink_interval:
		return
	_blink_elapsed = 0.0

	_blink_on = !_blink_on
	fuse_spark.color = FUSE_WARNING_COLOR if _blink_on else FUSE_SPARK_COLOR
	sprite.modulate = FUSE_WARNING_COLOR if _blink_on else Color.WHITE


func _physics_process(delta : float) -> void:
	if state == State.HELD:
		return

	velocity.y += gravity * delta
	move_and_slide()

	if state == State.THROWN and is_on_floor():
		state = State.LANDED
		velocity = Vector2.ZERO


func _on_fuse_timer_timeout() -> void:
	explode()


func explode() -> void:
	Explosion.detonate(self, explosion_damage, explosion_radius)
	queue_free()

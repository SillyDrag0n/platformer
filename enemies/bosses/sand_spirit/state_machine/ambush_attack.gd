extends NodeState

@export var boss: BossStateController

signal finished

enum Phase { SINK, TRACK, DELAY, JUMP }

const ARRIVAL_EPSILON := 4.0
const HIDE_DEPTH := 100.0

const SINK_TIMEOUT := 2.5
const TRACK_TIMEOUT := 4.0
const DELAY_DURATION := 0.35
const JUMP_DURATION := 0.4

const SINK_SPEED := 220.0
const TRACK_SPEED := 160.0
const JUMP_SPEED := 500.0

const ATTACK_RANGE_X := 60.0
const ATTACK_RANGE_Y := 40.0
const DAMAGE_AMOUNT := 1

var sand_eruption_effect = preload("res://enemies/bosses/sand_spirit/sand_eruption_effect.tscn")
var sand_sink_effect = preload("res://enemies/bosses/sand_spirit/sand_sink_effect.tscn")

var phase: Phase
var timer: float
var underground_y: float
var jump_target_y: float
var has_hit_player: bool

func enter():
	has_hit_player = false
	underground_y = boss.arena_bottom + HIDE_DEPTH
	phase = Phase.SINK
	timer = SINK_TIMEOUT
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.Hide)

func physics_update(delta):
	match phase:
		Phase.SINK:
			_move_vertical_toward(underground_y, SINK_SPEED)
			timer -= delta
			if _reached_y(underground_y) or timer <= 0:
				_start_track()
		Phase.TRACK:
			_move_horizontal_toward_player(TRACK_SPEED)
			timer -= delta
			if _aligned_with_player_x() or timer <= 0:
				_start_delay()
		Phase.DELAY:
			timer -= delta
			if timer <= 0:
				_start_jump()
		Phase.JUMP:
			_move_vertical_toward(jump_target_y, JUMP_SPEED)
			_check_for_hit()
			timer -= delta
			if timer <= 0:
				_end_attack()

func _start_track():
	phase = Phase.TRACK
	timer = TRACK_TIMEOUT
	boss.velocity = Vector2.ZERO
	boss.play_animation(boss.Animations.Hidden)
	_spawn_effect(sand_sink_effect)

func _start_delay():
	phase = Phase.DELAY
	timer = DELAY_DURATION
	boss.velocity = Vector2.ZERO

func _start_jump():
	phase = Phase.JUMP
	timer = JUMP_DURATION
	var player_y = PlayerManager.player.global_position.y if PlayerManager.player else boss.arena_top
	jump_target_y = clampf(player_y, boss.arena_top, boss.arena_bottom)
	boss.play_animation(boss.Animations.AmbushAttack)
	_spawn_effect(sand_eruption_effect)

func _end_attack():
	boss.velocity = Vector2.ZERO
	finished.emit()

func _spawn_effect(effect_scene: PackedScene):
	var effect = effect_scene.instantiate() as Node2D
	effect.global_position = boss.global_position
	boss.get_parent().add_child(effect)

func _move_horizontal_toward_player(speed: float):
	if PlayerManager.player == null:
		boss.velocity = Vector2.ZERO
		return

	var target_x = clampf(PlayerManager.player.global_position.x, boss.arena_left, boss.arena_right)
	var direction_x = signf(target_x - boss.global_position.x)
	boss.velocity = Vector2(direction_x * speed, 0)

func _move_vertical_toward(target_y: float, speed: float):
	var direction_y = signf(target_y - boss.global_position.y)
	boss.velocity = Vector2(0, direction_y * speed)

func _reached_y(target_y: float) -> bool:
	return absf(boss.global_position.y - target_y) <= ARRIVAL_EPSILON

func _aligned_with_player_x() -> bool:
	if PlayerManager.player == null:
		return true
	return absf(PlayerManager.player.global_position.x - boss.global_position.x) <= ATTACK_RANGE_X

func _check_for_hit():
	if has_hit_player or PlayerManager.player == null:
		return

	var player = PlayerManager.player
	var player_above = player.global_position.y < boss.global_position.y
	var player_aligned_x = absf(player.global_position.x - boss.global_position.x) <= ATTACK_RANGE_X
	var player_aligned_y = absf(player.global_position.y - boss.global_position.y) <= ATTACK_RANGE_Y

	if player_above and player_aligned_x and player_aligned_y:
		player.take_hit(DAMAGE_AMOUNT)
		has_hit_player = true

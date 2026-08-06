class_name BossArena
extends Area2D

@export var boss: BossStateController

@onready var walls: Node2D = $Walls

var _triggered := false


func _ready() -> void:
	_seal(false)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or boss == null:
		return
	if not body.is_in_group("Player"):
		return

	_triggered = true
	_seal(true)
	boss.start_boss_fight()
	boss.defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)


func _on_boss_defeated() -> void:
	_triggered = false
	_seal(false)


func _seal(sealed: bool) -> void:
	for wall in walls.get_children():
		for shape in wall.get_children():
			if shape is CollisionShape2D:
				shape.disabled = not sealed

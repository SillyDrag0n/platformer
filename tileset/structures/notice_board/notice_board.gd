extends Node2D

@export var notice_board_ui: CanvasItem

@onready var interactable: Area2D = $Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact


func _on_interact():
	print("Inspect Notice board")
	interactable.is_interactable = false
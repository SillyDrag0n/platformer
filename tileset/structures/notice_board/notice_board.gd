extends Node2D

@onready var interactable: Area2D = $Interactable

func _ready() -> void:
	interactable.interact = _on_interact

func _on_interact():
	interactable.is_interactable = false
	SceneManager.set_pending_spawn_position(PlayerManager.player.global_position)
	UiManager.open_bounty_board()
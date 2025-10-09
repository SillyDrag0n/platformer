extends Node

var player_scene = preload("res://player/player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func Respawn():
	var player_instance = player_scene.instantiate()
	add_child(player_instance)

extends Node2D

# Every bullet, enemy attack effect, and thrown weapon (player and enemy alike) gets added here
# instead of get_tree().current_scene / <enemy>.get_parent() scattered across combat scripts -
# one shared, consistently-layered parent instead of a z_index fix needed at every spawn site.
# Above Player (60), below Foreground (70) - see the level TileMap layers for the rest of the tiers.
const Z_INDEX := 65


func _ready() -> void:
	z_index = Z_INDEX


func spawn(instance : Node2D) -> void:
	add_child(instance)

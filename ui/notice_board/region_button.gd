extends Button

signal region_selected(region_id)
@export var region_id: String

func _ready():
	var unlocked = GameStateManager.is_region_unlocked(str(region_id))
	disabled = not unlocked

	if unlocked:
		modulate = Color.WHITE
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.6)

func _on_pressed():
	emit_signal("region_selected", region_id)

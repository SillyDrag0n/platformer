extends CanvasLayer

@onready var RewardsContainer: HBoxContainer = $PanelContainer/VBoxContainer/RewardsContainer
var bounty_reward = preload("res://ui/screens/bounty_reward.tscn")


func _ready():
	print_debug("Bounty ready")
	if GameStateManager.active_bounty == null:
		pass

	for reward in GameStateManager.active_bounty.rewards:
		var reward_instance = bounty_reward.instantiate()
		RewardsContainer.add_child(reward_instance)
		reward_instance.set_reward_texture(reward.icon)
		reward_instance.set_reward_label(reward.display_name)
		

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/hub_level.tscn")

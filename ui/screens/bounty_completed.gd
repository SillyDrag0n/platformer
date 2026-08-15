extends CanvasLayer

@onready var RewardsContainer: HBoxContainer = $PanelContainer/VBoxContainer/RewardsContainer
@onready var return_button: Button = $PanelContainer/VBoxContainer/Button
var bounty_reward = preload("res://ui/screens/bounty_reward.tscn")


func _ready():
	return_button.grab_focus()

	if GameStateManager.active_bounty == null:
		return

	for reward in GameStateManager.active_bounty.rewards:
		var reward_instance = bounty_reward.instantiate()
		RewardsContainer.add_child(reward_instance)
		reward_instance.set_reward_texture(reward.icon)
		reward_instance.set_reward_label(reward.display_name)

	for ability in GameStateManager.active_bounty.ability_rewards:
		var ability_reward_instance = bounty_reward.instantiate()
		RewardsContainer.add_child(ability_reward_instance)
		ability_reward_instance.set_reward_texture(ability.icon)
		ability_reward_instance.set_reward_label(ability.display_name)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/hub_level.tscn")

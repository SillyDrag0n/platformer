extends CanvasLayer

# The end of a whole contract, shown once the bounty is turned in: what was finished, and what it
# paid out. The per-leg screen (ui/screens/stage_completed.gd) is the one that fires between the
# stages on the way here, and the two are deliberately built to the same card so the end of a
# contract reads as the last beat of the same sequence rather than a different screen.

@onready var bounty_icon : TextureRect = $CenterContainer/Card/Margin/Body/BountyIcon
@onready var bounty_title_label : Label = $CenterContainer/Card/Margin/Body/BountyTitleLbl
@onready var rewards_label : Label = $CenterContainer/Card/Margin/Body/RewardsLbl
@onready var rewards_container : GridContainer = $CenterContainer/Card/Margin/Body/RewardsContainer
@onready var return_button : Button = $CenterContainer/Card/Margin/Body/Button

var bounty_reward = preload("res://ui/screens/bounty_reward.tscn")


func _ready():
	SettingsManager.apply_ui_scale(self)
	return_button.grab_focus()

	var bounty : BountyData = GameStateManager.active_bounty
	if bounty == null:
		# Nothing to name and nothing to hand over. The heading and the way out still stand, but
		# the poster art and the rewards row would otherwise be an empty frame and a bare heading.
		bounty_icon.visible = false
		bounty_title_label.visible = false
		rewards_label.visible = false
		return

	bounty_title_label.text = tr(bounty.title)
	# The same art the notice board prints on the poster, in full colour here - the board draws it
	# as a black silhouette right up until the contract is done (see notice_board_bounty.gd).
	bounty_icon.texture = bounty.icon
	bounty_icon.visible = bounty.icon != null

	for reward in bounty.rewards:
		_add_reward(reward.icon, reward.display_name)
	for ability in bounty.ability_rewards:
		_add_reward(ability.icon, ability.display_name)

	# A contract that pays nothing but progress shouldn't leave a heading over an empty row.
	rewards_label.visible = rewards_container.get_child_count() > 0


func _add_reward(icon : Texture2D, display_name : String) -> void:
	var reward_instance = bounty_reward.instantiate()
	rewards_container.add_child(reward_instance)
	reward_instance.set_reward_texture(icon)
	reward_instance.set_reward_label(display_name)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/hub/hub_level.tscn")

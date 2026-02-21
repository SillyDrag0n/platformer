extends ColorRect

var bounty_data

@onready var title_label = $Title
@onready var reward_label = $Reward
@onready var accept_button = $AcceptButton
@onready var picture = $Picture	

func setup(data):
	bounty_data = data
	title_label.text = data.title
	picture.texture = data.picture

func _on_accept_button_pressed():
	print(title_label)
	BountyManager.accept_bounty(bounty_data.id)
	get_parent().get_parent().populate_bounties()
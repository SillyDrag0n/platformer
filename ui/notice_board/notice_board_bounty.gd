extends ColorRect

var bounty_data

signal bounty_selected(id)

@onready var title_label = $Title
@onready var reward_label = $Reward
@onready var accept_button = $AcceptButton
@onready var picture = $Picture	

func setup(data):
	bounty_data = data
	title_label.text = data.title
	picture.texture = data.picture


func _on_accept_button_pressed():
	emit_signal("bounty_selected", bounty_data.id)

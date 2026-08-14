extends Control

signal bounty_selected(bounty_data)

var base_position: Vector2
var bounty_data: BountyData

func setup(bounty: BountyData):
	bounty_data = bounty
	$TitleLabel.text = bounty.title
	$RumorText.text = bounty.description if bounty.description != "" else "No word yet on this one."
	if bounty.icon:
		$Picture.texture = bounty.icon
		$Picture.self_modulate = Color.WHITE if bounty.completed else Color.BLACK

func _ready():
	base_position = position

func _process(_delta):
	position.y = base_position.y + sin(Time.get_ticks_msec() * 0.004) * 5

func _on_accept_button_pressed():
	bounty_selected.emit(bounty_data)


func grab_focus_button() -> void:
	$AcceptButton.grab_focus()
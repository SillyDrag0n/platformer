extends Control

signal bounty_selected(bounty_data)

var base_position: Vector2
var bounty_data: BountyData

func setup(bounty: BountyData):
    bounty_data = bounty
    $TitleLabel.text = bounty.title

func _ready():
    base_position = position

func _process(_delta):
    position.y = base_position.y + sin(Time.get_ticks_msec() * 0.004) * 5

func _on_accept_button_pressed():
    emit_signal("bounty_selected", bounty_data)
class_name BountyEntry
extends ColorRect

signal selected(bounty : BountyData)

const STATUS_COLORS := {
	"Locked": Color(0.6, 0.6, 0.6),
	"Available": Color(1, 1, 1),
	"Completed": Color(0.45, 0.85, 0.45),
}

const NORMAL_COLOR := Color(0.945098, 0.882353, 0.760784, 0.15)
const FOCUSED_COLOR := Color(0.960784, 0.615686, 0.156863, 0.6)

var bounty : BountyData

@export var default_icon : Texture2D

@onready var title_label : Label = $HBoxContainer/TitleLabel
@onready var status_label : Label = $HBoxContainer/StatusLabel
@onready var icon_rect : TextureRect = $HBoxContainer/IconRect
@onready var button : Button = $Button


func _ready() -> void:
	# The Button covering this entry is fully transparent, which also hides its built-in focus
	# outline - drive the highlight manually instead.
	button.focus_entered.connect(func(): color = FOCUSED_COLOR)
	button.focus_exited.connect(func(): color = NORMAL_COLOR)


func set_bounty_data(new_bounty : BountyData):
	bounty = new_bounty
	title_label.text = tr(bounty.title)
	icon_rect.texture = bounty.icon if bounty.icon else default_icon
	# undefeated bounties show as a silhouette so the boss isn't spoiled ahead of the fight
	icon_rect.self_modulate = Color.WHITE if bounty.completed else Color.BLACK

	var status_text := bounty.get_status_text()
	status_label.text = tr(status_text)
	status_label.modulate = STATUS_COLORS.get(status_text, Color.WHITE)

	modulate.a = 1.0 if bounty.unlocked else 0.5


func _on_button_pressed():
	selected.emit(bounty)


func grab_focus_button() -> void:
	button.grab_focus()

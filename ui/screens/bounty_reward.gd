extends Control

@onready var reward_texture: TextureRect = $MarginContainer/VBoxContainer/RewardTexture
@onready var reward_label: Label = $MarginContainer/VBoxContainer/RewardLabel

func set_reward_texture(texture):
	print_debug("Set reward texture")
	reward_texture.texture = texture

func set_reward_label(text):
	print_debug("Set reward label")
	reward_label.text = text

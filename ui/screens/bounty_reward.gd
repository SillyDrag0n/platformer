extends Control

@onready var reward_texture: TextureRect = $MarginContainer/VBoxContainer/RewardTexture
@onready var reward_label: Label = $MarginContainer/VBoxContainer/RewardLabel

func set_reward_texture(texture):
	reward_texture.texture = texture

func set_reward_label(text):
	reward_label.text = text

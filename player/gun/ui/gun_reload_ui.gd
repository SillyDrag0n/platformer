extends Control

func _ready() -> void:
	self.hide()

func set_value(value):
	$TextureProgressBar.value = value

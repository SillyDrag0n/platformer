extends Control

func _ready() -> void:
		self.hide()

func setValue(value):
	$TextureProgressBar.value = value

extends Control

func _ready() -> void:
		self.hide()

func setValue(value):
	print(value)	
	$TextureProgressBar.value = value

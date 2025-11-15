extends Control

func _ready() -> void:
		$TextureProgressBar.hide()

func setValue(value):
	print(value)	
	$TextureProgressBar.value = value
	if value > 0:
		$TextureProgressBar.show()
	else:
		$TextureProgressBar.hide()
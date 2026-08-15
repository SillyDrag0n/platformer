class_name ShopNPC
extends NPC

@export var speaker_name : String = ""
@export var greeting_line : String = "Howdy. Care to take a look at what I've got?"

@onready var shop_ui : ShopUI = $ShopUi
@onready var dialogue_box : DialogueBox = $DialogueBox


func _on_interact() -> void:
	dialogue_box.show_choice(speaker_name, greeting_line, "Yes", "No", _on_greeting_accepted, _on_greeting_declined)


func _on_greeting_accepted() -> void:
	shop_ui.open()


func _on_greeting_declined() -> void:
	pass

class_name QuestData
extends Resource

@export var id : String
@export var title : String

@export_category("Dialogue")
@export var offer_dialogue : Array[String] = []
@export var complete_dialogue : Array[String] = []

@export_category("Turn-in")
@export var required_item : ItemData
@export var required_amount : int = 1
@export var reward_items : Array[ItemData] = []

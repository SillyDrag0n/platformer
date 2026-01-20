extends Node

var inventory : Dictionary
const ITEM_SLOT = preload("res://ui/inventory/item_slot.gd")

func add_to_inventory(type : String, value : String):
	inventory[type] = value


func has_inventory_item(value : String) -> bool:
	if value == null:
		return false
	
	var item = inventory.find_key(value)
	
	if item:
		return true
	
	return false

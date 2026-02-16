extends CanvasLayer

@export var item_grid : GridContainer

func _ready():
	InventoryManager.UpdatedInventory.connect(update_inventory_ui)
	InventoryManager.UpdatedSlot.connect(update_inventory_slot_ui)
	create_inventory_ui()

func _process(_delta: float):
	if GameInputEvents.inventory_input() and !visible:
		show()
	elif GameInputEvents.inventory_input() and visible:
		hide()

func update_inventory_ui():
	pass

func update_inventory_slot_ui(slot):
	pass

func create_inventory_ui():
	for item_slot in InventoryManager.item_slots:
		if item_slot.get_parent():
			item_slot.get_parent().remove_child(item_slot)
		item_grid.add_child(item_slot)
		print("Children count:", item_grid.get_child_count())
	

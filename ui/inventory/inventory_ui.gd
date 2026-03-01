extends CanvasLayer

@export var item_grid : GridContainer
@export var item_slot_scene : PackedScene

func _ready():
	InventoryManager.UpdatedInventory.connect(update_inventory_ui)
	create_inventory_ui()

func _process(_delta):
	if GameInputEvents.inventory_input():
		visible = !visible


func update_inventory_ui():
	create_inventory_ui()


func create_inventory_ui():
	for child in item_grid.get_children():
		child.queue_free()
		
	for slot_data in InventoryManager.item_slots:
		var slot = item_slot_scene.instantiate()
		item_grid.add_child(slot)
		slot.set_slot_data(slot_data["item"], slot_data["quantity"])

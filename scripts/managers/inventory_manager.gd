extends Node

signal UpdatedInventory
signal UpdatedSlot (slot: ItemSlot)

var item_slots: Array[ItemSlot] = []

var size: int = 20
var start_items: Dictionary[ItemData, int]
var item_slot_scene: PackedScene = preload("res://ui/inventory/ItemSlot.tscn")

func _ready():
    print_debug("creating slots")

    item_slots.clear()

    for i in range(size):
        var slot := item_slot_scene.instantiate() as ItemSlot
        item_slots.append(slot)

    # add start items
    for key in start_items:
        for i in range(start_items[key]):
            add_item(key)

    print_debug("slots created")
    
func add_item(item: ItemData) -> bool:
    var slot : ItemSlot = get_item_slot(item)

    if slot and slot.quantity < item.max_stack_size:
        slot.quantity += 1
    else:
        slot = get_empty_item_slot()
        if not slot:
            return false
        
        slot.item = item
        slot.quantity = 1

    UpdatedInventory.emit()
    UpdatedSlot.emit(slot)
    
    return true

func remove_item(item: ItemData):
    if not has_item(item):
        return

    var slot : ItemSlot = get_item_slot(item)
    remove_item_from_slot(slot)

func remove_item_from_slot(slot: ItemSlot):
    if not slot.item:
        return

    if slot.quantity == 1:
        slot.item = null
    else:
        slot.quantity -= 1
        
    UpdatedInventory.emit()
    UpdatedSlot.emit(slot)

func get_item_slot(item: ItemData) -> ItemSlot:
    for slot in item_slots:
        if slot.item == item:
            return slot
            
    return null

func get_empty_item_slot() -> ItemSlot:
    for slot in item_slots:
        if slot.item == null:
            return slot

    return null

func has_item(item: ItemData) -> bool:
    for slot in item_slots:
        if slot.item == item:
            return true

    return false
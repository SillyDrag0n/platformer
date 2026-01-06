class_name Inventory
extends Node

class ItemSlot:
    var item: ItemData
    var quantity: int

signal UpdatedInventory
signal UpdatedSlot (slot: ItemSlot)

var item_slots: Array[ItemSlot]

@export var size : int = 9
@export var start_items: Dictionary[ItemData, int]

func _ready():
    pass

func add_item(item: ItemData) -> bool:
    var slot : ItemSlot = get_item_slot(item)

    if slot and slot.quantity < item.max_stack_size:
        slot.quantity += 1
        
    return false

func remove_item(item: ItemData):
    pass

func remove_item_from_slot(slot: ItemSlot):
    pass

func get_item_slot(item: ItemData) -> ItemSlot:
    return null

func get_empty_item_slot() -> ItemSlot:
    return null

func has_item(item: ItemData) -> bool:
    return false
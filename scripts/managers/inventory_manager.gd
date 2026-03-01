extends Node

signal UpdatedInventory

var size: int = 20
var start_items: Dictionary[ItemData, int]

# PURE DATA (no nodes)
var item_slots: Array = []

func _ready():
    initialize_inventory()

func initialize_inventory():
    item_slots.clear()

    # create empty slots
    for i in range(size):
        item_slots.append({
            "item": null,
            "quantity": 0
        })

    # add start items
    for item in start_items:
        for i in range(start_items[item]):
            add_item(item)

    UpdatedInventory.emit()


func add_item(item: ItemData) -> bool:
    var slot_index = get_item_slot_index(item)

    # stack if possible
    if slot_index != -1:
        var slot = item_slots[slot_index]
        if slot["quantity"] < item.max_stack_size:
            slot["quantity"] += 1
            UpdatedInventory.emit()
            return true

    # otherwise find empty slot
    slot_index = get_empty_slot_index()
    if slot_index == -1:
        return false

    item_slots[slot_index]["item"] = item
    item_slots[slot_index]["quantity"] = 1

    UpdatedInventory.emit()
    return true


func remove_item(item: ItemData):
    var slot_index = get_item_slot_index(item)
    if slot_index == -1:
        return

    var slot = item_slots[slot_index]

    if slot["quantity"] <= 1:
        slot["item"] = null
        slot["quantity"] = 0
    else:
        slot["quantity"] -= 1

    UpdatedInventory.emit()


func get_item_slot_index(item: ItemData) -> int:
    for i in range(item_slots.size()):
        if item_slots[i]["item"] == item:
            return i
    return -1


func get_empty_slot_index() -> int:
    for i in range(item_slots.size()):
        if item_slots[i]["item"] == null:
            return i
    return -1
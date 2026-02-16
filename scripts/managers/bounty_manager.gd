extends Node

# All BountyData resources assigned in inspector
@export var all_bounties: Array[BountyData]

# Runtime lookup
var bounty_lookup: Dictionary = {}

# Progress data (this is what gets saved)
var bounty_progress: Dictionary = {}

# Currently selected bounty
var current_bounty_id: String = ""

signal bounty_unlocked(id: String)
signal bounty_completed(id: String)
signal bounty_selected(id: String)

func _ready():
    _build_lookup()
    _initialize_progress()

func _build_lookup():
    bounty_lookup.clear()
    for bounty in all_bounties:
        bounty_lookup[bounty.id] = bounty

func _initialize_progress():
    for bounty in all_bounties:
        if not bounty_progress.has(bounty.id):
            bounty_progress[bounty.id] = {
                "completed": false,
                "unlocked": bounty.requires.is_empty() # root nodes auto unlock
            }

func select_bounty(id: String) -> bool:
    if not is_unlocked(id):
        return false
    
    current_bounty_id = id
    bounty_selected.emit(id)
    return true

func complete_current_bounty():
    if current_bounty_id == "":
        return
    
    complete_bounty(current_bounty_id)
    current_bounty_id = ""

func complete_bounty(id: String):
    if not bounty_lookup.has(id):
        return
    
    bounty_progress[id]["completed"] = true
    bounty_completed.emit(id)

    _check_unlocks(id)

func _check_unlocks(completed_id: String):
    var completed_bounty: BountyData = bounty_lookup[completed_id]

    for unlocked_id in completed_bounty.unlocks:
        if _requirements_met(unlocked_id):
            if not is_unlocked(unlocked_id):
                bounty_progress[unlocked_id]["unlocked"] = true
                bounty_unlocked.emit(unlocked_id)

func _requirements_met(id: String) -> bool:
    var bounty: BountyData = bounty_lookup[id]
    
    for req in bounty.requires:
        if not bounty_progress[req]["completed"]:
            return false
    return true

func is_completed(id: String) -> bool:
    return bounty_progress.has(id) and bounty_progress[id]["completed"]

func is_unlocked(id: String) -> bool:
    return bounty_progress.has(id) and bounty_progress[id]["unlocked"]

func get_unlocked_bounties() -> Array:
    var result: Array = []
    
    for id in bounty_progress.keys():
        if bounty_progress[id]["unlocked"]:
            result.append(bounty_lookup[id])
    
    return result

func get_bounty_data(id: String) -> BountyData:
    return bounty_lookup.get(id)

func load_current_level():
    if current_bounty_id == "":
        return
    
    var bounty: BountyData = bounty_lookup[current_bounty_id]
    get_tree().change_scene_to_packed(bounty.level_scene)

func load_progress(data: Dictionary):
    bounty_progress = data["bounty_progress"]

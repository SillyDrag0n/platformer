extends Node

@export var all_bounties: Array[BountyData] = []

var bounty_dict: Dictionary = {}
var active_bounty: BountyData = null


func _ready():
    _initialize_bounties()


func _initialize_bounties():
    bounty_dict.clear()

    for bounty in all_bounties:
        bounty_dict[bounty.id] = bounty

    for bounty in all_bounties:
        if bounty.requires.is_empty():
            bounty.unlocked = true


func get_available_bounties() -> Array[BountyData]:
    var result: Array[BountyData] = []

    for bounty in bounty_dict.values():
        if bounty.is_available():
            result.append(bounty)
    return result


func get_active_bounty() -> BountyData:
    return active_bounty


func should_spawn_boss(current_scene: PackedScene) -> bool:
    if active_bounty == null:
        return false
    return active_bounty.level_scene == current_scene


func get_active_boss_scene() -> PackedScene:
    if active_bounty == null:
        return null
    return active_bounty.boss_scene


func accept_bounty(id: String) -> void:
    if not bounty_dict.has(id):
        push_warning("Bounty not found: " + id)
        return

    var bounty = bounty_dict[id]
    if bounty.completed:
        return
        
    active_bounty = bounty


func complete_active_bounty():
    if active_bounty == null:
        return

    active_bounty.completed = true
    _process_unlocks(active_bounty)
    active_bounty = null


func _process_unlocks(bounty: BountyData):
    for unlock_id in bounty.unlocks:
        if bounty_dict.has(unlock_id):
            bounty_dict[unlock_id].unlocked = true

    for other in bounty_dict.values():
        if not other.unlocked and _requirements_met(other):
            other.unlocked = true


func _requirements_met(bounty: BountyData) -> bool:
    for req_id in bounty.requires:
        if not bounty_dict.has(req_id):
            return false

        if not bounty_dict[req_id].completed:
            return false
    return true
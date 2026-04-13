extends Node

@export var bounties: Array[BountyData]
@export var regions: Array[RegionData]

var _bounty_lookup: Dictionary = {}
var _region_lookup: Dictionary = {}

var active_bounty: BountyData = null
var current_region: String = ""


func _ready():
	_build_lookups()


func _build_lookups():
	_bounty_lookup.clear()
	_region_lookup.clear()

	for bounty in bounties:
		_bounty_lookup[bounty.id] = bounty

	for region in regions:
		_region_lookup[region.id] = region
	

func is_region_unlocked(region_id: String) -> bool:
	if _region_lookup.has(region_id):
		return _region_lookup[region_id].unlocked
	return false


func unlock_region(region_id: String):
	if _region_lookup.has(region_id):
		_region_lookup[region_id].unlocked = true


func get_unlocked_regions() -> Array[RegionData]:
	var result: Array[RegionData] = []
	for region in regions:
		if region.unlocked:
			result.append(region)
	return result

func get_bounty_by_id(id: String) -> BountyData:
	if _bounty_lookup.has(id):
		return _bounty_lookup[id]
	return null


func get_bounties_for_region(region_id: String) -> Array[BountyData]:
	var result: Array[BountyData] = []

	for bounty in bounties:
		if bounty.region_id == region_id:
			result.append(bounty)

	return result


func unlock_bounty(id: String):
	var bounty = get_bounty_by_id(id)
	if bounty:
		bounty.unlocked = true


func complete_bounty(id: String):
	var bounty = get_bounty_by_id(id)
	if bounty:
		bounty.completed = true


func complete_active_bounty():
	var bounty = active_bounty
	if bounty:
		bounty.completed = true


func is_bounty_unlocked(id: String) -> bool:
	var bounty = get_bounty_by_id(id)
	return bounty != null and bounty.unlocked


func is_bounty_completed(id: String) -> bool:
	var bounty = get_bounty_by_id(id)
	return bounty != null and bounty.completed


func set_active_bounty(bounty: BountyData):
	active_bounty = bounty


func load_active_bounty_level():
	if active_bounty and active_bounty.level_scene:
		get_tree().change_scene_to_packed(active_bounty.level_scene)


func clear_active_bounty():
	active_bounty = null

extends Node

signal bounty_unlocked(bounty: BountyData)
signal bounty_completed(bounty: BountyData)
signal region_unlocked(region: RegionData)

@export var bounties: Array[BountyData]
@export var regions: Array[RegionData]

var _bounty_lookup: Dictionary = {}
var _region_lookup: Dictionary = {}

var active_bounty: BountyData = null

# Gates WelcomeNPC's auto-greet timer (see npc/welcome_npc.gd) - without this, re-entering the
# Hub before ever talking to him restarts _ready() and re-arms the timer every time, forcing the
# greeting on every hub spawn-in instead of just the first. Persisted by SaveManager so it also
# stays suppressed across a full game restart, not just within one session.
var has_shown_hub_welcome: bool = false


func _ready():
	_build_lookups()


func _build_lookups():
	_bounty_lookup.clear()
	_region_lookup.clear()

	for bounty in bounties:
		_bounty_lookup[bounty.id] = bounty

	for region in regions:
		_region_lookup[region.id] = region
	

func get_region_by_id(id: String) -> RegionData:
	if _region_lookup.has(id):
		return _region_lookup[id]
	return null


func is_region_unlocked(region_id: String) -> bool:
	if _region_lookup.has(region_id):
		return _region_lookup[region_id].unlocked
	return false


func unlock_region(region_id: String):
	if _region_lookup.has(region_id):
		var region = _region_lookup[region_id]
		region.unlocked = true
		region_unlocked.emit(region)


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


func get_unlocked_bounties() -> Array[BountyData]:
	var result: Array[BountyData] = []

	for bounty in bounties:
		if bounty.unlocked:
			result.append(bounty)

	return result


func unlock_bounty(id: String):
	var bounty = get_bounty_by_id(id)
	if bounty:
		bounty.unlocked = true
		bounty_unlocked.emit(bounty)


func complete_bounty(id: String):
	var bounty = get_bounty_by_id(id)
	if bounty:
		bounty.completed = true
		bounty_completed.emit(bounty)
		_unlock_dependent_bounties(bounty.id)


func complete_active_bounty():
	var bounty = active_bounty
	if bounty:
		bounty.completed = true
		bounty_completed.emit(bounty)
		_unlock_dependent_bounties(bounty.id)


# Bounties can declare a requires_bounty_id prerequisite (e.g. the Sand Spirit bounty only
# becomes available once the tutorial bounty is done) - checked here rather than at board/journal
# display time so completion, not just region unlock, is what dependent bounties key off.
func _unlock_dependent_bounties(completed_bounty_id: String) -> void:
	for bounty in bounties:
		if bounty.requires_bounty_id == completed_bounty_id and not bounty.unlocked:
			unlock_bounty(bounty.id)


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
		SceneManager.transition_to_packed_scene(active_bounty.level_scene)


func clear_active_bounty():
	active_bounty = null


func give_bounty_reward():
	if active_bounty == null:
		return

	if active_bounty.completed == false:
		return

	if active_bounty.reward_claimed == true:
		return

	active_bounty.reward_claimed = true
	for reward in active_bounty.rewards:
		InventoryManager.add_item(reward)
	for ability in active_bounty.ability_rewards:
		AbilityManager.unlock_ability(ability)
	SaveManager.save_game()
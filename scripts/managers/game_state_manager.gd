extends Node

signal bounty_unlocked(bounty: BountyData)
signal bounty_completed(bounty: BountyData)
# A single line ticked off the bounty's checklist, and the leg of the job it finished. The
# inventory's Bounties tab listens to both so the page updates while the player is out working.
signal bounty_objective_completed(bounty: BountyData, objective: BountyObjectiveData)
signal bounty_stage_completed(bounty: BountyData, stage: BountyStageData)
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

# Gates the tutorial's cactus coyote encounter (see
# levels/farm_house_backyard/coyote_encounter.gd) - same reasoning as has_shown_hub_welcome above:
# without this, re-entering the backyard after already running the coyote off would stage the whole
# fight again. Set on the coyote actually fleeing rather than on the fight starting, since this one
# can be lost.
var has_driven_off_coyote: bool = false


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


# Takes the player to the leg of the job they are actually on, so accepting a part-finished bounty
# picks up where they left off instead of replaying its first level.
func load_active_bounty_level():
	if active_bounty == null:
		return
	var scene : PackedScene = active_bounty.get_current_level_scene()
	if scene != null:
		SceneManager.transition_to_packed_scene(scene)


# Ticks one line off a bounty's checklist. Idempotent, so a level re-entered (or an NPC talked to
# twice) can call it again without disturbing progress. Finishing the last objective finishes the
# bounty itself - a staged bounty has no other completion condition.
func complete_objective(bounty_id: String, objective_id: String) -> void:
	var bounty := get_bounty_by_id(bounty_id)
	if bounty == null:
		return
	var objective := bounty.find_objective(objective_id)
	if objective == null or objective.completed:
		return

	objective.completed = true
	bounty_objective_completed.emit(bounty, objective)

	var stage := bounty.find_stage_for_objective(objective_id)
	if stage != null and stage.is_complete():
		bounty_stage_completed.emit(bounty, stage)

	if bounty.all_objectives_complete() and not bounty.completed:
		complete_bounty(bounty.id)


func is_objective_completed(bounty_id: String, objective_id: String) -> bool:
	var bounty := get_bounty_by_id(bounty_id)
	if bounty == null:
		return false
	var objective := bounty.find_objective(objective_id)
	return objective != null and objective.completed


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
	if active_bounty.reward_dollars > 0:
		CollectibleManager.give_pickup_award(active_bounty.reward_dollars)
	for reward in active_bounty.rewards:
		InventoryManager.add_item(reward)
	for ability in active_bounty.ability_rewards:
		AbilityManager.unlock_ability(ability)
	SaveManager.save_game()
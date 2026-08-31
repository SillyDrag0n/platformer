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

# One-off things the world remembers: a conversation that has happened, a beat that has played, a
# creature that has been run off. Every one of these is the same shape - set once, checked on the
# way in, and persisted - so they live in one dictionary rather than as a field each. A field each
# meant a new story beat had to be added here, to SaveDataResource, and to both halves of
# SaveManager before it would survive a restart; with this, a beat calls set_story_flag() and is
# saved for free.
#
# Keys are the ids below rather than free-form strings, so a typo is a missing constant rather
# than a flag that silently never matches.
var story_flags : Dictionary = {}

# Gates WelcomeNPC's auto-greet timer (see npc/welcome_npc.gd) - without this, re-entering the
# Hub before ever talking to him restarts _ready() and re-arms the timer every time, forcing the
# greeting on every hub spawn-in instead of just the first.
const FLAG_HUB_WELCOME_SHOWN := &"hub_welcome_shown"

# Gates the tutorial's cactus coyote encounter (see
# levels/farm_house_backyard/coyote_encounter.gd), and retires the hub's tutorial furniture (see
# levels/hub_level.gd). Without it, re-entering the backyard after already running the coyote off
# would stage the whole fight again. Set on the coyote actually fleeing rather than on the fight
# starting, since this one can be lost.
const FLAG_COYOTE_DRIVEN_OFF := &"coyote_driven_off"


func _ready():
	_build_lookups()


func _build_lookups():
	_bounty_lookup.clear()
	_region_lookup.clear()

	for bounty in bounties:
		_bounty_lookup[bounty.id] = bounty

	for region in regions:
		_region_lookup[region.id] = region


# Records that a story beat has happened. Idempotent by nature - a beat that plays twice sets the
# same flag twice - and `false` is a real value, so a beat can be un-done if a level ever needs to.
func set_story_flag(flag : StringName, value : bool = true) -> void:
	story_flags[String(flag)] = value


func has_story_flag(flag : StringName) -> bool:
	return story_flags.get(String(flag), false)


func get_region_by_id(id: String) -> RegionData:
	return _region_lookup.get(id)


# The write side of the region gate. Nothing calls it yet - the Plains are unlocked from the
# start and the Mountains/Swamp have no content behind them - but it is what the journal's region
# headers already listen for, so it stays as the one place a region opens up.
func unlock_region(region_id: String) -> void:
	var region : RegionData = get_region_by_id(region_id)
	if region == null or region.unlocked:
		return
	region.unlocked = true
	region_unlocked.emit(region)


func get_bounty_by_id(id: String) -> BountyData:
	return _bounty_lookup.get(id)


func get_bounties_for_region(region_id: String) -> Array[BountyData]:
	return _filter_bounties(func(bounty : BountyData): return bounty.region_id == region_id)


func get_unlocked_bounties() -> Array[BountyData]:
	return _filter_bounties(func(bounty : BountyData): return bounty.unlocked)


func _filter_bounties(predicate : Callable) -> Array[BountyData]:
	var result: Array[BountyData] = []
	for bounty in bounties:
		if predicate.call(bounty):
			result.append(bounty)
	return result


func unlock_bounty(id: String) -> void:
	var bounty := get_bounty_by_id(id)
	if bounty == null or bounty.unlocked:
		return
	bounty.unlocked = true
	bounty_unlocked.emit(bounty)


func complete_bounty(id: String) -> void:
	_complete(get_bounty_by_id(id))


func complete_active_bounty() -> void:
	# Deliberately the object rather than a lookup by its id: the active bounty is whatever was
	# handed to set_active_bounty(), which needn't be one of the authored `bounties`.
	_complete(active_bounty)


func _complete(bounty : BountyData) -> void:
	if bounty == null or bounty.completed:
		return
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
	var bounty := get_bounty_by_id(id)
	return bounty != null and bounty.unlocked


func set_active_bounty(bounty: BountyData) -> void:
	active_bounty = bounty


# Takes the player to the leg of the job they are actually on, so accepting a part-finished bounty
# picks up where they left off instead of replaying its first level.
func load_active_bounty_level() -> void:
	if active_bounty == null:
		return
	var scene : PackedScene = active_bounty.get_current_level_scene()
	if scene == null:
		# Nothing to load means the player accepted a contract off the board and then stayed on it,
		# poster already torn off, with no way forward - so say why rather than failing silently.
		push_warning("GameStateManager: bounty '%s' has no level for its current stage - " % active_bounty.id + \
			"set level_scene on the stage (or on the bounty, for a single-level job).")
		return
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

	if bounty.all_objectives_complete():
		_complete(bounty)


func is_objective_completed(bounty_id: String, objective_id: String) -> bool:
	var bounty := get_bounty_by_id(bounty_id)
	if bounty == null:
		return false
	var objective := bounty.find_objective(objective_id)
	return objective != null and objective.completed


func clear_active_bounty() -> void:
	active_bounty = null


# Pays out once, and only for a contract that is actually finished. reward_claimed is what keeps
# a second turn-in conversation from handing the rewards over twice.
func give_bounty_reward() -> void:
	if active_bounty == null or not active_bounty.completed or active_bounty.reward_claimed:
		return

	active_bounty.reward_claimed = true
	if active_bounty.reward_dollars > 0:
		CollectibleManager.give_pickup_award(active_bounty.reward_dollars)
	for reward in active_bounty.rewards:
		InventoryManager.add_item(reward)
	for ability in active_bounty.ability_rewards:
		AbilityManager.unlock_ability(ability)
	SaveManager.save_game()
extends Resource
class_name BountyData

@export var id: String
@export var title: String
@export var region_id: String
@export_multiline var description: String
@export var icon: Texture2D

# If set, GameStateManager only auto-unlocks this bounty once the bounty with this id completes.
@export var requires_bounty_id: String = ""

@export var unlocked: bool = false
@export var completed: bool = false
@export var reward_claimed: bool = false

@export var map_position: Vector2

# What the contract pays out, in dollars, on top of any reward items below.
@export var reward_dollars: int = 0

# The legs of the job, in order - a bounty like Missing Cattle is one contract played across
# three levels (investigate -> seek the shaman -> hunt), each with its own objectives. A bounty
# with no stages is a single-level job and falls back on level_scene below.
@export var stages: Array[BountyStageData] = []

@export var level_scene: PackedScene
@export var boss_scene: PackedScene
@export var rewards: Array[ItemData]
@export var ability_rewards: Array[AbilityData]


func get_status_text() -> String:
	if completed:
		return "Completed"
	if not unlocked:
		return "Locked"
	if completed_objective_count() > 0:
		return "In Progress"
	return "Available"


# The leg the player is on: the first stage with anything left to do. Null once every objective is
# ticked off, and for a bounty that has no stages at all.
func get_current_stage() -> BountyStageData:
	for stage in stages:
		if not stage.is_complete():
			return stage
	return null


func get_current_stage_index() -> int:
	for i in stages.size():
		if not stages[i].is_complete():
			return i
	return stages.size()


# Where accepting this bounty takes the player: the level for the leg they are actually on, or the
# bounty's own level for the single-level jobs that predate stages.
func get_current_level_scene() -> PackedScene:
	var stage := get_current_stage()
	if stage != null and stage.level_scene != null:
		return stage.level_scene
	return level_scene


func find_objective(objective_id : String) -> BountyObjectiveData:
	for stage in stages:
		var objective := stage.find_objective(objective_id)
		if objective != null:
			return objective
	return null


func find_stage_for_objective(objective_id : String) -> BountyStageData:
	for stage in stages:
		if stage.find_objective(objective_id) != null:
			return stage
	return null


func objective_count() -> int:
	var count := 0
	for stage in stages:
		count += stage.objectives.size()
	return count


func completed_objective_count() -> int:
	var count := 0
	for stage in stages:
		count += stage.completed_objective_count()
	return count


# True only for a staged bounty whose every objective is done - a bounty with no stages is never
# finished this way, since nothing would ever tick it off.
func all_objectives_complete() -> bool:
	if stages.is_empty():
		return false
	for stage in stages:
		if not stage.is_complete():
			return false
	return true

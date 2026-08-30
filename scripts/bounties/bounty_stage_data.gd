class_name BountyStageData
extends Resource

# One leg of a bounty - "Investigate the Missing Cattle", "Seek the Shaman", "Hunt the Creature".
# A bounty is the contract the player takes; its stages are the levels they play to see it through,
# each with its own handful of objectives.
#
# The level is held per stage rather than per bounty, so accepting a bounty that's already part-way
# through drops the player into the leg they're actually on (see BountyData.get_current_stage()).

@export var id : String
@export var title : String
@export_multiline var description : String
@export var objectives : Array[BountyObjectiveData] = []
@export var level_scene : PackedScene


func is_complete() -> bool:
	for objective in objectives:
		if not objective.completed:
			return false
	return true


func is_started() -> bool:
	for objective in objectives:
		if objective.completed:
			return true
	return false


func completed_objective_count() -> int:
	var count := 0
	for objective in objectives:
		if objective.completed:
			count += 1
	return count


func find_objective(objective_id : String) -> BountyObjectiveData:
	for objective in objectives:
		if objective.id == objective_id:
			return objective
	return null

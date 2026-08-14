extends Resource
class_name BountyData

@export var id: String
@export var title: String
@export var region_id: String
@export_multiline var description: String
@export var icon: Texture2D

@export var unlocked: bool = false
@export var completed: bool = false
@export var reward_claimed: bool = false

@export var map_position: Vector2
@export var level_scene: PackedScene
@export var boss_scene: PackedScene
@export var rewards: Array[ItemData]
@export var ability_rewards: Array[AbilityData]


func get_status_text() -> String:
	if completed:
		return "Completed"
	if unlocked:
		return "Available"
	return "Locked"
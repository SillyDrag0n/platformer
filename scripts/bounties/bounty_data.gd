extends Resource
class_name BountyData

@export_group("Core")
@export var id: String
@export var title: String
@export var description: String
@export var level_scene: PackedScene
@export var boss_scene: PackedScene
@export var reward: int = 0

@export_group("UI")
@export var picture: Texture2D
@export_multiline var rumor_text: String
@export var difficulty: int = 1

@export_group("Progression")
@export var unlocks: Array[String] = []
@export var requires: Array[String] = []

var unlocked: bool = false
var completed: bool = false

func is_available() -> bool:
    return unlocked and not completed
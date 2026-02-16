extends Resource
class_name BountyData

@export_group("Core")
@export var id: String
@export var title: String
@export var level_scene: PackedScene
@export var boss_scene: PackedScene


@export_group("UI")
@export var symbol_texture: Texture2D
@export_multiline var rumor_text: String
@export var difficulty: int = 1


@export_group("Branching")
@export var unlocks: Array[String] = []
@export var requires: Array[String] = []
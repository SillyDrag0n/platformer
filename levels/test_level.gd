extends Node2D

@export var camera: Camera2D
@export var respawn_marker: Marker2D
@export var player: CharacterBody2D
@export var level_id : String


func _ready():
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)
	if BountyManager.should_spawn_boss():
		spawn_boss()


func setPlayerInstance(playerInstance: CharacterBody2D):
	player = playerInstance


func _on_death_zone_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		player.player_death()


func spawn_boss():
	var boss_scene = BountyManager.get_active_boss_scene()
	var boss = boss_scene.instantiate()
	add_child(boss)
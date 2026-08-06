extends Node2D

@export var camera: Camera2D
@export var respawn_marker: Marker2D
@export var boss_spawn_marker: Marker2D
@export var boss_arena: BossArena
@export var player: CharacterBody2D
@export var level_id : String

		
func _ready():
	await get_tree().process_frame
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)
	spawn_boss()


func set_player_instance(player_instance: CharacterBody2D):
	player = player_instance


func _on_death_zone_body_entered(body:Node2D) -> void:
	if body.is_in_group("Player"):
		player.player_death()


func spawn_boss():
	if GameStateManager.active_bounty == null:
		return

	var boss_scene = GameStateManager.active_bounty.boss_scene
	if boss_scene == null:
		return

	var boss_instance = boss_scene.instantiate()
	boss_instance.global_position = boss_spawn_marker.global_position
	add_child(boss_instance)
	boss_arena.boss = boss_instance


func on_boss_defeated():
	GameStateManager.complete_active_bounty()
	GameStateManager.clear_active_bounty()
	get_tree().change_scene_to_file("res://levels/hub_level.tscn")

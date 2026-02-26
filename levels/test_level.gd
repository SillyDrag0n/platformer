extends Node2D

@export var camera: Camera2D
@export var respawn_marker: Marker2D
@export var boss_spawn_marker: Marker2D
@export var player: CharacterBody2D
@export var level_id : String

		
func _ready():
	await get_tree().process_frame
	RespawnManager.set_respawn_nodes(camera, respawn_marker, self)
	spawn_boss()


func setPlayerInstance(playerInstance: CharacterBody2D):
	player = playerInstance


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

	var spawn_point = get_node("BossSpawn")
	boss_instance.global_position = spawn_point.global_position

	add_child(boss_instance)


func on_boss_defeated():
	GameStateManager.complete_bounty(GameStateManager.active_bounty_id)
	GameStateManager.clear_active_bounty()
	get_tree().change_scene_to_file("res://levels/hub_level.tscn")

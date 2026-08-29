extends GutTest

# Regression coverage for two related bugs in the hub's death/respawn flow:
# 1. hub_level.gd never called RespawnManager.set_respawn_nodes(), so respawning crashed on a
#    null (then, once that was fixed, stale/freed) respawn_marker.
# 2. RespawnManager.respawn() parented the new player under its own parent (the SceneTree root,
#    since RespawnManager is an autoload) instead of under current_level - the respawned player
#    was never actually a child of the level whose "player" reference had just been updated to it.

const HubLevelScene = preload("res://levels/hub_level.tscn")

var hub


func after_each():
	if is_instance_valid(hub):
		hub.queue_free()


func _spawn_hub_and_kill_player() -> void:
	hub = HubLevelScene.instantiate()
	get_tree().get_root().add_child(hub)
	await wait_physics_frames(2)

	hub.player.player_death()
	# player_death() awaits DEATH_POSE_DURATION (0.5s) before freeing itself and emitting player_died.
	await wait_seconds(0.7)


func test_death_then_respawn_in_hub_does_not_crash():
	await _spawn_hub_and_kill_player()

	RespawnManager.respawn()

	assert_true(true, "reached this line without a script error/crash")


func test_respawn_updates_hub_level_player_to_the_new_instance_and_parents_it_there():
	await _spawn_hub_and_kill_player()
	var old_player = hub.player

	RespawnManager.respawn()
	await wait_physics_frames(2)

	assert_ne(hub.player, old_player, \
		"hub.player should be updated to the newly-spawned player, not still the dead one")
	assert_true(is_instance_valid(hub.player), "the new player should be alive")
	assert_eq(hub.player.get_parent(), hub, \
		"the new player should be parented under the hub level, same as the scene-authored one, " + \
		"not left as a sibling of it under the SceneTree root")


func test_calling_respawn_twice_in_a_row_does_not_crash():
	await _spawn_hub_and_kill_player()

	RespawnManager.respawn()
	RespawnManager.respawn()

	assert_true(true, "reached this line without a script error/crash")


func test_second_death_and_respawn_cycle_does_not_crash():
	await _spawn_hub_and_kill_player()
	RespawnManager.respawn()
	await wait_physics_frames(2)

	hub.player.player_death()
	await wait_seconds(0.7)
	RespawnManager.respawn()

	assert_true(true, "reached this line without a script error/crash")

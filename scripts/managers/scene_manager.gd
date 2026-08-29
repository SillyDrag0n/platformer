extends Node

var scene_transition_screen = preload("res://ui/screen_transition/scene_transition_screen.tscn")
var fade_transition_screen = preload("res://ui/screen_transition/FadeTransitionScreen.tscn")

var scenes : Dictionary = { "Level1": "res://levels/test_level.tscn",
							"Hub": "res://levels/hub_level.tscn",
							"Saloon": "res://levels/saloon_interior/saloon_interior.tscn",
							"ArmsDealer": "res://levels/arms_dealer_interior/arms_dealer_interior.tscn",
							"SheriffsOffice": "res://levels/sheriffs_office_interior/sheriffs_office_interior.tscn",
							"Bank": "res://levels/bank_interior/bank_interior.tscn",
							"PostOffice": "res://levels/post_office_interior/post_office_interior.tscn",
							"FarmHouseBackyard": "res://levels/farm_house_backyard/farm_house_backyard.tscn" }

# Lets a scene the player is about to leave (e.g. walking into a building) tell whichever scene
# they arrive in (e.g. that building's interior) - or, on the way back out, tell the Hub - where
# to actually place the player, instead of always falling back to that scene's fixed start spot.
var pending_spawn_position : Vector2 = Vector2.ZERO
var has_pending_spawn_position : bool = false


func set_pending_spawn_position(spawn_position : Vector2) -> void:
	pending_spawn_position = spawn_position
	has_pending_spawn_position = true


func consume_pending_spawn_position() -> Vector2:
	has_pending_spawn_position = false
	return pending_spawn_position


func transition_to_scene(level : String):
	var scene_path : String = scenes.get(level)
	if scene_path != null:
		await _play_loading_transition(scene_path)


# Bounty levels are held directly as PackedScene resources (BountyData.level_scene) rather than
# through the scenes-by-name lookup above, so this takes the resource itself but reuses the same
# dissolve "LOADING" screen used for other heavy scene loads.
func transition_to_packed_scene(scene: PackedScene) -> void:
	if scene == null:
		return
	await _play_loading_transition(scene)


func _play_loading_transition(scene) -> void:
	var scene_transition_screen_instance = scene_transition_screen.instantiate()
	get_tree().get_root().add_child(scene_transition_screen_instance)
	await get_tree().create_timer(2.5).timeout
	if scene is PackedScene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(scene)
	scene_transition_screen_instance.queue_free()


# Quick fade-to-black transition for short interior hops (Hub <-> Saloon/Arms Dealer) that don't
# need the longer dissolve-shader loading screen used for heavier scene loads.
func transition_to_scene_faded(level : String) -> void:
	var scene_path : String = scenes.get(level)
	if scene_path == null:
		return

	var fade_instance = fade_transition_screen.instantiate()
	get_tree().get_root().add_child(fade_instance)

	await fade_instance.fade_out()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_instance.fade_in()

	fade_instance.queue_free()

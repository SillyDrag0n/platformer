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
							"FarmHouseInterior": "res://levels/farm_house_interior/farm_house_interior.tscn",
							# The tutorial level out behind the farm house. Reached by taking the
							# Missing Cattle contract off the board, not by walking into the house
							# in town - that leads to FarmHouseInterior above.
							"FarmHouseBackyard": "res://levels/farm_house_backyard/farm_house_backyard.tscn" }

# Lets a scene the player is about to leave (e.g. walking into a building) tell whichever scene
# they arrive in (e.g. that building's interior) - or, on the way back out, tell the Hub - where
# to actually place the player, instead of always falling back to that scene's fixed start spot.
#
# The position is a spot in one particular level, so it is tagged with the level it was recorded in
# and only ever handed back there. Without that tag a leftover value gets applied to whatever level
# happens to ask next: the backyard's farm house carries the hub door's script, so interacting with
# it recorded a backyard position that the Hub then used on arrival - dropping the player at
# coordinates with no ground under them, out of frame, while the level itself looked fine.
var pending_spawn_position : Vector2 = Vector2.ZERO
var has_pending_spawn_position : bool = false
var pending_spawn_scene_key : String = ""


# scene_key defaults to whichever level is running - the caller is a structure standing in it, so
# that is the level the position belongs to.
func set_pending_spawn_position(spawn_position : Vector2, scene_key : String = "") -> void:
	pending_spawn_position = spawn_position
	pending_spawn_scene_key = scene_key if scene_key != "" else get_current_scene_key()
	has_pending_spawn_position = true


func has_pending_spawn_position_for(scene_key : String) -> bool:
	return has_pending_spawn_position and pending_spawn_scene_key == scene_key


func consume_pending_spawn_position() -> Vector2:
	has_pending_spawn_position = false
	pending_spawn_scene_key = ""
	return pending_spawn_position


# The key this level is listed under above, so a position can be tied to it. Falls back to the
# scene's own path for anything not in the table (a bounty level, say), which still tells two
# different levels apart.
func get_current_scene_key() -> String:
	var current : Node = get_tree().current_scene
	if current == null:
		return ""
	for key in scenes:
		if scenes[key] == current.scene_file_path:
			return key
	return current.scene_file_path


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


# Fade to black, do something, fade back in - all within the scene the player is already in. The
# transitions above are all scene changes; this is for a scripted beat that moves the player
# somewhere else in the same level (the tutorial's farmer debrief, so far) and wants the cut to
# read as time passing rather than as a teleport. `during` runs while the screen is fully black.
func play_fade_beat(during : Callable, hold_seconds : float = 0.5) -> void:
	var fade_instance = fade_transition_screen.instantiate()
	get_tree().get_root().add_child(fade_instance)

	await fade_instance.fade_out()
	if during.is_valid():
		during.call()
	if hold_seconds > 0.0:
		await get_tree().create_timer(hold_seconds).timeout
	await fade_instance.fade_in()

	fade_instance.queue_free()


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

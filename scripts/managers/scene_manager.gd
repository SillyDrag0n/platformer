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


# The ride-out screen (ui/screen_transition/scene_transition_screen.gd): the rider crosses the
# trail as the level loads. Where there is a real load to measure - a scene named by path - it is
# streamed on a background thread and the bar reports what the engine actually says. A PackedScene
# handed in directly (a bounty's level_scene) is already in memory, so there is nothing to measure
# and the ride just plays out over its minimum.
func _play_loading_transition(scene) -> void:
	var screen = scene_transition_screen.instantiate()
	get_tree().get_root().add_child(screen)

	if scene is PackedScene:
		await screen.ride(func(): return 1.0)
		get_tree().change_scene_to_packed(scene)
		screen.queue_free()
		return

	var loaded : PackedScene = await _ride_while_loading(screen, scene)
	if loaded != null:
		get_tree().change_scene_to_packed(loaded)
	else:
		# Threaded loading refused the path outright. Fall back to the blocking load rather than
		# leaving the player on a loading screen for a level that was never going to arrive.
		get_tree().change_scene_to_file(scene)
	screen.queue_free()


func _ride_while_loading(screen, scene_path : String) -> PackedScene:
	if ResourceLoader.load_threaded_request(scene_path, "PackedScene") != OK:
		push_warning("SceneManager: could not stream '%s' - falling back to a blocking load." % scene_path)
		await screen.ride(func(): return 1.0)
		return null

	# load_threaded_get_status() writes a single 0..1 float into the array it is handed.
	var progress : Array = [0.0]
	await screen.ride(func():
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return 1.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return 1.0
		return float(progress[0])
	)
	return ResourceLoader.load_threaded_get(scene_path) as PackedScene


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

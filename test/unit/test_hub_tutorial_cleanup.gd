extends GutTest

# The Old Timer and the interact prompt are the hub's tutorial furniture: he exists to push the
# player at the notice board for their first job, and the hint teaches the button for it. Once the
# player has been out to Hutch's place and run the coyote off, both are spent - so hub_level.gd
# clears them away rather than leaving a town that never moved on.
#
# Gated on GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF), the same persisted flag the encounter itself
# uses to stop restaging (see levels/farm_house_backyard/coyote_encounter.gd).

const HubLevelScene = preload("res://levels/hub_level.tscn")

var _original_has_driven_off_coyote : bool
var _hub : Node


func before_each():
	_original_has_driven_off_coyote = GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF)


func after_each():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, _original_has_driven_off_coyote)
	if is_instance_valid(_hub):
		_hub.queue_free()
	_hub = null


func _spawn_hub() -> Node:
	_hub = HubLevelScene.instantiate()
	get_tree().get_root().add_child(_hub)
	# queue_free() lands at the end of the frame, so the nodes are still there for one more.
	await wait_frames(2)
	return _hub


func test_the_hub_wires_both_pieces_of_tutorial_furniture():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, false)
	var hub := await _spawn_hub()

	assert_eq(hub.tutorial_only_nodes.size(), 2, \
		"the Old Timer and the interact prompt - wired in hub_level.tscn, not looked up by name")
	assert_has(hub.tutorial_only_nodes, hub.get_node("WelcomeNPC"), "the Old Timer")
	assert_has(hub.tutorial_only_nodes, hub.get_node("HintZoneInteract"), "the interact prompt")


func test_both_are_still_there_before_the_coyote_has_been_run_off():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, false)
	var hub := await _spawn_hub()

	assert_true(hub.has_node("WelcomeNPC"), \
		"the Old Timer has to be there to hand out the first job in the first place")
	assert_true(hub.has_node("HintZoneInteract"), \
		"and the prompt teaches the button used to talk to him")


func test_both_are_gone_once_the_encounter_level_is_finished():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, true)
	var hub := await _spawn_hub()

	assert_false(hub.has_node("WelcomeNPC"), \
		"the Old Timer has said his piece - leaving him standing there reads like nothing happened")
	assert_false(hub.has_node("HintZoneInteract"), \
		"and the player has been interacting with things for a whole level by now")


# Freed rather than hidden on purpose: a hidden NPC is still an interactable the player can walk
# into, and a hidden HintZone still fires on body_entered - so "invisible" would not be enough.
func test_they_are_freed_rather_than_left_in_the_tree_hidden():
	GameStateManager.set_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF, true)
	var hub := await _spawn_hub()

	for child in hub.get_children():
		assert_false(child is WelcomeNPC, "no Old Timer left under any name")
		assert_false(child is HintZone, "no hint zone left under any name")

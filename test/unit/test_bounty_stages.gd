extends GutTest

# The Plains story is one contract - Missing Cattle - played across three legs: investigate, seek
# the shaman, hunt. What's pinned here is the shape of that contract (stages, objectives, what it
# pays), how progress moves through it, and that the Bounties tab renders the checklist the player
# reads it off. The bounty resources are shared singletons GameStateManager ticks off in place, so
# every test winds the checklist back to where it found it.

const BOUNTY_ID := "missing_cattle"
const InventoryUiScene = preload("res://ui/inventory/InventoryUI.tscn")

var _original_objectives : Dictionary
var _original_completed : bool
var _original_unlocked : bool
# Seeing the contract through completes it, and completing a bounty unlocks whatever names it as
# a prerequisite (Sand Spirit does) - so the unlock state of every bounty has to be wound back,
# not just this one.
var _original_unlocks : Dictionary


func before_each():
	var bounty := _bounty()
	_original_objectives = {}
	_original_completed = bounty.completed
	_original_unlocked = bounty.unlocked
	_original_unlocks = {}
	for other in GameStateManager.bounties:
		_original_unlocks[other.id] = other.unlocked
	bounty.completed = false
	bounty.unlocked = true
	for stage in bounty.stages:
		for objective in stage.objectives:
			_original_objectives[objective.id] = objective.completed
			objective.completed = false
	InventoryManager.is_open = false


func after_each():
	var bounty := _bounty()
	bounty.completed = _original_completed
	bounty.unlocked = _original_unlocked
	for other in GameStateManager.bounties:
		if other.id != BOUNTY_ID:
			other.unlocked = _original_unlocks.get(other.id, other.unlocked)
	for stage in bounty.stages:
		for objective in stage.objectives:
			objective.completed = _original_objectives.get(objective.id, false)
	InventoryManager.is_open = false


func _bounty() -> BountyData:
	return GameStateManager.get_bounty_by_id(BOUNTY_ID)


func _complete_stage(stage : BountyStageData) -> void:
	for objective in stage.objectives:
		GameStateManager.complete_objective(BOUNTY_ID, objective.id)


func test_the_plains_story_is_one_contract_with_three_legs():
	var bounty := _bounty()
	assert_not_null(bounty, "Missing Cattle is the contract the whole Plains arc hangs off")
	assert_eq(bounty.stages.size(), 3, \
		"investigate, seek the shaman, hunt - levels of one job rather than three bounties")
	assert_eq(bounty.reward_dollars, 250, "and it pays $250 when the whole thing is seen through")

	var titles : Array[String] = []
	for stage in bounty.stages:
		titles.append(stage.title)
		assert_eq(stage.objectives.size(), 3, "%s should list what it takes to finish it" % stage.id)
	assert_eq(titles, ["Investigate the Missing Cattle", "Seek the Shaman", "Hunt the Creature"])


func test_each_leg_knows_the_level_it_is_played_in():
	var bounty := _bounty()
	assert_not_null(bounty.stages[0].level_scene, "the investigation is the farm house backyard")
	assert_not_null(bounty.stages[1].level_scene, "and the ride out is the shaman's camp")
	assert_eq(bounty.get_current_level_scene(), bounty.stages[0].level_scene, \
		"a fresh contract sends the player to its first leg")

	_complete_stage(bounty.stages[0])
	assert_eq(bounty.get_current_level_scene(), bounty.stages[1].level_scene, \
		"and once that leg is done, accepting it again takes them on to the next one rather " + \
		"than replaying the level they finished")


func test_progress_moves_a_leg_at_a_time():
	var bounty := _bounty()
	assert_eq(bounty.get_status_text(), "Available", "nothing done yet")

	GameStateManager.complete_objective(BOUNTY_ID, "reach_attack_site")
	assert_eq(bounty.get_status_text(), "In Progress", \
		"one line ticked off is enough for the job to read as under way")
	assert_eq(bounty.get_current_stage().id, "investigate", \
		"and it stays on the leg it's on until every line of that leg is done")

	_complete_stage(bounty.stages[0])
	assert_eq(bounty.get_current_stage().id, "seek_the_shaman")
	assert_eq(bounty.completed_objective_count(), 3)
	assert_false(bounty.completed)


func test_finishing_the_last_objective_finishes_the_contract():
	var bounty := _bounty()
	for stage in bounty.stages:
		_complete_stage(stage)

	assert_true(bounty.completed, \
		"a staged bounty has no other completion condition - the last line on the checklist is it")
	assert_eq(bounty.get_status_text(), "Completed")
	assert_null(bounty.get_current_stage(), "and there's no leg left to send the player to")


func test_completing_an_objective_twice_changes_nothing():
	var bounty := _bounty()
	GameStateManager.complete_objective(BOUNTY_ID, "reach_attack_site")
	GameStateManager.complete_objective(BOUNTY_ID, "reach_attack_site")

	assert_eq(bounty.completed_objective_count(), 1, \
		"a level re-entered (or an NPC talked to twice) must not disturb progress")


func test_objective_and_stage_completion_are_announced():
	var objectives_seen : Array[String] = []
	var stages_seen : Array[String] = []
	var on_objective := func(_bounty, objective): objectives_seen.append(objective.id)
	var on_stage := func(_bounty, stage): stages_seen.append(stage.id)
	GameStateManager.bounty_objective_completed.connect(on_objective)
	GameStateManager.bounty_stage_completed.connect(on_stage)

	_complete_stage(_bounty().stages[0])

	GameStateManager.bounty_objective_completed.disconnect(on_objective)
	GameStateManager.bounty_stage_completed.disconnect(on_stage)

	assert_eq(objectives_seen, ["reach_attack_site", "encounter_creature", "creature_escapes"], \
		"the Bounties tab redraws off these, so every line has to announce itself")
	assert_eq(stages_seen, ["investigate"], "and the leg announces itself when its last line lands")


# The tab is what the player actually reads the job off, so the checklist it renders is worth
# pinning rather than just the data behind it.
func test_the_bounties_tab_shows_the_checklist():
	var bounty := _bounty()
	GameStateManager.complete_objective(BOUNTY_ID, "reach_attack_site")

	var inventory = InventoryUiScene.instantiate()
	add_child_autofree(inventory)
	await wait_frames(1)

	inventory._on_bounty_entry_selected(bounty)
	var details : String = inventory.bounty_description_label.text

	assert_string_contains(details, "Reward: $250", "what the job pays")
	assert_string_contains(details, "1. Investigate the Missing Cattle", "the legs, in order")
	assert_string_contains(details, "2. Seek the Shaman")
	assert_string_contains(details, "3. Hunt the Creature")
	assert_string_contains(details, "[x] Go to the attack site", "a line already done")
	assert_string_contains(details, "[ ] Encounter the creature", "and one still to do")
	assert_eq(inventory.bounty_status_label.text, "In Progress")
	assert_false(details.contains("Track it to its den"), \
		"a leg the player hasn't reached is named but not itemised - listing its objectives " + \
		"would give away beats they should be walking into")


func test_the_tab_follows_progress_made_while_it_is_open():
	var bounty := _bounty()
	var inventory = InventoryUiScene.instantiate()
	add_child_autofree(inventory)
	await wait_frames(1)
	inventory._on_bounty_entry_selected(bounty)

	GameStateManager.complete_objective(BOUNTY_ID, "reach_attack_site")
	await wait_frames(1)

	assert_string_contains(inventory.bounty_description_label.text, "[x] Go to the attack site", \
		"progress made out in the world updates the page rather than waiting for a reselect")
	assert_eq(inventory.bounty_title_label.text, "Missing Cattle", \
		"and the open bounty stays open instead of resetting to the pick-a-bounty state")


# A bounty the player hasn't been handed yet has no business on the journal page: the name alone
# gives away that the job exists. Reported after the Sand Spirit showed up in the inventory while
# still locked behind the Missing Cattle contract.
func test_the_journal_lists_only_bounties_that_have_been_posted():
	var sand_spirit := GameStateManager.get_bounty_by_id("1")
	sand_spirit.unlocked = false
	_bounty().unlocked = true

	var inventory = InventoryUiScene.instantiate()
	add_child_autofree(inventory)
	await wait_frames(1)

	var listed : Array[String] = []
	for child in inventory.bounty_list_container.get_children():
		if child is BountyEntry:
			listed.append(child.bounty.id)

	assert_has(listed, BOUNTY_ID, "the contract they're working is on the page")
	assert_does_not_have(listed, sand_spirit.id, \
		"and the one still to come isn't - not even greyed out")


func test_a_region_with_nothing_posted_says_so():
	for bounty in GameStateManager.bounties:
		bounty.unlocked = false

	var inventory = InventoryUiScene.instantiate()
	add_child_autofree(inventory)
	await wait_frames(1)

	var entries := 0
	var empty_notices := 0
	for child in inventory.bounty_list_container.get_children():
		if child is BountyEntry:
			entries += 1
		elif child is Label and child.text == "No bounties posted yet.":
			empty_notices += 1

	assert_eq(entries, 0, "a new save has had nothing posted to it yet")
	assert_gt(empty_notices, 0, \
		"so the Plains reads as an empty page rather than a list of jobs they can't take")

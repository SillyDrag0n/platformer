extends GutTest

# Coverage for GameStateManager's bounty-prerequisite chaining (BountyData.requires_bounty_id) -
# completing one bounty auto-unlocks any bounty that names it as a prerequisite, e.g. the
# tutorial bounty unlocking Sand Spirit. Tests that mutate GameStateManager.bounties directly
# (real singleton state) use throwaway ids and restore the array + lookup cache afterward.

const TUTORIAL_BOUNTY_ID := "tutorial_missing_cattle"
const SAND_SPIRIT_BOUNTY_ID := "1"


func test_sand_spirit_requires_the_tutorial_bounty_and_starts_locked():
	var sand_spirit = GameStateManager.get_bounty_by_id(SAND_SPIRIT_BOUNTY_ID)

	assert_not_null(sand_spirit)
	assert_eq(sand_spirit.requires_bounty_id, TUTORIAL_BOUNTY_ID)
	assert_false(sand_spirit.unlocked, \
		"Sand Spirit should start locked until the tutorial bounty is completed")


func test_completing_a_bounty_unlocks_bounties_that_require_it():
	var prereq := BountyData.new()
	prereq.id = "test_prereq"
	var dependent := BountyData.new()
	dependent.id = "test_dependent"
	dependent.requires_bounty_id = prereq.id
	dependent.unlocked = false

	GameStateManager.bounties.append(prereq)
	GameStateManager.bounties.append(dependent)
	GameStateManager._build_lookups()

	GameStateManager.complete_bounty(prereq.id)

	assert_true(dependent.unlocked, \
		"completing the prerequisite should auto-unlock the dependent bounty")

	GameStateManager.bounties.erase(prereq)
	GameStateManager.bounties.erase(dependent)
	GameStateManager._build_lookups()


func test_completing_an_unrelated_bounty_does_not_unlock_a_dependent_one():
	var prereq := BountyData.new()
	prereq.id = "test_prereq"
	var unrelated := BountyData.new()
	unrelated.id = "test_unrelated"
	var dependent := BountyData.new()
	dependent.id = "test_dependent"
	dependent.requires_bounty_id = prereq.id
	dependent.unlocked = false

	GameStateManager.bounties.append(prereq)
	GameStateManager.bounties.append(unrelated)
	GameStateManager.bounties.append(dependent)
	GameStateManager._build_lookups()

	GameStateManager.complete_bounty(unrelated.id)

	assert_false(dependent.unlocked)

	GameStateManager.bounties.erase(prereq)
	GameStateManager.bounties.erase(unrelated)
	GameStateManager.bounties.erase(dependent)
	GameStateManager._build_lookups()

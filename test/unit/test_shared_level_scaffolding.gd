extends GutTest

# The two script families that used to be copy-pasted per scene and are now shared:
#
#   levels/_common/interior_level.gd  - the eight hub building interiors
#   tileset/structures/hub_structure.gd - the nine buildings in town
#
# Both are pure wiring, so what is worth pinning is that every scene still gets that wiring, and
# that each building leads where it is supposed to. A structure's destination is a plain string
# now, which is exactly the kind of thing that goes wrong silently: a typo'd key doesn't fail to
# load, it just leaves the player interacting with a door that never opens.

const INTERIORS := [
	"res://levels/arms_dealer_interior/arms_dealer_interior.tscn",
	"res://levels/farm_house_interior/farm_house_interior.tscn",
	"res://levels/bank_interior/bank_interior.tscn",
	"res://levels/post_office_interior/post_office_interior.tscn",
	"res://levels/saloon_interior/saloon_interior.tscn",
	"res://levels/sheriffs_office_interior/sheriffs_office_interior.tscn",
	"res://levels/chapel_interior/chapel_interior.tscn",
	"res://levels/railway_station_interior/railway_station_interior.tscn",
]

# Scene path -> the SceneManager key it should lead to. "" is scenery the player can walk up to
# but not enter yet.
const STRUCTURES := {
	"res://tileset/structures/arms_dealer_shop/arms_dealer_shop.tscn": "ArmsDealer",
	"res://tileset/structures/bank/bank.tscn": "Bank",
	"res://tileset/structures/farm_house/farm_house.tscn": "FarmHouseInterior",
	"res://tileset/structures/post_office/post_office.tscn": "PostOffice",
	"res://tileset/structures/saloon/rosas_saloon.tscn": "Saloon",
	"res://tileset/structures/sheriffs_office/sheriffs_office.tscn": "SheriffsOffice",
	"res://tileset/structures/chapel/chapel.tscn": "Chapel",
	"res://tileset/structures/railway_station/railway_station.tscn": "RailwayStation",
}


func _instantiate(path : String) -> Node:
	var node = load(path).instantiate()
	add_child_autofree(node)
	return node


func test_every_interior_shares_the_one_script_and_gets_its_door_wired():
	for path in INTERIORS:
		var interior = _instantiate(path)
		assert_true(interior is InteriorLevel, "%s should be an InteriorLevel" % path)
		assert_not_null(interior.exit_door, "%s needs an ExitDoor to leave by" % path)
		assert_true(interior.exit_door.interact == interior._on_exit_interact, \
			"%s should have _ready() wire the exit door, or the player is shut in" % path)


func test_every_structure_shares_the_one_script_and_gets_its_interactable_wired():
	for path in STRUCTURES:
		var structure = _instantiate(path)
		assert_true(structure is HubStructure, "%s should be a HubStructure" % path)
		assert_true(structure.interactable.interact == structure._on_interact, \
			"%s should have _ready() wire its interactable" % path)


func test_every_enterable_structure_leads_somewhere_scenemanager_knows():
	for path in STRUCTURES:
		var expected_key : String = STRUCTURES[path]
		var structure = _instantiate(path)

		assert_eq(structure.destination_scene_key, expected_key, \
			"%s leads to the wrong place" % path)
		assert_eq(structure.can_enter(), expected_key != "", \
			"%s should%s be enterable" % [path, "" if expected_key != "" else " not"])

		if expected_key != "":
			assert_true(SceneManager.scenes.has(expected_key), \
				"'%s' is not a scene SceneManager knows - %s would go nowhere" % [expected_key, path])


# The chapel and the railway station are the reason can_enter() exists: before they had interiors
# they ran the same _on_interact() as everything else, which latched the interactable off and then
# transitioned nowhere, so the first press killed the prompt for the rest of the run. Every
# building in town leads somewhere now, so this is pinned against a structure whose destination has
# been cleared - the state any new bit of scenery starts life in.
func test_scenery_stays_interactable_after_a_press_that_leads_nowhere():
	var structure = _instantiate("res://tileset/structures/chapel/chapel.tscn")
	structure.destination_scene_key = ""

	structure._on_interact()

	assert_false(structure.can_enter(), "with no destination there is nowhere to go...")
	assert_true(structure.interactable.is_interactable, \
		"...so the press must not disarm the prompt permanently")


func test_the_notice_board_opens_the_board_instead_of_loading_a_level():
	var board = _instantiate("res://tileset/structures/notice_board/notice_board.tscn")

	assert_true(board is HubStructure, "it is still one of the buildings in town")
	assert_eq(board.destination_scene_key, "", "it has no level to lead to...")
	assert_true(board.can_enter(), "...but it is still the one structure that opens a screen")

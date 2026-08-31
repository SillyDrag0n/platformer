extends GutTest

# Every playable level has a music slot (levels/_common/level.gd), so a track is assigned in the
# editor rather than wired in code. This just pins that the slot is there and reaches the manager -
# the tracks themselves are dropped in per level.

const LEVELS := [
	"res://levels/hub_level.tscn",
	"res://levels/farm_house_backyard/farm_house_backyard.tscn",
	"res://levels/shaman_camp/shaman_camp.tscn",
	"res://levels/coyote_den/coyote_den.tscn",
	"res://levels/test_level.tscn",
]


func test_every_level_exposes_a_music_slot():
	for path in LEVELS:
		var level = load(path).instantiate()
		autofree(level)
		assert_true("music" in level, \
			"%s should take a track in the inspector - it extends Level" % path)

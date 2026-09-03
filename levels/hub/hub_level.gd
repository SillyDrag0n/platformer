extends Level

# Town: the persistent hub the player comes back to between jobs. Everything that makes it a
# level - the player, the camera, claiming the respawn wiring - is Level's job; what's particular
# to the hub is putting the player back at the door they came out of, and clearing away the
# scenery that was only ever there to get them started.

# Tutorial furniture: the Old Timer, who exists to push the player at the notice board for their
# first job, and the interact prompt that teaches them the button for it. Both have said all they
# have to say once the player has been out to Hutch's place and run the coyote off, and a town
# that still has them standing around in it reads like the game never moved on. A list rather
# than two named exports so anything else that turns out to be first-job-only can retire the
# same way without touching this script.
@export var tutorial_only_nodes : Array[Node] = []


func _on_level_ready() -> void:
	# Only a position that was recorded in the hub itself - a door the player walked into on their
	# way out of town. A leftover from anywhere else is somebody else's coordinates and would put
	# the player through the floor here.
	if SceneManager.has_pending_spawn_position_for("Hub"):
		player.global_position = SceneManager.consume_pending_spawn_position()

	_retire_tutorial_nodes()


# Keyed off the same story flag the encounter uses to retire itself (FLAG_COYOTE_DRIVEN_OFF - see
# levels/farm_house_backyard/coyote_encounter.gd's _ready()), so town stays cleared across a
# restart rather than only for the trip home.
#
# Freed rather than hidden: a hidden Old Timer is still an interactable the player can walk into
# and start a conversation with, and a hidden HintZone still fires its prompt on body_entered.
func _retire_tutorial_nodes() -> void:
	if not GameStateManager.has_story_flag(GameStateManager.FLAG_COYOTE_DRIVEN_OFF):
		return

	for node in tutorial_only_nodes:
		if is_instance_valid(node):
			node.queue_free()

extends Level

# The ride out to the shaman - PROJECT.md's "Level 2 - The Shaman", and the job Hutch puts on the
# board at the end of the tutorial (see
# levels/regions/plains/farm_house_backyard/coyote_encounter.gd). A traverse east out of the farm
# country: a dry wash to cross, a mesa to climb, and her camp at the far end.
#
# The bounty is turned in by talking to her rather than by killing anything - ShamanNPC completes
# this leg's objectives when her dialogue closes. That also means the level is harmless to run on
# its own with no active bounty: she just talks.
#
# The terrain is authored as tile data rather than hand-placed collision, same as every other
# level, so it can be painted over in the editor without restructuring anything.
#
# What she leaves the player with is the whole of this leg, so the conversation ending is the level
# ending: her box closes, the summary of the leg goes up, and the ride back to town is behind that.
# Without this the camp had no way out at all - talking to her ticked the contract along and then
# stood the player in the desert with nothing to do but quit to the main menu.


# Where the ride hands off once she has had her say. Keyed into SceneManager.scenes rather than a
# PackedScene, so it stays a level-flow decision made in the scene - and left empty for a level
# being run on its own, which then ends the way it always did, with her simply talking.
@export var exit_scene_key : String = "Hub"
# Her. She owns the contract side of the conversation (bounty_id and completes_objectives are set
# on her in npc/ShamanNPC.tscn); this script owns only what becomes of the level afterwards.
@export var shaman : DialogNPC

# Whether the leg was already finished when the player walked in. Riding back out here afterwards
# should find her willing to talk, not march the player through a summary screen for a leg they
# finished days ago.
var _leg_was_already_done := false
var _leaving_the_camp := false


func _on_level_ready() -> void:
	if not is_instance_valid(shaman):
		return
	_leg_was_already_done = completed_stage() != null
	# Connected after DialogNPC's own handler - a child is ready before its parent - so the
	# objectives that conversation ticks off are already ticked by the time this runs, and
	# completed_stage() below can see them.
	shaman.dialogue_box.closed.connect(_on_shaman_finished)


func _on_shaman_finished() -> void:
	if _leaving_the_camp or _leg_was_already_done:
		return

	var stage := completed_stage()
	if stage == null:
		# She talks to anyone. Someone out here without the contract has had a conversation, not
		# finished a leg, and the level has no business ending on them.
		return

	_leaving_the_camp = true
	if exit_scene_key == "":
		# Nowhere to go - a level being run on its own. Don't tear the scene down for a summary
		# screen that would have nothing to hand back to.
		return

	# No payment: what she tells him is this leg, and Hutch settles up when the whole job is done -
	# the summary hides the line rather than showing a nought. Saving is hers as well; DialogNPC
	# does it as the conversation closes, so the ride home can't cost the player the progress.
	UiManager.open_stage_completed_screen(GameStateManager.get_bounty_by_id(shaman.bounty_id), \
		stage, 0, exit_scene_key)


# The leg this camp is the whole of, once it actually is finished. Null while the contract is
# missing, was never taken, or she still has objectives left unticked.
func completed_stage() -> BountyStageData:
	if not is_instance_valid(shaman) or shaman.bounty_id == "" or shaman.completes_objectives.is_empty():
		return null

	var bounty : BountyData = GameStateManager.get_bounty_by_id(shaman.bounty_id)
	if bounty == null:
		return null

	var stage : BountyStageData = bounty.find_stage_for_objective(shaman.completes_objectives[0])
	if stage == null or not stage.is_complete():
		return null
	return stage

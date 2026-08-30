extends Node

@export var bounty_board_scene: PackedScene
@export var bounty_completed_scene: PackedScene
@export var stage_completed_scene: PackedScene

# What the stage-complete screen shows. Held here because change_scene_to_packed() builds that
# screen from scratch - there is no instance to hand the data to until it is already running.
var completed_stage: BountyStageData = null
var completed_stage_bounty: BountyData = null
var completed_stage_payment: int = 0
var completed_stage_exit_key: String = "Hub"

func open_bounty_board():
	get_tree().change_scene_to_packed(bounty_board_scene)

func open_bounty_completed_screen():
	get_tree().change_scene_to_packed(bounty_completed_scene)


# Shown between the level that finished a leg of a bounty and the ride back to town. `payment` is
# whatever was handed over during that leg (Hutch's fifteen dollars, say) rather than the
# contract's own reward, which is paid out when the whole job is done.
func open_stage_completed_screen(bounty: BountyData, stage: BountyStageData, payment: int = 0, exit_key: String = "Hub") -> void:
	if stage_completed_scene == null:
		# Nothing wired up to show - go where the screen would have sent them.
		SceneManager.transition_to_scene_faded(exit_key)
		return

	completed_stage_bounty = bounty
	completed_stage = stage
	completed_stage_payment = payment
	completed_stage_exit_key = exit_key
	get_tree().change_scene_to_packed(stage_completed_scene)


func clear_completed_stage() -> void:
	completed_stage_bounty = null
	completed_stage = null
	completed_stage_payment = 0
	completed_stage_exit_key = "Hub"

extends CanvasLayer

# Shown when a leg of a bounty is finished, between the level that finished it and the ride back to
# town: what the player just did, what they were paid for it, and what the contract asks of them
# next. The bounty's own reward screen (ui/screens/bounty_completed.gd) is for the end of the whole
# contract - this is the one that fires two stages before that.
#
# Built fresh by change_scene_to_packed(), so there is nothing to hand it directly - it reads what
# to show off UiManager, which the caller sets on the way in.

@onready var stage_title_label : Label = $PanelContainer/VBoxContainer/StageTitleLabel
@onready var done_label : Label = $PanelContainer/VBoxContainer/DoneLabel
@onready var payment_label : Label = $PanelContainer/VBoxContainer/PaymentLabel
@onready var next_label : Label = $PanelContainer/VBoxContainer/NextLabel
@onready var continue_button : Button = $PanelContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	SettingsManager.apply_ui_scale(self)
	# Nothing else on this screen takes input, and without an explicit grab a controller has
	# nothing focused to press - the same gap that left the shop unusable on a pad.
	continue_button.grab_focus()

	var stage : BountyStageData = UiManager.completed_stage
	if stage == null:
		return

	stage_title_label.text = tr(stage.title)
	done_label.text = _completed_lines(stage)
	_show_payment(UiManager.completed_stage_payment)
	_show_next_stage()


func _completed_lines(stage : BountyStageData) -> String:
	var lines : Array[String] = []
	for objective in stage.objectives:
		lines.append("[x] %s" % tr(objective.text))
	return "\n".join(lines)


func _show_payment(payment : int) -> void:
	# Hidden rather than shown as zero, since not every leg of a job pays on its own.
	payment_label.visible = payment > 0
	if payment > 0:
		payment_label.text = tr("Paid: $%d") % payment


func _show_next_stage() -> void:
	var bounty : BountyData = UiManager.completed_stage_bounty
	var next_stage : BountyStageData = bounty.get_current_stage() if bounty != null else null
	if next_stage == null:
		# The last leg of the contract is finished by the bounty's own reward screen, so there is
		# nothing left to point at here.
		next_label.visible = false
		return

	var lines : Array[String] = [tr("Next: %s") % tr(next_stage.title)]
	for objective in next_stage.objectives:
		lines.append("     %s" % tr(objective.text))
	next_label.text = "\n".join(lines)


func _on_continue_button_pressed() -> void:
	# Read before clearing - the clear takes the exit key with it.
	var exit_key : String = UiManager.completed_stage_exit_key
	UiManager.clear_completed_stage()
	SceneManager.transition_to_scene_faded(exit_key)

extends Control

signal closed
signal accepted(bounty_data: BountyData)

const REWARD_ICON_SIZE := Vector2(64, 64)

@onready var status_label: Label = $CenterContainer/VBoxContainer/Card/MarginVBox/HeaderRow/StatusLabel
@onready var title_label: Label = $CenterContainer/VBoxContainer/Card/MarginVBox/BodyRow/RightColumn/TitleLabel
@onready var description_label: Label = $CenterContainer/VBoxContainer/Card/MarginVBox/BodyRow/RightColumn/DescriptionScroll/DescriptionLabel
@onready var icon_rect: TextureRect = $CenterContainer/VBoxContainer/Card/MarginVBox/BodyRow/LeftColumn/IconFrame/IconRect
@onready var region_label: Label = $CenterContainer/VBoxContainer/Card/MarginVBox/BodyRow/LeftColumn/RegionLabel
@onready var status_detail_label: Label = $CenterContainer/VBoxContainer/Card/MarginVBox/BodyRow/LeftColumn/StatusDetailLabel
@onready var rewards_row: HBoxContainer = $CenterContainer/VBoxContainer/Card/MarginVBox/BodyRow/RightColumn/RewardsSection/RewardsRow
@onready var accept_button: Button = $CenterContainer/VBoxContainer/ButtonRow/AcceptButton
@onready var decline_button: Button = $CenterContainer/VBoxContainer/ButtonRow/DeclineButton

var bounty_data: BountyData


func open(bounty: BountyData) -> void:
	bounty_data = bounty

	title_label.text = tr(bounty.title)
	description_label.text = tr(bounty.description) if bounty.description != "" else tr("No word yet on this one.")

	var status_text := bounty.get_status_text()
	status_label.text = status_text
	status_detail_label.text = "Status: %s" % status_text

	var region: RegionData = GameStateManager.get_region_by_id(bounty.region_id)
	region_label.text = "Region: %s" % (region.name if region else "Unknown")

	icon_rect.texture = bounty.icon

	_populate_rewards(bounty)

	visible = true
	accept_button.disabled = false
	decline_button.disabled = false
	accept_button.grab_focus()


func _populate_rewards(bounty: BountyData) -> void:
	for child in rewards_row.get_children():
		child.queue_free()

	for item in bounty.rewards:
		if item and item.icon:
			rewards_row.add_child(_make_reward_icon(item.icon, item.display_name))

	for ability in bounty.ability_rewards:
		if ability and ability.icon:
			rewards_row.add_child(_make_reward_icon(ability.icon, ability.display_name))


func _make_reward_icon(texture: Texture2D, label: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = REWARD_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = label
	return icon


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_accept_pressed() -> void:
	accept_button.disabled = true
	decline_button.disabled = true
	# Hide the dossier first so the board (and the poster about to tear off it) is visible again
	# before BountyBoard starts that animation - see BountyBoard._on_bounty_accepted().
	visible = false
	accepted.emit(bounty_data)


func _on_decline_pressed() -> void:
	_close()


func _close() -> void:
	visible = false
	bounty_data = null
	closed.emit()

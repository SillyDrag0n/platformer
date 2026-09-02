extends CanvasLayer

# Pick which of the three saves to play. Sits between the main menu's PLAY and the game itself,
# because that is the moment the game finally knows which file to read - nothing is loaded at boot
# any more (see scripts/managers/save_manager.gd).
#
# The rows are built here rather than authored three times in the scene: they differ only by slot
# number, and a filled row and an empty one are the same row with different text on it.

signal closed

const NAME_ENTRY_SCENE := preload("res://ui/screens/name_entry_screen.tscn")

# The rows are built at runtime, so their sizing lives here rather than in the scene with
# everything else. Tall enough to read a whole playthrough summary off in one line.
const ROW_HEIGHT := 62
const ROW_FONT_SIZE := 22

@onready var slot_list : VBoxContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/SlotList
@onready var back_button : Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

# Erasing a save used to ask through a ConfirmationDialog, which is a real OS Window rather than a
# Control in this scene. That is the same trap the inventory's item picker was pulled out of (see
# inventory_ui.gd's _close_picker) - a native window never reliably receives gamepad input, so the
# one prompt in the game guarding a permanent delete could be unanswerable on a pad, and it drew
# itself in stock OS chrome besides. It is an embedded panel now, like every other prompt here.
@onready var confirm_panel : PanelContainer = $ConfirmPanel
@onready var confirm_backdrop : Button = $ConfirmBackdrop
@onready var confirm_text : Label = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmText
@onready var confirm_cancel_button : Button = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmButtons/CancelButton
@onready var confirm_delete_button : Button = $ConfirmPanel/ConfirmMargin/ConfirmBody/ConfirmButtons/DeleteButton

# Which slot the prompt is asking about. It is one panel reused by all three rows, so it has to be
# told each time rather than knowing.
var _slot_pending_delete : int = SaveManager.NO_SLOT

# The Delete button that opened the prompt, so closing it puts focus back on the row the player was
# working through instead of throwing them to the top of the list.
var _confirm_opener : Control = null


func _ready() -> void:
	SettingsManager.apply_ui_scale(self)
	_build_slot_list()


func _build_slot_list() -> void:
	for child in slot_list.get_children():
		child.queue_free()

	var buttons : Array = []
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		slot_list.add_child(row)

		var play := Button.new()
		play.text = _slot_label(slot)
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		play.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		play.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(play)
		buttons.append(play)

		# A slot with nothing in it has nothing to delete, so the button is there for alignment but
		# takes neither presses nor focus - a controller should not have to skip past dead buttons.
		var erase := Button.new()
		erase.text = tr("Delete")
		erase.custom_minimum_size = Vector2(180, ROW_HEIGHT)
		erase.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		erase.disabled = not SaveManager.has_save(slot)
		erase.focus_mode = Control.FOCUS_ALL if not erase.disabled else Control.FOCUS_NONE
		erase.pressed.connect(_on_delete_pressed.bind(slot, erase))
		row.add_child(erase)
		if not erase.disabled:
			buttons.append(erase)

	# Wired by hand for the same reason every other list in this game is - Godot's geometric focus
	# search is unreliable across a rebuilt list, and this one rebuilds on every delete.
	FocusGrid.wire_grid(buttons, 1, back_button)
	if not buttons.is_empty():
		buttons[0].grab_focus()
	else:
		back_button.grab_focus()


# "Slot 1 - Empty", or the playthrough in it: who they are, what they have, how far along.
func _slot_label(slot : int) -> String:
	var summary : Dictionary = SaveManager.read_slot_summary(slot)
	if summary.is_empty():
		return "%s %d  -  %s" % [tr("Slot"), slot, tr("Empty")]

	var parts : Array[String] = [
		"%s %d  -  %s" % [tr("Slot"), slot, summary["player_name"]],
		"$%d" % summary["dollars"],
		tr("%d bounties") % summary["bounties_completed"],
	]
	if summary["saved_at_unix"] > 0:
		var when := Time.get_datetime_dict_from_unix_time(summary["saved_at_unix"])
		parts.append("%04d-%02d-%02d" % [when["year"], when["month"], when["day"]])
	return "  |  ".join(parts)


func _on_slot_pressed(slot : int) -> void:
	if SaveManager.has_save(slot):
		SaveManager.load_slot(slot)
		queue_free()
		SceneManager.transition_to_scene("Hub")
		return

	# A brand new save has no player name yet, so it is asked for before the Hub loads rather than
	# starting the player off as an empty string.
	SaveManager.start_new_game(slot)
	queue_free()
	get_tree().get_root().add_child(NAME_ENTRY_SCENE.instantiate())


# --- Erasing a slot ---

func _on_delete_pressed(slot : int, opener : Control) -> void:
	_slot_pending_delete = slot
	_confirm_opener = opener
	confirm_text.text = tr("Permanently erase slot %d? This cannot be undone.") % slot
	confirm_backdrop.visible = true
	confirm_panel.visible = true
	# Keep, not Delete. The destructive answer should never be the one a player confirms by
	# reflex, and this prompt is the last thing standing between them and a lost playthrough.
	confirm_cancel_button.grab_focus()


func _close_delete_confirm() -> void:
	_slot_pending_delete = SaveManager.NO_SLOT
	confirm_panel.visible = false
	confirm_backdrop.visible = false
	if _confirm_opener != null and is_instance_valid(_confirm_opener):
		_confirm_opener.grab_focus()
	else:
		back_button.grab_focus()
	_confirm_opener = null


func _on_delete_confirmed() -> void:
	if _slot_pending_delete == SaveManager.NO_SLOT:
		return
	SaveManager.delete_slot(_slot_pending_delete)
	_slot_pending_delete = SaveManager.NO_SLOT
	# The list rebuilds and grabs focus itself, so the opener is stale from here on.
	_confirm_opener = null
	confirm_panel.visible = false
	confirm_backdrop.visible = false
	_build_slot_list()


func is_confirming_delete() -> bool:
	return confirm_panel.visible


# B / Escape backs out one level at a time: the delete prompt first if it is up, and only then the
# screen itself - the same gesture every other screen in this game uses.
func _unhandled_input(event : InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if is_confirming_delete():
		_close_delete_confirm()
		return
	_on_back_button_pressed()


# The main menu frees itself on the way in here (it can't just hide - see
# ui/screens/main_menu_screen.gd), so backing out rebuilds it rather than revealing it.
func _on_back_button_pressed() -> void:
	closed.emit()
	queue_free()
	GameManager.main_menu()

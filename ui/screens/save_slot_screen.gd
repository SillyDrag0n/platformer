extends CanvasLayer

# Pick which of the three saves to play. Sits between the main menu's PLAY and the game itself,
# because that is the moment the game finally knows which file to read - nothing is loaded at boot
# any more (see scripts/managers/save_manager.gd).
#
# The rows are built here rather than authored three times in the scene: they differ only by slot
# number, and a filled row and an empty one are the same row with different text on it.

signal closed

const NAME_ENTRY_SCENE := preload("res://ui/screens/name_entry_screen.tscn")

@onready var slot_list : VBoxContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/SlotList
@onready var back_button : Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var delete_confirm_dialog : ConfirmationDialog = $DeleteConfirmDialog

# Which slot the delete dialog is asking about. The dialog is one node reused by all three rows,
# so it has to be told each time rather than knowing.
var _slot_pending_delete : int = SaveManager.NO_SLOT


func _ready() -> void:
	SettingsManager.apply_ui_scale(self)
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	_build_slot_list()


func _build_slot_list() -> void:
	for child in slot_list.get_children():
		child.queue_free()

	var buttons : Array = []
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var row := HBoxContainer.new()
		slot_list.add_child(row)

		var play := Button.new()
		play.text = _slot_label(slot)
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(play)
		buttons.append(play)

		# A slot with nothing in it has nothing to delete, so the button is there for alignment but
		# takes neither presses nor focus - a controller should not have to skip past dead buttons.
		var erase := Button.new()
		erase.text = tr("Delete")
		erase.disabled = not SaveManager.has_save(slot)
		erase.focus_mode = Control.FOCUS_ALL if not erase.disabled else Control.FOCUS_NONE
		erase.pressed.connect(_on_delete_pressed.bind(slot))
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


func _on_delete_pressed(slot : int) -> void:
	_slot_pending_delete = slot
	delete_confirm_dialog.dialog_text = tr("Permanently erase slot %d? This cannot be undone.") % slot
	delete_confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _slot_pending_delete == SaveManager.NO_SLOT:
		return
	SaveManager.delete_slot(_slot_pending_delete)
	_slot_pending_delete = SaveManager.NO_SLOT
	_build_slot_list()


# B / Escape backs out to the main menu, the same gesture every other screen in this game uses.
func _unhandled_input(event : InputEvent) -> void:
	if delete_confirm_dialog.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()


# The main menu frees itself on the way in here (it can't just hide - see
# ui/screens/main_menu_screen.gd), so backing out rebuilds it rather than revealing it.
func _on_back_button_pressed() -> void:
	closed.emit()
	queue_free()
	GameManager.main_menu()

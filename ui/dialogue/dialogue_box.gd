class_name DialogueBox
extends MenuPopup

signal line_shown(line_index : int)

@export var speaker_label : Label
@export var text_label : Label
@export var continue_button : Button
@export var choice_buttons : Control
@export var yes_button : Button
@export var no_button : Button

var lines : Array[String] = []
var line_index : int = 0

var _on_yes : Callable
var _on_no : Callable


func show_dialogue(speaker_name : String, dialogue_lines : Array[String]) -> void:
	if dialogue_lines.is_empty():
		return

	continue_button.show()
	choice_buttons.hide()

	speaker_label.text = tr(speaker_name)
	lines = dialogue_lines.map(func(line): return tr(line))
	line_index = 0
	_refresh_current_line()
	open()


# Shows a single line with Yes/No buttons instead of Continue, calling on_yes or on_no once the
# box has already closed - so a callback that immediately opens another menu (e.g. the shop)
# doesn't get rejected by MenuPopup.open()'s already-open guard.
func show_choice(speaker_name : String, line : String, yes_text : String, no_text : String, on_yes : Callable, on_no : Callable) -> void:
	continue_button.hide()
	choice_buttons.show()
	yes_button.text = tr(yes_text)
	no_button.text = tr(no_text)
	_on_yes = on_yes
	_on_no = on_no

	speaker_label.text = tr(speaker_name)
	text_label.text = tr(line)
	open()


# MenuPopup.open() never grabs focus on its own, so without this a controller has no focused
# button to press - Continue/Yes only worked via mouse click.
func _on_opened() -> void:
	if choice_buttons.visible:
		yes_button.grab_focus()
	else:
		continue_button.grab_focus()


func _refresh_current_line() -> void:
	text_label.text = lines[line_index]
	continue_button.text = tr("Close") if line_index == lines.size() - 1 else tr("CONTINUE")
	line_shown.emit(line_index)


func _on_continue_button_pressed() -> void:
	line_index += 1
	if line_index >= lines.size():
		close()
	else:
		_refresh_current_line()


func _on_yes_button_pressed() -> void:
	close()
	if _on_yes.is_valid():
		_on_yes.call()


func _on_no_button_pressed() -> void:
	close()
	if _on_no.is_valid():
		_on_no.call()

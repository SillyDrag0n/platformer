class_name QuestEntry
extends ColorRect

@onready var title_label : Label = $MarginContainer/VBoxContainer/HBoxContainer/TitleLabel
@onready var status_label : Label = $MarginContainer/VBoxContainer/HBoxContainer/StatusLabel
@onready var progress_bar : ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var description_label : Label = $MarginContainer/VBoxContainer/DescriptionLabel


func set_quest_data(quest : QuestData) -> void:
	var completed : bool = QuestManager.is_completed(quest)
	var current : int = QuestManager.get_progress_current(quest)
	var target : int = QuestManager.get_progress_target(quest)

	title_label.text = tr(quest.title)
	status_label.text = tr("Completed") if completed else "%d / %d" % [current, target]
	progress_bar.value = QuestManager.get_progress_fraction(quest) * 100.0
	description_label.text = tr(quest.description)

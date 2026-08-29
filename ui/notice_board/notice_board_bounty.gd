extends Control

signal poster_pressed(bounty_data)

var base_position: Vector2
var base_rotation: float = 0.0
var bounty_data: BountyData

var _tearing := false

func setup(bounty: BountyData):
	bounty_data = bounty
	$TitleLabel.text = tr(bounty.title)
	$RumorText.text = tr(bounty.description) if bounty.description != "" else tr("No word yet on this one.")
	if bounty.icon:
		$Picture.texture = bounty.icon
		$Picture.self_modulate = Color.WHITE if bounty.completed else Color.BLACK

func _ready():
	pivot_offset = size / 2.0
	base_position = position
	base_rotation = rotation_degrees

func _process(_delta):
	if _tearing:
		return
	position.y = base_position.y + sin(Time.get_ticks_msec() * 0.004) * 5

func _on_poster_pressed():
	poster_pressed.emit(bounty_data)


func grab_focus_button() -> void:
	$SelectButton.grab_focus()


func set_interactive(enabled: bool) -> void:
	$SelectButton.disabled = not enabled
	$SelectButton.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


# Rips the poster free of the board - pinned posters (see BountyBoard.spawn_poster) fly off at
# an angle derived from their resting tilt so it reads as torn from a fixed pin, not just flung.
func tear_off() -> void:
	if _tearing:
		return
	_tearing = true
	set_interactive(false)
	if $TearSound.stream:
		$TearSound.play()
	var fly_side := 1.0 if randf() < 0.5 else -1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees", base_rotation + fly_side * 50.0, 0.4)
	tween.parallel().tween_property(self, "position", position + Vector2(fly_side * 120.0, 340.0), 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.15)
	await tween.finished

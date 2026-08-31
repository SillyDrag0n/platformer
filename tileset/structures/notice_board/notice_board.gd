extends HubStructure

# The board of posted contracts outside the sheriff's office. The only structure in town that
# opens a screen instead of loading a level, so it is the only one that still needs its own script.


func can_enter() -> bool:
	return true


func enter() -> void:
	UiManager.open_bounty_board()

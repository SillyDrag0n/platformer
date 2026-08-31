extends Node

static var total_award_amount : int

signal on_collectible_award_received


func give_pickup_award(collectible_award : int):
	total_award_amount += collectible_award

	on_collectible_award_received.emit(total_award_amount)


func can_afford(amount : int) -> bool:
	return total_award_amount >= amount


func spend(amount : int) -> bool:
	if !can_afford(amount):
		return false

	total_award_amount -= amount
	on_collectible_award_received.emit(total_award_amount)
	return true


# Back to a brand-new game's pockets. Called by SaveManager when a slot is started or loaded, so
# one playthrough's money can't follow the player into another's.
func reset_progress() -> void:
	total_award_amount = 0
	on_collectible_award_received.emit(total_award_amount)

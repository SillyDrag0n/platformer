extends Node

signal ability_unlocked(ability : AbilityData)

@export var abilities : Array[AbilityData]

var _unlocked_ids : Dictionary = {}
var _ability_lookup : Dictionary = {}


func _ready():
	_ability_lookup.clear()
	for ability in abilities:
		_ability_lookup[ability.id] = ability


func is_unlocked(id : String) -> bool:
	return _unlocked_ids.get(id, false)


func unlock(id : String):
	if _ability_lookup.has(id):
		unlock_ability(_ability_lookup[id])


func unlock_ability(ability : AbilityData):
	if ability == null or _unlocked_ids.get(ability.id, false):
		return
	_unlocked_ids[ability.id] = true
	ability_unlocked.emit(ability)


func get_ability_by_id(id : String) -> AbilityData:
	return _ability_lookup.get(id)


func get_unlocked_ids() -> Array:
	return _unlocked_ids.keys()


# Back to a brand-new game: nothing unlocked. The ability lookup itself is authored content and
# stays. Called by SaveManager when a slot is started or loaded.
func reset_progress() -> void:
	_unlocked_ids.clear()

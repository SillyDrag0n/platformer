extends Level

# The sandbox the Sand Spirit bounty is played in, and the level new mechanics get prototyped in.
# Unlike the story levels it hosts whichever boss the active bounty names rather than one authored
# into the scene, so the same arena can stand in for any contract that has a boss and no level of
# its own yet.

const SPIRIT_ITEM : ItemData = preload("res://items/utility/spirit.tres")
const SPIRIT_REFILL_AMOUNT : int = 3

@export var boss_spawn_marker : Marker2D
@export var boss_arena : BossArena


func _on_level_ready() -> void:
	InventoryManager.refill_item(SPIRIT_ITEM, SPIRIT_REFILL_AMOUNT)
	spawn_boss()


func _on_death_zone_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		player.player_death()


func spawn_boss() -> void:
	if GameStateManager.active_bounty == null:
		return

	var boss_scene : PackedScene = GameStateManager.active_bounty.boss_scene
	if boss_scene == null:
		return

	var boss_instance = boss_scene.instantiate()
	boss_instance.global_position = boss_spawn_marker.global_position
	add_child(boss_instance)
	boss_arena.boss = boss_instance

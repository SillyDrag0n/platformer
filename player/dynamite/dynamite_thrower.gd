extends Node2D

var dynamite_scene = preload("res://player/dynamite/dynamite.tscn")

@onready var throw_marker : Marker2D = $ThrowMarker
@onready var player = get_parent()

var held_dynamite : Node2D = null


func _process(_delta) -> void:
	if held_dynamite != null and not is_instance_valid(held_dynamite):
		held_dynamite = null

	if held_dynamite == null:
		if GameInputEvents.throw_input_just_pressed() and player.state_machine.current_node_state.name.to_lower() == "normal":
			_pull_dynamite()
		return

	held_dynamite.global_position = throw_marker.global_position

	if GameInputEvents.throw_input_just_released():
		_release_dynamite()


func _pull_dynamite() -> void:
	var item = InventoryManager.get_equipped_utility()
	if not (item is ThrowableItemData):
		return
	if InventoryManager.get_owned_quantity(item) <= 0:
		return

	InventoryManager.remove_item(item)

	held_dynamite = dynamite_scene.instantiate()
	get_tree().current_scene.add_child(held_dynamite)
	held_dynamite.global_position = throw_marker.global_position
	held_dynamite.throw_speed = item.throw_speed
	held_dynamite.gravity = item.gravity
	held_dynamite.explosion_damage = item.explosion_damage
	held_dynamite.explosion_radius = item.explosion_radius
	held_dynamite.light_fuse(item.fuse_time)


func _release_dynamite() -> void:
	var direction : Vector2 = GameInputEvents.aim_input(held_dynamite.global_position)
	held_dynamite.throw(direction)
	held_dynamite = null

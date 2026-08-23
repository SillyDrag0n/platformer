extends Node

# Utility items granted (and the first one equipped) at spawn, same bootstrap pattern Gun.gd uses
# for default_weapon/default_ammo - guarantees there's always something to cycle to/use even
# before any shop or pickup grants one.
@export var default_utility_items : Array[UtilityItemData] = []
# Every default utility item is a capped consumable (dynamite included - see DynamiteThrower,
# which spends one per throw), so a single granted copy would run out almost immediately. Grant
# this many of each at spawn instead, capped at whatever the item itself allows.
@export var default_consumable_quantity : int = 3

@onready var player = get_parent()
@onready var spirit_drink_sound : AudioStreamPlayer = $SpiritDrink


func _ready() -> void:
	for item in default_utility_items:
		if InventoryManager.is_owned(item):
			continue
		var grant_count := mini(default_consumable_quantity, item.max_stack_size)
		for i in grant_count:
			InventoryManager.add_item(item)
	if InventoryManager.get_equipped_utility() == null and not default_utility_items.is_empty():
		InventoryManager.equip_utility(default_utility_items[0])


func _process(_delta) -> void:
	if GameInputEvents.cycle_utility_just_pressed():
		InventoryManager.cycle_utility()

	_try_use_equipped_utility()


# Only handles instant-use utility items (e.g. a healing item consumed on press). Throwables
# (e.g. dynamite) are handled separately by DynamiteThrower, which reads the same "use_utility"
# input but only acts when a ThrowableItemData is equipped.
func _try_use_equipped_utility() -> void:
	if not GameInputEvents.use_utility_just_pressed():
		return
	if player.state_machine.current_node_state.name.to_lower() != "normal":
		return

	var item = InventoryManager.get_equipped_utility()
	if not (item is HealingItemData):
		return
	if InventoryManager.get_owned_quantity(item) <= 0:
		return
	if HealthManager.current_health >= HealthManager.max_health:
		return

	InventoryManager.remove_item(item)
	HealthManager.increase_health(item.heal_amount)
	spirit_drink_sound.play()

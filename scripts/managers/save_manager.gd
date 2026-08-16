extends Node

var save_path := "user://game_data/"
var save_file_name := "save_data.tres"


func _ready():
	load_game()


func save_game():
	var data := SaveDataResource.new()

	for slot_data in InventoryManager.item_slots:
		var item : ItemData = slot_data["item"]
		if item != null:
			data.inventory_item_paths.append(item.resource_path)
			data.inventory_item_quantities.append(slot_data["quantity"])

	var primary : WeaponItemData = InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.PRIMARY)
	data.equipped_primary_path = primary.resource_path if primary else ""

	var secondary : WeaponItemData = InventoryManager.get_equipped_weapon(InventoryManager.WeaponSlot.SECONDARY)
	data.equipped_secondary_path = secondary.resource_path if secondary else ""

	var primary_ammo : AmmoItemData = InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.PRIMARY)
	data.equipped_primary_ammo_path = primary_ammo.resource_path if primary_ammo else ""

	var secondary_ammo : AmmoItemData = InventoryManager.get_equipped_ammo(InventoryManager.WeaponSlot.SECONDARY)
	data.equipped_secondary_ammo_path = secondary_ammo.resource_path if secondary_ammo else ""

	data.equipped_utility_path = InventoryManager.equipped_utility.resource_path if InventoryManager.equipped_utility else ""

	for slot_key in InventoryManager.equipped_cosmetics:
		var cosmetic : CosmeticItemData = InventoryManager.equipped_cosmetics[slot_key]
		if cosmetic != null:
			data.equipped_cosmetic_paths[slot_key] = cosmetic.resource_path

	var primary_skin : CosmeticItemData = InventoryManager.get_equipped_weapon_skin(InventoryManager.WeaponSlot.PRIMARY)
	data.equipped_primary_weapon_skin_path = primary_skin.resource_path if primary_skin else ""

	var secondary_skin : CosmeticItemData = InventoryManager.get_equipped_weapon_skin(InventoryManager.WeaponSlot.SECONDARY)
	data.equipped_secondary_weapon_skin_path = secondary_skin.resource_path if secondary_skin else ""

	data.unlocked_ability_ids.assign(AbilityManager.get_unlocked_ids())
	data.completed_quest_ids.assign(QuestManager.completed_quest_ids)
	data.enemy_kill_counts = QuestManager.enemy_kill_counts.duplicate()
	for quest in QuestManager.received_quests:
		data.received_quest_paths.append(quest.resource_path)

	for bounty in GameStateManager.bounties:
		data.bounty_states[bounty.id] = {
			"unlocked": bounty.unlocked,
			"completed": bounty.completed,
			"reward_claimed": bounty.reward_claimed,
		}

	for region in GameStateManager.regions:
		data.region_states[region.id] = region.unlocked

	if !DirAccess.dir_exists_absolute(save_path):
		DirAccess.make_dir_absolute(save_path)
	ResourceSaver.save(data, save_path + save_file_name)


func load_game():
	if !ResourceLoader.exists(save_path + save_file_name):
		return

	var data : SaveDataResource = ResourceLoader.load(save_path + save_file_name)
	if data == null:
		return

	# Ownership has to be restored before equipped state below, since equip_weapon()/
	# equip_ammo()/equip_utility()/equip_cosmetic() all reject items InventoryManager doesn't
	# consider owned.
	for i in range(data.inventory_item_paths.size()):
		var path : String = data.inventory_item_paths[i]
		if path == "" or !ResourceLoader.exists(path):
			continue
		var item : ItemData = load(path)
		for _q in range(data.inventory_item_quantities[i]):
			InventoryManager.add_item(item)

	if data.equipped_primary_path != "" and ResourceLoader.exists(data.equipped_primary_path):
		InventoryManager.equip_weapon(InventoryManager.WeaponSlot.PRIMARY, load(data.equipped_primary_path))

	if data.equipped_secondary_path != "" and ResourceLoader.exists(data.equipped_secondary_path):
		InventoryManager.equip_weapon(InventoryManager.WeaponSlot.SECONDARY, load(data.equipped_secondary_path))

	if data.equipped_primary_ammo_path != "" and ResourceLoader.exists(data.equipped_primary_ammo_path):
		InventoryManager.equip_ammo(InventoryManager.WeaponSlot.PRIMARY, load(data.equipped_primary_ammo_path))

	if data.equipped_secondary_ammo_path != "" and ResourceLoader.exists(data.equipped_secondary_ammo_path):
		InventoryManager.equip_ammo(InventoryManager.WeaponSlot.SECONDARY, load(data.equipped_secondary_ammo_path))

	if data.equipped_utility_path != "" and ResourceLoader.exists(data.equipped_utility_path):
		InventoryManager.equip_utility(load(data.equipped_utility_path))

	for slot_key in data.equipped_cosmetic_paths:
		var path : String = data.equipped_cosmetic_paths[slot_key]
		if path != "" and ResourceLoader.exists(path):
			InventoryManager.equip_cosmetic(load(path))

	if data.equipped_primary_weapon_skin_path != "" and ResourceLoader.exists(data.equipped_primary_weapon_skin_path):
		InventoryManager.equip_weapon_skin(InventoryManager.WeaponSlot.PRIMARY, load(data.equipped_primary_weapon_skin_path))

	if data.equipped_secondary_weapon_skin_path != "" and ResourceLoader.exists(data.equipped_secondary_weapon_skin_path):
		InventoryManager.equip_weapon_skin(InventoryManager.WeaponSlot.SECONDARY, load(data.equipped_secondary_weapon_skin_path))

	for id in data.unlocked_ability_ids:
		AbilityManager.unlock(id)

	for path in data.received_quest_paths:
		if ResourceLoader.exists(path):
			QuestManager.receive_quest(load(path))

	for id in data.completed_quest_ids:
		QuestManager.mark_completed(id)

	QuestManager.enemy_kill_counts = data.enemy_kill_counts.duplicate()

	for bounty_id in data.bounty_states:
		var bounty : BountyData = GameStateManager.get_bounty_by_id(bounty_id)
		if bounty != null:
			var state : Dictionary = data.bounty_states[bounty_id]
			bounty.unlocked = state.get("unlocked", bounty.unlocked)
			bounty.completed = state.get("completed", bounty.completed)
			bounty.reward_claimed = state.get("reward_claimed", bounty.reward_claimed)

	for region in GameStateManager.regions:
		if data.region_states.has(region.id):
			region.unlocked = data.region_states[region.id]

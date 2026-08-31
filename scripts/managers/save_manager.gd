extends Node

# Three save files, picked from the main menu (see ui/screens/save_slot_screen.gd) before anything
# is loaded. Nothing is read at boot any more: which slot to load isn't known until the player
# says so, and loading one at startup is what made a second slot impossible.

const SLOT_COUNT := 3
# 1..SLOT_COUNT are the real slots; NO_SLOT is "the player hasn't picked one yet", which is the
# state the main menu sits in.
const NO_SLOT := 0

# The single-file save this game had before slots existed. Moved into slot 1 the first time a
# build with slots runs, so an existing playthrough isn't stranded.
const LEGACY_SAVE_FILE := "save_data.tres"

var save_path := "user://game_data/"

# Where save_game() writes. Guarded rather than defaulted to slot 1: an autosave firing before the
# player has chosen (quitting straight from the main menu, say) must not invent a file, and must
# certainly not write one playthrough's state into another's slot.
var active_slot : int = NO_SLOT


func _ready() -> void:
	_migrate_legacy_save_file()


func slot_path(slot : int) -> String:
	return "%ssave_slot_%d.tres" % [save_path, slot]


func has_save(slot : int) -> bool:
	return ResourceLoader.exists(slot_path(slot))


# Starts a fresh playthrough in a slot. No file is written yet - that happens on the first real
# save - so backing out of the name screen doesn't leave a half-made save behind.
func start_new_game(slot : int) -> void:
	active_slot = slot
	_reset_game_state()
	InventoryManager.grant_default_outfit_if_needed()


func load_slot(slot : int) -> void:
	active_slot = slot
	_reset_game_state()
	load_game()
	# Runs after load_game() has had its say, not inside InventoryManager's own _ready() - see
	# grant_default_outfit_if_needed()'s comment.
	InventoryManager.grant_default_outfit_if_needed()


func delete_slot(slot : int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))
	# A player who deletes the slot they are playing keeps playing, but their progress now has
	# nowhere to go - so the slot is let go of rather than silently re-created on the next save.
	if active_slot == slot:
		active_slot = NO_SLOT


# What the slot screen puts on a button, read straight off the file without loading any of it into
# the running game. Returns an empty dictionary for a slot with nothing in it.
func read_slot_summary(slot : int) -> Dictionary:
	if not has_save(slot):
		return {}
	var data : SaveDataResource = ResourceLoader.load(slot_path(slot))
	if data == null:
		return {}
	return {
		"player_name": data.player_name if data.player_name != "" else PlayerManager.DEFAULT_NAME,
		"dollars": data.dollars,
		"bounties_completed": _count_completed_bounties(data),
		"saved_at_unix": data.saved_at_unix,
	}


func _count_completed_bounties(data : SaveDataResource) -> int:
	var count := 0
	for bounty_id in data.bounty_states:
		if data.bounty_states[bounty_id].get("completed", false):
			count += 1
	return count


# Everything a playthrough owns, wound back to a brand-new game. Managers keep their progress in
# memory for the whole session and load_game() only overwrites what the file happens to mention -
# so without this, loading slot 2 after playing slot 1 would leave slot 1's items, kills and
# ticked-off objectives sitting underneath it.
func _reset_game_state() -> void:
	PlayerManager.player_name = ""
	CollectibleManager.reset_progress()
	InventoryManager.reset_progress()
	AbilityManager.reset_progress()
	QuestManager.reset_progress()
	GameStateManager.reset_progress()


# A save from before slots becomes slot 1. Only ever runs once - it moves the file rather than
# copying it, so there is nothing left to migrate on the next boot.
func _migrate_legacy_save_file() -> void:
	var legacy_path := save_path + LEGACY_SAVE_FILE
	if not FileAccess.file_exists(legacy_path) or has_save(1):
		return
	if DirAccess.rename_absolute(legacy_path, slot_path(1)) != OK:
		push_warning("SaveManager: could not move the pre-slots save into slot 1.")


func save_game():
	# Nothing to write into. Autosaves fire from a lot of places (a level's exit, closing the
	# inventory, quitting the game) and some of them can be reached from the menus, before a slot
	# has been picked.
	if active_slot == NO_SLOT:
		return

	var data := SaveDataResource.new()
	data.saved_at_unix = int(Time.get_unix_time_from_system())
	data.player_name = PlayerManager.player_name
	data.dollars = CollectibleManager.total_award_amount

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
		var completed_objectives : Array[String] = []
		for stage in bounty.stages:
			for objective in stage.objectives:
				if objective.completed:
					completed_objectives.append(objective.id)

		data.bounty_states[bounty.id] = {
			"unlocked": bounty.unlocked,
			"completed": bounty.completed,
			"reward_claimed": bounty.reward_claimed,
			"completed_objectives": completed_objectives,
		}

	for region in GameStateManager.regions:
		data.region_states[region.id] = region.unlocked

	# Every story beat in one go, so a beat added later needs no change here.
	data.story_flags = GameStateManager.story_flags.duplicate()

	if !DirAccess.dir_exists_absolute(save_path):
		DirAccess.make_dir_absolute(save_path)
	ResourceSaver.save(data, slot_path(active_slot))


# Applies the active slot's file on top of freshly-reset state. Always reached through load_slot(),
# which is what does the resetting - calling this on its own would layer a save over whatever the
# previous playthrough left in memory.
func load_game():
	if active_slot == NO_SLOT or not has_save(active_slot):
		return

	var data : SaveDataResource = ResourceLoader.load(slot_path(active_slot))
	if data == null:
		return

	PlayerManager.player_name = data.player_name
	CollectibleManager.total_award_amount = data.dollars

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

			# Objectives are stored as the ids that are done rather than as flags per line, so a save
			# made before a stage was rewritten restores what it can and ignores what no longer exists.
			var completed_objectives : Array = state.get("completed_objectives", [])
			for stage in bounty.stages:
				for objective in stage.objectives:
					objective.completed = completed_objectives.has(objective.id)

	for region in GameStateManager.regions:
		if data.region_states.has(region.id):
			region.unlocked = data.region_states[region.id]

	GameStateManager.story_flags = data.story_flags.duplicate()
	_migrate_legacy_story_flags(data)


# A save written before the story beats were pooled into one dictionary carries a bool field per
# beat instead. Copied across once, so a player mid-tutorial doesn't find the coyote back at the
# carcass and the Old Timer back in town the first time they launch a build with this in it.
func _migrate_legacy_story_flags(data : SaveDataResource) -> void:
	var legacy := {
		GameStateManager.FLAG_HUB_WELCOME_SHOWN: data.has_shown_hub_welcome,
		GameStateManager.FLAG_COYOTE_DRIVEN_OFF: data.has_driven_off_coyote,
	}
	for flag in legacy:
		if legacy[flag] and not GameStateManager.has_story_flag(flag):
			GameStateManager.set_story_flag(flag)

class_name SaveDataResource
extends Resource

# Item ownership/equipment is saved as resource paths rather than the resources themselves -
# ItemData/WeaponItemData/etc. are shared content templates (authored .tres files), not
# per-save data, so a save file only needs to remember *which* ones the player has.
@export var inventory_item_paths : Array[String] = []
@export var inventory_item_quantities : Array[int] = []

@export var equipped_primary_path : String = ""
@export var equipped_secondary_path : String = ""
@export var equipped_primary_ammo_path : String = ""
@export var equipped_secondary_ammo_path : String = ""
@export var equipped_utility_path : String = ""
@export var equipped_cosmetic_paths : Dictionary = {} # CosmeticItemData.CosmeticSlot(int) -> String
@export var equipped_primary_weapon_skin_path : String = ""
@export var equipped_secondary_weapon_skin_path : String = ""

@export var unlocked_ability_ids : Array[String] = []
@export var completed_quest_ids : Array[String] = []
@export var enemy_kill_counts : Dictionary = {} # enemy id -> kill count
@export var received_quest_paths : Array[String] = []

@export var bounty_states : Dictionary = {} # bounty id -> {unlocked, completed, reward_claimed}
@export var region_states : Dictionary = {} # region id -> unlocked

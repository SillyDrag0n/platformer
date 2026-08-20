extends Node2D

@onready var head : Sprite2D = $Head
@onready var body_attachment : Sprite2D = $BodyAttachment
@onready var accessory : Sprite2D = $Accessory


func _ready() -> void:
	InventoryManager.equipped_cosmetic_changed.connect(_on_equipped_cosmetic_changed)

	# Pick up whatever's already equipped (e.g. restored from a save) instead of only reacting to
	# future changes, so a cosmetic equipped before this node existed still renders immediately.
	_apply_slot(CosmeticItemData.CosmeticSlot.HAT, InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.HAT))
	_apply_slot(CosmeticItemData.CosmeticSlot.OUTFIT, InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.OUTFIT))
	_apply_slot(CosmeticItemData.CosmeticSlot.ACCESSORY, InventoryManager.get_equipped_cosmetic(CosmeticItemData.CosmeticSlot.ACCESSORY))


func _on_equipped_cosmetic_changed(slot : CosmeticItemData.CosmeticSlot, cosmetic : CosmeticItemData) -> void:
	# WEAPON_SKIN is handled by Gun itself (it already owns active_slot/weapon rendering) - ignore
	# it here rather than fighting over the same signal.
	_apply_slot(slot, cosmetic)


func _apply_slot(slot : CosmeticItemData.CosmeticSlot, cosmetic : CosmeticItemData) -> void:
	var texture : Texture2D = cosmetic.texture if cosmetic else null
	match slot:
		CosmeticItemData.CosmeticSlot.HAT:
			head.texture = texture
		CosmeticItemData.CosmeticSlot.OUTFIT:
			body_attachment.texture = texture
		CosmeticItemData.CosmeticSlot.ACCESSORY:
			accessory.texture = texture

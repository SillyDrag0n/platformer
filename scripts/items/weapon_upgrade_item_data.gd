class_name WeaponUpgradeItemData
extends ItemData

# A permanent modification bought for one specific weapon. Owning it is what fits it - there is no
# separate equip slot the way cosmetics and ammo have one - so it is bought once and stays fitted,
# and the save file already remembers it along with everything else in the bag (see
# SaveDataResource.inventory_item_paths).

# The weapon this was made for. An upgrade only does anything while that weapon is the one in
# hand, so the revolver's speed loader doesn't quietly improve the shotgun as well.
@export var target_weapon : WeaponItemData

# How much of the reload the active-reload sweet spot covers, as a fraction of the whole reload -
# 0.12 of the revolver's 1.5s reload is a window a bit under a fifth of a second wide. Gun.gd
# places a window this wide at random inside the bottom of the reload dial on every reload, and a
# reload press while the meter is inside it finishes the reload on the spot. 0 means no timing
# window at all, for an upgrade that does something else.
@export_range(0.0, 0.5, 0.01) var active_reload_window : float = 0.12

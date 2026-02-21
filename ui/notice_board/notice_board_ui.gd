extends CanvasLayer

@export var bounty_entry_scene : PackedScene
@export var bounty_container : GridContainer

func _ready():
    populate_bounties()

func populate_bounties():
    for child in bounty_container.get_children():
        child.queue_free()

    var available_bounties = BountyManager.get_available_bounties()

    for bounty_data in available_bounties:
        var entry = bounty_entry_scene.instantiate()
        bounty_container.add_child(entry)
        entry.setup(bounty_data)

class_name BountyObjectiveData
extends Resource

# One line on the bounty's checklist ("Go to the attack site"). Objectives are addressed by id from
# whatever ticks them off - a level, an NPC, an encounter - so the wording can be rewritten without
# touching the code that completes them.
#
# `completed` is runtime progress kept on the shared resource, same as BountyData's own
# unlocked/completed flags, and persisted by SaveManager alongside them.

@export var id : String
@export var text : String
@export var completed : bool = false

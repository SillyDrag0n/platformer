extends Node

var player: Node = null

# Set by NameEntryScreen on a new save, restored from SaveDataResource on an existing one (see
# SaveManager) - not tied to any one player instance, so it survives death/respawn.
var player_name : String = ""

signal player_spawned(player)
signal player_died()

signal snake_grab_started(jump_presses_required : int)
signal snake_grab_progress(press_count : int, jump_presses_required : int)
signal snake_grab_ended()
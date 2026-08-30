extends Node

var player: Node = null

# What the player character is called when nobody has asked yet: a blank entry on the name screen,
# a save made before that screen existed, or a level run straight from the editor without going
# through the main menu. Lives here rather than on NameEntryScreen so there is one answer to "what
# is the player called" instead of one per caller.
const DEFAULT_NAME := "Stranger"

# Set by NameEntryScreen on a new save, restored from SaveDataResource on an existing one (see
# SaveManager) - not tied to any one player instance, so it survives death/respawn.
var player_name : String = ""

signal player_spawned(player)
signal player_died()

signal snake_grab_started(jump_presses_required : int)
signal snake_grab_progress(press_count : int, jump_presses_required : int)
signal snake_grab_ended()


# The name to put in front of anything the player character says - see DialogueBox.PLAYER_TOKEN.
# Never empty, so a dialogue box can't end up crediting a line to nobody.
func get_display_name() -> String:
	return player_name if player_name.strip_edges() != "" else DEFAULT_NAME

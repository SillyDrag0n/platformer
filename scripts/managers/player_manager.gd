extends Node

var player: Node = null

signal player_spawned(player)
signal player_died()

signal snake_grab_started(jump_presses_required : int)
signal snake_grab_progress(press_count : int, jump_presses_required : int)
signal snake_grab_ended()
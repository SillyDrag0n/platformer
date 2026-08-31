class_name HubStructure
extends Node2D

# A building in town the player can walk into. Every one of them does the same three things -
# latch the door shut, remember where the player was stood so the hub can put them back there on
# the way out, and go somewhere - so they share this script and differ only by which scene key
# they lead to.
#
# A structure with no destination_scene_key is scenery the player can walk up to but not enter
# yet (the church, the railway station). Those deliberately leave the interactable armed: latching
# it off for a building that never transitions away would kill the prompt permanently the first
# time anyone pressed it.

@export var destination_scene_key : String = ""

@onready var interactable : Area2D = $Interactable


func _ready() -> void:
	interactable.interact = _on_interact


func _on_interact() -> void:
	if not can_enter():
		return
	interactable.is_interactable = false
	SceneManager.set_pending_spawn_position(PlayerManager.player.global_position)
	enter()


# False for scenery that isn't enterable yet - see the class comment.
func can_enter() -> bool:
	return destination_scene_key != ""


# What entering actually does. Overridden by structures that open a screen instead of loading a
# level (see tileset/structures/notice_board/notice_board.gd).
func enter() -> void:
	SceneManager.transition_to_scene_faded(destination_scene_key)

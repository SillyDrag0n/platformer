extends Node

# Routes every sound in the game onto its mixer bus.
#
# A sound declares which bus it belongs to by being in a group named after it - "SFX", "UI",
# "Music" - rather than by having `bus` set on the node. That indirection looks redundant and
# isn't, for one specific reason:
#
#   AudioStreamPlayer.get_bus() returns "Master" whenever the bus name it is holding is not
#   registered with the running AudioServer.
#
# So a Godot editor session that was started before default_bus_layout.tres gained a bus reads
# every player on that bus back as "Master", and writes that to disk the next time it saves the
# scene. player.tscn silently lost its five SFX tags three times in one session that way, and
# nothing in the running game said so - the gunshots just quietly stopped answering the SFX slider.
# A test caught it; nothing else would have.
#
# Group names are never validated against anything, so they survive that. Routing from them here
# means the tag cannot be lost by an editor save, and this file is where the next person finds out
# why the buses aren't just set on the nodes.

# Bus names come from SettingsManager.VOLUME_BUSES, so adding a category to the mixer needs no
# change here either. Master is skipped: it is the default, and everything ends up there anyway.


func _ready() -> void:
	# Every player in the game is spawned rather than pre-placed in some cases (the dynamite
	# explosion effect, for one), so routing has to happen as nodes arrive, not in a single sweep.
	get_tree().node_added.connect(route)
	_route_tree(get_tree().get_root())


# Public so a test - or a tool that builds players in code - can ask for one to be routed directly.
func route(node : Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	for bus_name in SettingsManager.VOLUME_BUSES:
		if bus_name != &"Master" and node.is_in_group(bus_name):
			node.bus = bus_name
			return


func _route_tree(node : Node) -> void:
	route(node)
	for child in node.get_children():
		_route_tree(child)

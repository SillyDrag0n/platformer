extends GutTest

# The mixer: one bus per category of sound, so the settings screen can turn the music down without
# taking the gunshots with it. See default_bus_layout.tres and SettingsManager.VOLUME_BUSES.
#
# The failure mode this guards is quiet rather than loud: a bus renamed in one place and not the
# other, or a new sound added without a bus, both leave a slider that silently does nothing.

# Scenes that own sounds, and the bus each of their players belongs on.
const TAGGED_SCENES := {
	"res://player/player.tscn": "SFX",
	"res://player/dynamite/dynamite_explosion_effect.tscn": "SFX",
	"res://scripts/managers/UiSoundPlayer.tscn": "UI",
	"res://ui/notice_board/notice_board_bounty.tscn": "UI",
}

var _original_volumes : Dictionary = {}


func before_each():
	_original_volumes.clear()
	for bus_name in SettingsManager.VOLUME_BUSES:
		_original_volumes[bus_name] = SettingsManager.get_bus_volume(bus_name)


func after_each():
	for bus_name in _original_volumes:
		SettingsManager.set_bus_volume(bus_name, _original_volumes[bus_name])


func _players_in(node : Node) -> Array:
	var found : Array = []
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_players_in(child))
	return found


func test_every_bus_the_settings_screen_offers_actually_exists():
	for bus_name in SettingsManager.VOLUME_BUSES:
		assert_ne(AudioServer.get_bus_index(bus_name), -1, \
			"'%s' is offered as a slider but is not in default_bus_layout.tres - the slider " % bus_name + \
			"would move nothing")


func test_every_category_bus_feeds_master():
	for bus_name in SettingsManager.VOLUME_BUSES:
		if bus_name == &"Master":
			continue
		var index := AudioServer.get_bus_index(bus_name)
		assert_eq(AudioServer.get_bus_send(index), &"Master", \
			"%s has to route through Master, or the Master slider stops being a master" % bus_name)


# The point of the tags. A sound left on Master answers to nothing but the master slider.
#
# The bus is declared by group membership and applied by AudioBuses when the node enters the tree,
# so this exercises the whole route: the group is on the node in the scene, and something acts on
# it. See scripts/managers/audio_buses.gd for why it is not simply set on the node.
func test_every_sound_in_the_game_is_tagged_onto_a_category_bus():
	for scene_path in TAGGED_SCENES:
		var scene = load(scene_path).instantiate()
		add_child_autofree(scene)
		await wait_frames(1)

		var players := _players_in(scene)
		assert_gt(players.size(), 0, "%s should still own the sounds this expects" % scene_path)
		for player in players:
			assert_true(player.is_in_group(TAGGED_SCENES[scene_path]), \
				"%s in %s has lost its bus group" % [player.name, scene_path])
			assert_eq(String(player.bus), TAGGED_SCENES[scene_path], \
				"%s in %s is untagged - it would ignore its category's slider" % [player.name, scene_path])


# A player built in code, never authored in a scene, still gets routed - which is the case the
# dynamite explosion effect and anything else spawned mid-level rely on.
func test_a_sound_spawned_at_runtime_is_routed_too():
	var player := AudioStreamPlayer.new()
	player.add_to_group(&"SFX")
	add_child_autofree(player)
	await wait_frames(1)

	assert_eq(String(player.bus), "SFX", \
		"AudioBuses listens for nodes entering the tree, not just what was there at startup")


# Nothing else should be quietly moved off Master.
func test_an_untagged_sound_is_left_alone():
	var player := AudioStreamPlayer.new()
	add_child_autofree(player)
	await wait_frames(1)

	assert_eq(String(player.bus), "Master", "a sound with no bus group keeps Godot's default")


func test_setting_a_bus_volume_moves_that_bus_and_is_remembered():
	SettingsManager.set_bus_volume(&"Music", 0.5)

	assert_almost_eq(SettingsManager.get_bus_volume(&"Music"), 0.5, 0.001)
	var index := AudioServer.get_bus_index(&"Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01, \
		"the slider has to actually move the mixer, not just record a number")


func test_each_bus_is_independent():
	SettingsManager.set_bus_volume(&"Music", 0.0)
	SettingsManager.set_bus_volume(&"SFX", 1.0)

	assert_almost_eq(SettingsManager.get_bus_volume(&"SFX"), 1.0, 0.001, \
		"turning the music off is the whole reason these are separate - it must not touch SFX")


# linear_to_db(0.0) is -inf, which the audio server will not take. The bottom of a slider has to
# mean silence rather than an error.
func test_a_bus_turned_all_the_way_down_is_silent_rather_than_broken():
	SettingsManager.set_bus_volume(&"Music", 0.0)

	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
	assert_true(is_finite(db), "a finite dB value, not -inf")
	assert_lt(db, -60.0, "and low enough to be silence")


func test_volume_is_clamped_to_the_sliders_range():
	SettingsManager.set_bus_volume(&"Music", 4.0)
	assert_almost_eq(SettingsManager.get_bus_volume(&"Music"), 1.0, 0.001, "no boosting past full")

	SettingsManager.set_bus_volume(&"Music", -1.0)
	assert_almost_eq(SettingsManager.get_bus_volume(&"Music"), 0.0, 0.001, "and no negative volume")


# The names live in two files. A bus dropped from the layout should cost the player that one
# slider, not the whole settings screen.
func test_an_unknown_bus_is_survivable():
	SettingsManager.set_bus_volume(&"NoSuchBus", 0.5)

	assert_almost_eq(SettingsManager.get_bus_volume(&"NoSuchBus"), 0.5, 0.001, \
		"reached this line without a crash - the value is kept even though no bus took it")
	SettingsManager.settings_data.bus_volumes.erase("NoSuchBus")


# A settings file written before the mixer existed only knows about master_volume.
func test_a_settings_file_from_before_the_mixer_keeps_its_volume():
	var settings := SettingsManager.settings_data
	var real_volumes : Dictionary = settings.bus_volumes
	var real_master : float = settings.master_volume

	settings.bus_volumes = {}
	settings.master_volume = 0.3
	SettingsManager._migrate_legacy_master_volume()

	assert_almost_eq(float(settings.bus_volumes.get("Master", -1.0)), 0.3, 0.001, \
		"a player who had turned the game down should not get it back at full volume")

	settings.bus_volumes = real_volumes
	settings.master_volume = real_master

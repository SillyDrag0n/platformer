extends GutTest

# Coverage for HintZone (interaction_component/hint_zone.gd) - the reusable Area2D trigger that
# fires a GameScreen hint once when the player walks into it, used throughout the tutorial bounty.
# Calls _on_hint_zone_body_entered() directly rather than relying on real physics overlap
# detection, which would need precise shape/position setup and a physics tick to resolve.

const HintZoneScene = preload("res://interaction_component/hint_zone.tscn")
const GameScreenScene = preload("res://ui/screens/game_screen.tscn")


func _make_fake_player() -> Node2D:
	var body := Node2D.new()
	body.add_to_group("Player")
	return body


func _make_zone() -> Area2D:
	var zone = HintZoneScene.instantiate()
	zone.watch_action = &"jump"
	zone.hint_text_format = "Press %s to Jump"
	return zone


func test_body_entering_shows_the_hint_on_the_hud():
	var hud = GameScreenScene.instantiate()
	add_child_autofree(hud)
	var zone = _make_zone()
	add_child_autofree(zone)
	var player := _make_fake_player()
	add_child_autofree(player)

	zone._on_hint_zone_body_entered(player)

	assert_true(hud.action_hint.visible)


func test_only_fires_once():
	var hud = GameScreenScene.instantiate()
	add_child_autofree(hud)
	var zone = _make_zone()
	add_child_autofree(zone)
	var player := _make_fake_player()
	add_child_autofree(player)

	zone._on_hint_zone_body_entered(player)
	hud._dismiss_hint()
	zone._on_hint_zone_body_entered(player)

	assert_false(hud._hint_showing, \
		"a second entry into an already-fired HintZone should not re-show the hint")


func test_ignores_bodies_not_in_the_player_group():
	var hud = GameScreenScene.instantiate()
	add_child_autofree(hud)
	var zone = _make_zone()
	add_child_autofree(zone)
	var not_player := Node2D.new()
	add_child_autofree(not_player)

	zone._on_hint_zone_body_entered(not_player)

	assert_false(hud.action_hint.visible)

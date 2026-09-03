extends GutTest

# Money: the dollars a bandit drops, taking them, and the two places the total is shown.
#
# All three had something wrong with them at once - the drop was drawn under the ground dressing
# painted on top of it, the pickup could pay out more than once, and the HUD's coin icon pointed at
# a texture that had been deleted out of the project (it rendered as nothing at all).

const DollarPickupScene = preload("res://collectibles/dollar_pickup/dollar_pickup.tscn")
const DynamitePickupScene = preload("res://pickups/dynamite_pickup/dynamite_pickup.tscn")
const GameScreenScene = preload("res://ui/screens/game_screen.tscn")
const InventoryUIScene = preload("res://ui/inventory/InventoryUI.tscn")

# What a level's TileMapDecorations layer sits at. Anything a pickup has to be seen against is
# painted there.
const DECORATION_LAYER_Z := 30

var _original_total : int


func before_each():
	_original_total = CollectibleManager.total_award_amount
	CollectibleManager.total_award_amount = 0
	InventoryManager.is_open = false
	# A number floats for the better part of a second and a chime rings for a quarter of one, both
	# longer than a test takes. Left in place, either would be found by the test after this one.
	for award in get_tree().get_nodes_in_group(FloatingAward.GROUP):
		award.free()
	for sound in get_tree().get_nodes_in_group(PickupSound.GROUP):
		sound.free()


func after_each():
	CollectibleManager.total_award_amount = _original_total
	InventoryManager.is_open = false


func _a_body_in_the_player_group() -> Node2D:
	var body := CharacterBody2D.new()
	body.add_to_group("Player")
	add_child_autofree(body)
	return body


func test_a_dropped_dollar_is_drawn_with_the_ground_dressing_rather_than_under_it():
	var pickup = DollarPickupScene.instantiate()
	add_child_autofree(pickup)
	await wait_physics_frames(1)

	assert_eq(pickup.z_index, DECORATION_LAYER_Z, \
		"at the default 0 it goes under every tuft of grass painted over the dirt it landed on")


# The same for the other thing a bandit drops. It is a plain Node2D rather than a Collectible, so
# what the two share is PickupDrop - which is why the z-index lives there and not on either of
# them: anything dropped on the ground has to be seen against it.
func test_so_is_dropped_dynamite():
	var pickup = DynamitePickupScene.instantiate()
	add_child_autofree(pickup)
	await wait_physics_frames(1)

	assert_eq(pickup.z_index, DECORATION_LAYER_Z, \
		"a stick of dynamite in the dirt has the same problem a dollar does")


func test_one_dollar_pays_out_once():
	var pickup = DollarPickupScene.instantiate()
	pickup.award_amount = 5
	add_child_autofree(pickup)
	await wait_physics_frames(1)
	var body := _a_body_in_the_player_group()

	pickup._on_area_2d_body_entered(body)
	# queue_free() only lands at the end of the frame, so the shape is still there for the rest of
	# this one.
	pickup._on_area_2d_body_entered(body)
	await wait_physics_frames(1)

	assert_eq(CollectibleManager.total_award_amount, 5, \
		"standing in the drop should not be paid for the same dollar twice")


func test_anything_that_is_not_the_player_walks_straight_past_it():
	var pickup = DollarPickupScene.instantiate()
	add_child_autofree(pickup)
	await wait_physics_frames(1)

	var bandit := CharacterBody2D.new()
	add_child_autofree(bandit)
	pickup._on_area_2d_body_entered(bandit)

	assert_eq(CollectibleManager.total_award_amount, 0)


# The HUD icon was an ExtResource pointing at res://collectibles/coins-and-gems.png, a file no
# longer in the project - Godot reports that at import time and then draws nothing, which is easy
# to miss in a corner of the screen. Pinning that the texture resolves catches the next one.
func test_the_huds_money_icon_is_a_texture_that_actually_exists():
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	var icon : TextureRect = screen.get_node("MarginContainer/VBoxContainer/HBoxContainer/CollectibleIcon")
	assert_not_null(icon.texture, "the HUD has to have something to draw next to the number")
	assert_gt(icon.texture.get_width(), 0, "and it has to have resolved to real pixels")


func test_the_journal_says_how_much_the_player_is_carrying():
	CollectibleManager.total_award_amount = 42
	var inventory = InventoryUIScene.instantiate()
	add_child_autofree(inventory)
	await wait_physics_frames(2)

	assert_not_null(inventory.money_label, "the journal needs somewhere to say it")
	assert_string_contains(inventory.money_label.text, "42", \
		"opened after the money was earned, it still has to show the total - reading the manager " + \
		"rather than waiting for a signal that already fired")


func test_the_journals_total_follows_money_earned_while_it_is_open():
	var inventory = InventoryUIScene.instantiate()
	add_child_autofree(inventory)
	await wait_physics_frames(2)

	CollectibleManager.give_pickup_award(7)
	await wait_physics_frames(1)

	assert_string_contains(inventory.money_label.text, "7")


# The number used to be a Label on the dollar itself, so it appeared wherever the coin had rolled
# to - off to one side, and behind the player as often as not. These pin where it goes now.
func test_the_number_floats_over_the_player_rather_than_over_the_coin():
	var pickup = DollarPickupScene.instantiate()
	pickup.award_amount = 3
	add_child_autofree(pickup)
	var body := _a_body_in_the_player_group()
	body.global_position = Vector2(400, 100)
	pickup.global_position = Vector2(120, 100)
	await wait_physics_frames(1)

	pickup._on_area_2d_body_entered(body)
	await wait_physics_frames(1)

	var award = get_tree().get_first_node_in_group(FloatingAward.GROUP)
	assert_not_null(award, "taking money should say so somewhere")
	assert_almost_eq(award.global_position.x, body.global_position.x, 1.0, \
		"over the player, not back where the coin was")
	assert_lt(award.global_position.y, body.global_position.y, "and above their head")
	assert_string_contains(award.label.text, "3", "saying what was just picked up")
	assert_gt(award.z_index, 70, \
		"above the foreground tiles - a number that can hide behind a rock is not feedback")


func test_two_dollars_taken_together_make_one_number_rather_than_two_stacked_ones():
	var body := _a_body_in_the_player_group()
	var first = DollarPickupScene.instantiate()
	var second = DollarPickupScene.instantiate()
	first.award_amount = 2
	second.award_amount = 4
	add_child_autofree(first)
	add_child_autofree(second)
	await wait_physics_frames(1)

	first._on_area_2d_body_entered(body)
	second._on_area_2d_body_entered(body)
	await wait_physics_frames(1)

	var awards := get_tree().get_nodes_in_group(FloatingAward.GROUP)
	assert_eq(awards.size(), 1, "two labels drawn over each other on the same spot reads as one " + \
		"unreadable smudge, so the second adds to the first")
	assert_string_contains(awards[0].label.text, "6", "and it says what they came to together")


# Taking something off the ground says so out loud as well. The sound cannot live on the pickup -
# that frees itself the same frame - so it is spawned in its place and frees itself when it has
# finished ringing (see pickups/_common/pickup_sound.gd).
func test_taking_a_dollar_makes_a_sound():
	var pickup = DollarPickupScene.instantiate()
	add_child_autofree(pickup)
	await wait_physics_frames(1)

	pickup._on_area_2d_body_entered(_a_body_in_the_player_group())
	await wait_physics_frames(1)

	var sounds := get_tree().get_nodes_in_group(PickupSound.GROUP)
	assert_eq(sounds.size(), 1, "one chime for one dollar")
	assert_true(sounds[0].playing, "and it is actually ringing rather than sitting there silent")
	assert_true(sounds[0].is_in_group("SFX"), \
		"tagged for the SFX bus by group, never by node - see scripts/managers/audio_buses.gd")


func test_a_handful_taken_at_once_does_not_stack_the_same_sample_on_itself():
	var body := _a_body_in_the_player_group()
	var handful : Array = []
	for i in 4:
		var pickup = DollarPickupScene.instantiate()
		add_child_autofree(pickup)
		handful.append(pickup)
	await wait_physics_frames(1)

	# All four in the same frame, the way walking through a scattered drop takes them.
	for pickup in handful:
		pickup._on_area_2d_body_entered(body)
	await wait_physics_frames(1)

	assert_eq(get_tree().get_nodes_in_group(PickupSound.GROUP).size(), 1, \
		"four copies of one sample inside a frame phase into a single clipped blat rather than " + \
		"sounding four times as good")
	assert_eq(CollectibleManager.total_award_amount, 4, \
		"though every one of them is still paid for - it is the sound that is folded, not the money")


# Every level scene instances its own game_screen.tscn, so the HUD is rebuilt from scratch on each
# scene change - and it used to be wired to the award signal alone, which only ever reports money
# earned since it was built. Walking into a level with a full wallet showed the .tscn's hardcoded
# "0" while the journal, which reads the manager directly, showed the truth.
func test_the_hud_shows_money_earned_before_it_was_built():
	CollectibleManager.total_award_amount = 240
	var screen = GameScreenScene.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)

	assert_eq(screen.collectible_label.text, "$240", \
		"a HUD built after the money was earned still has to say how much there is")


func test_the_two_readouts_agree_after_a_scene_change():
	CollectibleManager.total_award_amount = 0
	var inventory = InventoryUIScene.instantiate()
	add_child_autofree(inventory)
	var first_screen = GameScreenScene.instantiate()
	add_child_autofree(first_screen)
	await wait_physics_frames(2)

	CollectibleManager.give_pickup_award(15)
	await wait_physics_frames(1)

	# The level ends and the next one brings its own HUD along, while the journal survives as an
	# autoloaded screen - which is how the two came to disagree in the first place.
	first_screen.free()
	var second_screen = GameScreenScene.instantiate()
	add_child_autofree(second_screen)
	await wait_physics_frames(1)

	assert_string_contains(inventory.money_label.text, "15", "the journal kept up")
	assert_eq(second_screen.collectible_label.text, "$15", \
		"and the new level's HUD has to arrive carrying the same number, not start over at zero")

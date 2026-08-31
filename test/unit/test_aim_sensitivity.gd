extends GutTest

# The Aim Sensitivity slider sets how fast the aim direction turns to follow the right stick
# (GameInputEvents.aim_turn_speed()). It read as doing nothing because the mapping was linear in
# turn *rate*, while what a player feels is the time a flick takes - the reciprocal. The halfway
# mark landed at 31 rad/s, a 180 turn in a tenth of a second, already indistinguishable from
# instant, so the entire top half of the slider felt the same.

var _original_sensitivity : float

# How long a 180 degree flick takes at a given setting - the thing the player actually feels.
func _half_turn_seconds(sensitivity : float) -> float:
	GameInputEvents.aim_sensitivity = sensitivity
	return PI / GameInputEvents.aim_turn_speed()


func before_each():
	_original_sensitivity = GameInputEvents.aim_sensitivity


func after_each():
	GameInputEvents.aim_sensitivity = _original_sensitivity


func test_the_ends_of_the_slider_are_the_authored_limits():
	GameInputEvents.aim_sensitivity = 0.0
	assert_almost_eq(GameInputEvents.aim_turn_speed(), GameInputEvents.AIM_TURN_SPEED_MIN, 0.01)

	GameInputEvents.aim_sensitivity = 1.0
	assert_almost_eq(GameInputEvents.aim_turn_speed(), GameInputEvents.AIM_TURN_SPEED_MAX, 0.01)


func test_a_setting_outside_the_slider_is_clamped():
	GameInputEvents.aim_sensitivity = 5.0
	assert_almost_eq(GameInputEvents.aim_turn_speed(), GameInputEvents.AIM_TURN_SPEED_MAX, 0.01)

	GameInputEvents.aim_sensitivity = -2.0
	assert_almost_eq(GameInputEvents.aim_turn_speed(), GameInputEvents.AIM_TURN_SPEED_MIN, 0.01)


func test_turning_the_slider_up_always_turns_faster():
	var previous := 0.0
	for step in 21:
		GameInputEvents.aim_sensitivity = float(step) / 20.0
		var speed := GameInputEvents.aim_turn_speed()
		assert_gt(speed, previous, "every notch of the slider has to be faster than the one below")
		previous = speed


# The actual complaint. The midpoint used to be effectively instant, so half the slider was dead
# travel - a flick at 0.5 has to feel clearly heavier than one at full.
func test_the_middle_of_the_slider_is_nowhere_near_instant():
	var middle := _half_turn_seconds(0.5)
	var fastest := _half_turn_seconds(1.0)

	assert_gt(middle, 0.2, \
		"a half-turn at the midpoint should take long enough to feel, not a tenth of a second")
	assert_gt(middle / fastest, 4.0, \
		"and it should be several times slower than the top of the slider, not a hair slower")


func test_the_slowest_setting_is_genuinely_heavy():
	assert_gt(_half_turn_seconds(0.0), 1.0, \
		"the bottom of the slider should read as dragging a heavy gun around")


func test_the_fastest_setting_is_effectively_instant():
	assert_lt(_half_turn_seconds(1.0), 0.1, \
		"the top of the slider should keep up with anything the player flicks")


# Spread evenly across the travel rather than bunched at one end: each quarter of the slider should
# roughly halve the time a flick takes, so the whole range is usable.
func test_the_slider_spreads_its_range_across_its_whole_travel():
	var quarters : Array[float] = []
	for i in 5:
		quarters.append(_half_turn_seconds(float(i) / 4.0))

	for i in range(1, quarters.size()):
		var ratio := quarters[i - 1] / quarters[i]
		assert_almost_eq(ratio, 2.34, 0.3, \
			"quarter %d should be about twice as quick as the one before it" % i)

extends GutTest

const HealthManagerScript = preload("res://scripts/managers/health_manager.gd")

var health


func before_each():
	health = HealthManagerScript.new()
	add_child_autofree(health)


func test_starts_at_max_health():
	assert_eq(health.current_health, health.max_health)


func test_decrease_health_reduces_current_health():
	health.decrease_health(1)
	assert_eq(health.current_health, health.max_health - 1)


func test_decrease_health_does_not_go_below_zero():
	health.decrease_health(health.max_health + 10)
	assert_eq(health.current_health, 0.0)


func test_decrease_health_while_invulnerable_is_a_no_op():
	health.decrease_health(1)
	var health_after_first_hit = health.current_health

	health.decrease_health(1) # still invulnerable from the first hit's timer
	assert_eq(health.current_health, health_after_first_hit, \
		"a second hit before the invulnerability timer clears should deal no damage")


func test_invulnerability_clears_once_the_timer_fires():
	health.decrease_health(1)
	assert_true(health.invulnerable)

	health._on_timer_timeout() # simulate the Timer completing without waiting for it
	assert_false(health.invulnerable)

	var health_before = health.current_health
	health.decrease_health(1)
	assert_eq(health.current_health, health_before - 1, \
		"damage should apply again once invulnerability has cleared")


func test_increase_health_does_not_exceed_max_health():
	health.increase_health(999)
	assert_eq(health.current_health, health.max_health)


func test_increase_health_restores_lost_health():
	health.decrease_health(1)
	health.increase_health(0.5)
	assert_eq(health.current_health, health.max_health - 0.5)


func test_set_health_max_resets_current_health():
	health.decrease_health(1)
	health.set_health_max()
	assert_eq(health.current_health, health.max_health)

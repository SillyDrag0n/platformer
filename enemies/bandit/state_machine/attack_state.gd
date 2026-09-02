extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D

# Brief pause on the "popped up and aiming" pose before the shot actually fires, so the player
# gets a readable beat to react before ducking back down to reload.
const AIM_DURATION : float = 0.5

var timer : float
var has_fired : bool

# Set by state_machine_controller.gd when the player leaves the attack range mid-aim. The shot is
# already committed at that point, so it still goes off - see the note there for why the bandit is
# no longer yanked straight out of the pose.
var chase_after_firing : bool


func enter():
	animated_sprite_2d.play("attack")
	character_body_2d.set_chase(false)
	timer = AIM_DURATION
	has_fired = false
	chase_after_firing = false


func physics_update(delta):
	timer -= delta
	if timer <= 0 and not has_fired:
		has_fired = true
		character_body_2d.shoot()
		# Straight after the player if they walked out while he was lining it up. Ducking into a
		# reload here would leave him crouched behind cover from someone who has already gone,
		# and it is the chase the player is owed after being shot at.
		return "Chase" if chase_after_firing else "Reload"
	return null


func exit():
	animated_sprite_2d.stop()

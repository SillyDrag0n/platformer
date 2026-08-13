extends NodeState

@export var boss: BossStateController
@export var Sprite: AnimatedSprite2D


func _on_intro_finished():
	boss.finite_state_machine.transition_to("move")


func enter():
	boss.play_animation(boss.Animations.Intro)
	Sprite.animation_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)

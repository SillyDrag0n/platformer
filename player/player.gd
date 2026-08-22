extends CharacterBody2D

const DEADEYE_TIME_SCALE := 0.35
const HIT_FLASH_SHADER : Shader = preload("res://player/player_hit_flash_shader.tres")
# Slightly longer than the "death" animation's own length (0.4s, see player.tscn) so the collapse
# has visibly settled into its final pose before the poof effect/death screen cut it short.
const DEATH_POSE_DURATION := 0.5

var player_death_effect = preload("res://player/player_death_effect/player_death_effect.tscn")

@onready var state_machine : NodeFiniteStateMachine = $StateMachine

@onready var body_sprites : Array[Sprite2D] = [
	$Animation/Body/Torso,
	$Animation/Bones/Skeleton2D/Hip/LegR/LegR,
	$Animation/Bones/Skeleton2D/Hip/LegR/ShinR/ShinR,
	$Animation/Bones/Skeleton2D/Hip/LegR/ShinR/FootR/FootR,
	$Animation/Bones/Skeleton2D/Hip/ArmR/ArmR,
	$Animation/Bones/Skeleton2D/Hip/ArmR/ForearmR/ForearmR,
	$Animation/Bones/Skeleton2D/Hip/ArmL/ArmL,
	$Animation/Bones/Skeleton2D/Hip/ArmL/ForearmL/ForearmL,
	$Animation/Bones/Skeleton2D/Hip/LegL/LegL,
	$Animation/Bones/Skeleton2D/Hip/LegL/ShinL/ShinL,
	$Animation/Bones/Skeleton2D/Hip/LegL/ShinL/FootL/FootL,
	$Animation/Bones/Skeleton2D/Hip/Head/Head,
]

var hit_flash_material : ShaderMaterial

var is_invulnerable : bool = false
var is_shooting : bool = false

func _ready() -> void:
	PlayerManager.player = self
	PlayerManager.player_spawned.emit(self)

	# One shared material across every body-part sprite so a single tween flashes the whole rig
	# at once, instead of needing a separate material/tween per limb.
	hit_flash_material = ShaderMaterial.new()
	hit_flash_material.shader = HIT_FLASH_SHADER
	for sprite in body_sprites:
		sprite.material = hit_flash_material


func _process(_delta) -> void:
	if AbilityManager.is_unlocked("deadeye") and GameInputEvents.deadeye_input():
		Engine.time_scale = DEADEYE_TIME_SCALE
	elif Engine.time_scale != 1.0:
		Engine.time_scale = 1.0

	# Shooting is a plain state-independent flag now rather than living inside ground-only shoot
	# states - gated to Normal so Dash/Grapple/Hurt/Dead still can't fire, matching what those
	# states already never allowed.
	is_shooting = GameInputEvents.shoot_input() and state_machine.current_node_state.name.to_lower() == "normal"


func set_invulnerable(value : bool) -> void:
	is_invulnerable = value


func player_death() -> void:
	# Reset immediately (not after the delay below) so a deadeye-slowed death still plays the
	# collapse pose and poof effect at normal speed rather than in slow motion.
	Engine.time_scale = 1.0
	await get_tree().create_timer(DEATH_POSE_DURATION).timeout

	var player_death_effect_instance = player_death_effect.instantiate() as Node2D
	player_death_effect_instance.global_position = global_position
	get_parent().add_child(player_death_effect_instance)
	PlayerManager.player_died.emit()
	queue_free()


func _on_hurtbox_body_entered(body : Node2D):
	if body.is_in_group("Enemy"):
		take_hit(body.damage_amount)


func _on_hurtbox_area_entered(area : Area2D) -> void:
	var source := area.get_parent()
	if source != null and source.has_method("get_damage_amount"):
		take_hit(source.get_damage_amount())


func take_hit(damage : int):
	if is_invulnerable:
		return
	flash_hit()
	HealthManager.decrease_health(damage)
	if HealthManager.current_health == 0:
		state_machine.transition_to("Dead")
	else:
		state_machine.transition_to("Hurt")


func flash_hit():
	var tween = get_tree().create_tween()
	tween.tween_property(hit_flash_material, "shader_parameter/enabled", true, 0)
	tween.tween_property(hit_flash_material, "shader_parameter/enabled", false, 0.2)


func _exit_tree():
	Engine.time_scale = 1.0
	if PlayerManager.player == self:
		PlayerManager.player = null
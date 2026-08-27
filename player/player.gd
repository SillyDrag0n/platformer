extends CharacterBody2D

const DEADEYE_TIME_SCALE := 0.35
const HIT_FLASH_SHADER : Shader = preload("res://player/player_hit_flash_shader.tres")
# Slightly longer than the "death" animation's own length (0.4s, see player.tscn) so the collapse
# has visibly settled into its final pose before the poof effect/death screen cut it short.
const DEATH_POSE_DURATION := 0.5
# One-time horizontal nudge on getting hit, so lower_body_controller.gd's procedural hurt pose
# (which staggers opposite current velocity) has real motion to react to even when the player was
# standing still - matches release_jump_boost's magnitude in grapple_state.gd for a similarly
# small "pop", not a heavy launch.
const HURT_KNOCKBACK_SPEED := 150.0

var player_death_effect = preload("res://player/player_death_effect/player_death_effect.tscn")

@onready var state_machine : NodeFiniteStateMachine = $StateMachine
@onready var dynamite_thrower : Node = $DynamiteThrower

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
	is_shooting = GameInputEvents.shoot_input() \
		and state_machine.current_node_state.name.to_lower() == "normal" \
		and dynamite_thrower.held_dynamite == null


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
		take_hit(body.damage_amount, body)


func _on_hurtbox_area_entered(area : Area2D) -> void:
	var source := area.get_parent()
	if source != null and source.has_method("get_damage_amount"):
		take_hit(source.get_damage_amount(), source if source is Node2D else null)


func take_hit(damage : int, source : Node2D = null):
	if is_invulnerable:
		return
	flash_hit()
	HealthManager.decrease_health(damage)
	if HealthManager.current_health == 0:
		state_machine.transition_to("Dead")
		return
	apply_hurt_knockback(source)
	state_machine.transition_to("Hurt")


# Gives lower_body_controller.gd's procedural hurt pose (which reads current velocity) real
# motion to stagger against, even if the player was standing still when hit. Pushes away from
# whatever dealt the damage; falls back to opposite the player's current motion if no source
# position is available (e.g. damage from a hazard that isn't a Node2D).
func apply_hurt_knockback(source : Node2D) -> void:
	var knockback_dir : float
	if source != null:
		knockback_dir = signf(global_position.x - source.global_position.x)
		if knockback_dir == 0.0:
			knockback_dir = 1.0
	else:
		knockback_dir = -signf(velocity.x) if velocity.x != 0.0 else 1.0
	velocity.x = knockback_dir * HURT_KNOCKBACK_SPEED


func flash_hit():
	var tween = get_tree().create_tween()
	tween.tween_property(hit_flash_material, "shader_parameter/enabled", true, 0)
	tween.tween_property(hit_flash_material, "shader_parameter/enabled", false, 0.2)


func _exit_tree():
	Engine.time_scale = 1.0
	if PlayerManager.player == self:
		PlayerManager.player = null
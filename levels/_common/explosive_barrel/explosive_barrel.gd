extends StaticBody2D

# A barrel of blasting powder left standing in a level: solid enough to stand on or hide behind,
# until something damages it. Shoot it, catch it in a blast, and it goes off - hurting enemies,
# hurting the player who lit it from too close, opening breakable terrain, and setting off any
# other barrel in range. The blast itself is Explosion's (scripts/explosion.gd), the same one the
# player's dynamite uses, so a barrel and a thrown stick can never drift apart in what they do.
#
# It carries a short fuse rather than going off on the hit that kills it. That gives the player a
# beat to get clear of one they shot from too close, and staggers a row of them into a visible
# chain instead of one indistinguishable bang.

const Explosion = preload("res://scripts/explosion.gd")
const HIT_FLASH_SHADER : Shader = preload("res://player/player_hit_flash_shader.tres")

const FUSE_FLASH_COLOR := Color(1, 0.35, 0.2, 1)
const FUSE_FLASH_INTERVAL : float = 0.06

@export var health_amount : int = 1
@export var explosion_damage : int = 4

# Deliberately wider than dynamite's 64: a barrel is a fixed piece of level furniture the player
# has to plan around, rather than something they can place, so it earns a blast worth planning for.
@export var explosion_radius : float = 88.0

# Long enough to read as a fuse and to run from, short enough that it never feels like a dud.
@export var fuse_time : float = 0.35

var _detonating : bool = false

@onready var sprite : Sprite2D = $Sprite


func take_damage(amount : int) -> void:
	# Everything that can hurt a barrel routes through here - bullets via the hurtbox below, and
	# other explosions via Explosion's chain step - so the fuse guard only has to exist once.
	# Without it a pair of barrels inside each other's radius would set each other off forever.
	if _detonating:
		return

	health_amount -= amount
	_flash_hit()
	if health_amount <= 0:
		light_fuse()


func light_fuse() -> void:
	if _detonating:
		return
	_detonating = true

	var flashes : int = maxi(1, int(fuse_time / FUSE_FLASH_INTERVAL))
	var tween := create_tween()
	for i in flashes:
		tween.tween_property(sprite, "modulate", FUSE_FLASH_COLOR, FUSE_FLASH_INTERVAL * 0.5)
		tween.tween_property(sprite, "modulate", Color.WHITE, FUSE_FLASH_INTERVAL * 0.5)
	tween.tween_callback(explode)


func explode() -> void:
	Explosion.detonate(self, explosion_damage, explosion_radius)
	queue_free()


# Mirrors Enemy.flash_hit() - same shader, same timing - so a barrel taking a bullet reads exactly
# like anything else in the game taking one.
func _flash_hit() -> void:
	if sprite.material == null:
		var flash_material := ShaderMaterial.new()
		flash_material.shader = HIT_FLASH_SHADER
		sprite.material = flash_material
	var tween := create_tween()
	tween.tween_property(sprite, "material:shader_parameter/enabled", true, 0)
	tween.tween_property(sprite, "material:shader_parameter/enabled", false, 0.2)


# Same shape as Enemy._on_hurtbox_area_entered(): whatever owns the incoming hitbox is asked how
# hard it hits, rather than the barrel knowing anything about bullets.
#
# The hurtbox detects the bullet rather than the other way round - it sits on no layer at all, only
# masking PlayerAttack. The barrel's own body is already on Ground, which is what stops the bullet
# and spawns its impact, so putting the hurtbox on a layer bullets scan for too would just spawn a
# second impact effect on top of the first (which is what enemies, whose body and hurtbox share the
# Enemy layer, currently do).
func _on_hurtbox_area_entered(area : Area2D) -> void:
	var source := area.get_parent()
	if source != null and source.has_method("get_damage_amount"):
		take_damage(source.get_damage_amount())

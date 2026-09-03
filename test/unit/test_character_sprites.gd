extends GutTest

# Who the townspeople and the outlaws actually look like. Two things are easy to lose silently: a
# per-instance texture override (an editor re-save has quietly dropped node overrides in this
# project before), and an animation frame pointing at a texture that no longer resolves - Godot
# reports that once at import and then draws nothing.

const SaloonScene = preload("res://levels/hub/saloon_interior/saloon_interior.tscn")
const BanditScene = preload("res://enemies/bandit/bandit.tscn")
const SHARED_SHOPKEEPER = preload("res://npc/shop_npc.svg")
const ROSA = preload("res://npc/rosa.svg")


func test_rosa_has_her_own_face_rather_than_the_shared_shopkeepers():
	var saloon = SaloonScene.instantiate()
	add_child_autofree(saloon)
	await wait_physics_frames(2)

	var sprite : Sprite2D = saloon.get_node("Barkeep/Sprite2D")
	assert_eq(sprite.texture, ROSA, "the saloon's barkeep is Rosa, not a second arms dealer")
	assert_ne(sprite.texture, SHARED_SHOPKEEPER, \
		"ShopNPC.tscn still ships the shared sprite as its default, so this only holds while the " + \
		"override on the Barkeep instance survives")


func test_every_bandit_animation_draws_something():
	var bandit = BanditScene.instantiate()
	add_child_autofree(bandit)
	await wait_physics_frames(1)

	var frames : SpriteFrames = bandit.get_node("AnimatedSprite2D").sprite_frames
	var seen : Array = []
	for animation in ["idle", "walk", "aggro", "attack"]:
		assert_true(frames.has_animation(animation), "the state machine plays %s" % animation)
		var texture : Texture2D = frames.get_frame_texture(animation, 0)
		assert_not_null(texture, "%s has to have a frame to draw" % animation)
		assert_eq(texture.get_size(), Vector2(32, 32 * 2), \
			"%s has to stay on the 32x64 canvas the AtlasTexture regions cut from" % animation)
		assert_false(seen.has(texture.atlas.resource_path), \
			"%s needs its own art - four states sharing one frame is a bandit that never " % animation + \
			"visibly reacts")
		seen.append(texture.atlas.resource_path)

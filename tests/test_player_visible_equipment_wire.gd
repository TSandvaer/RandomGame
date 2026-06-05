# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Paired test — visible-equipment foundation wiring (ticket 86ca56w4f, spec
## `team/uma-ux/visible-equipment-system.md §7 steps 2-5).
##
## Pins the GEN-INDEPENDENT wiring that lands before any new PixelLab art:
##   - `_resolve_attack_set` picks fist vs 1H prefix by equipped weapon class.
##   - Pre-art STUB fallback: equipping a 1H weapon with NO `_1h` art present
##     falls back to the FIST animation (nothing breaks pre-art).
##   - With `_1h` art PRESENT, the 1H swing prefix plays (proves the path is
##     wired for when art lands — synthetic SpriteFrames).
##   - The WeaponHand overlay node exists (sibling of body Sprite, z=1) and
##     shows/hides on equip/unequip.
##   - `equipped_armor_changed` fires on armor equip/unequip; the body-look
##     swap seam invalidates the hit-flash cache + replays state when a tier's
##     frames are registered (STUB: map empty → no-op for every tier).
##
## Companion to `tests/test_player_animation_wire.gd` (the M3W-2 anim contract)
## and `tests/test_item_def_weapon_class.gd` (the schema half).

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const ContentFactoryScript: Script = preload("res://tests/factories/content_factory.gd")
const ItemInstanceScript: Script = preload("res://scripts/loot/ItemInstance.gd")
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

# ---- Helpers ----------------------------------------------------------


func _make_scene_player() -> Player:
	var packed: PackedScene = load("res://scenes/player/Player.tscn")
	var p: Player = packed.instantiate() as Player
	add_child_autofree(p)
	return p


func _make_1h_weapon_instance() -> ItemInstance:
	# A ONE_HAND_MELEE weapon ItemInstance (the iron_sword shape).
	var def: ItemDef = ContentFactoryScript.make_item_def(
		{"id": &"test_1h_blade", "weapon_class": ItemDef.WeaponClass.ONE_HAND_MELEE}
	)
	return ItemInstanceScript.new(def, def.tier)


func _make_armor_instance(tier: int) -> ItemInstance:
	var def: ItemDef = ContentFactoryScript.make_item_def(
		{"id": &"test_armor", "slot": ItemDef.Slot.ARMOR, "tier": tier}
	)
	return ItemInstanceScript.new(def, def.tier)


# ---- _resolve_attack_set: class → prefix ------------------------------


func test_resolve_attack_set_unarmed_returns_fist_prefixes() -> void:
	# No weapon equipped → FIST set (existing punch animations).
	var p: Player = _make_scene_player()
	assert_eq(
		p._resolve_attack_set(Player.ATTACK_LIGHT),
		Player.ANIM_PREFIX_ATTACK_LIGHT,
		"unarmed light → attack_light (fist)"
	)
	assert_eq(
		p._resolve_attack_set(Player.ATTACK_HEAVY),
		Player.ANIM_PREFIX_ATTACK_HEAVY,
		"unarmed heavy → attack_heavy (fist)"
	)


func test_resolve_attack_set_one_hand_returns_1h_prefixes() -> void:
	# A 1H weapon equipped → the 1H swing prefixes (regardless of whether the
	# art exists yet — that's the _play_anim fallback's job, not the resolver's).
	var p: Player = _make_scene_player()
	p.equip_item(_make_1h_weapon_instance())
	assert_eq(
		p._resolve_attack_set(Player.ATTACK_LIGHT),
		Player.ANIM_PREFIX_ATTACK_LIGHT_1H,
		"1H light → attack_light_1h"
	)
	assert_eq(
		p._resolve_attack_set(Player.ATTACK_HEAVY),
		Player.ANIM_PREFIX_ATTACK_HEAVY_1H,
		"1H heavy → attack_heavy_1h"
	)


# ---- Attack-set is class-suffixed; other states are NOT --------------


func test_anim_prefix_for_state_attack_switches_on_weapon_class() -> void:
	# STATE_ATTACK routes through _resolve_attack_set; idle/walk/dodge/hit/die
	# do NOT (shared across classes, §2).
	var p: Player = _make_scene_player()
	# Unarmed.
	p._current_attack_kind = Player.ATTACK_LIGHT
	assert_eq(
		p._anim_prefix_for_state(Player.STATE_ATTACK),
		Player.ANIM_PREFIX_ATTACK_LIGHT,
		"unarmed STATE_ATTACK → attack_light"
	)
	# 1H armed.
	p.equip_item(_make_1h_weapon_instance())
	assert_eq(
		p._anim_prefix_for_state(Player.STATE_ATTACK),
		Player.ANIM_PREFIX_ATTACK_LIGHT_1H,
		"1H-armed STATE_ATTACK → attack_light_1h"
	)
	# Non-attack states are class-independent.
	assert_eq(
		p._anim_prefix_for_state(Player.STATE_WALK),
		Player.ANIM_PREFIX_IDLE_AND_WALK,
		"walk is NOT class-suffixed"
	)
	assert_eq(
		p._anim_prefix_for_state(Player.STATE_DODGE),
		Player.ANIM_PREFIX_DODGE,
		"dodge is NOT class-suffixed"
	)


# ---- Pre-art STUB fallback: 1H equipped, no _1h art → plays fist -----


func test_one_hand_attack_falls_back_to_fist_anim_when_1h_art_absent() -> void:
	# THE LOAD-BEARING STUB BEHAVIOR. The production Player.tres has NO
	# attack_light_1h_<dir> keys yet (the swing art ships in a later pilot
	# step). Equipping a 1H weapon and firing a light attack must therefore
	# PLAY the existing fist anim (attack_light_<dir>), NOT no-op the sprite.
	var p: Player = _make_scene_player()
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	# Precondition: the production frames genuinely lack the 1H keys.
	assert_false(
		asprite.sprite_frames.has_animation(StringName("attack_light_1h_e")),
		"precondition: production SpriteFrames has NO attack_light_1h_e (pre-art)"
	)
	p.equip_item(_make_1h_weapon_instance())
	p._facing = Vector2.RIGHT
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_eq(
		asprite.animation,
		StringName("attack_light_e"),
		"1H equipped + no swing art → plays fist 'attack_light_e' (stub fallback)"
	)


func test_one_hand_heavy_attack_falls_back_to_fist_heavy_when_1h_art_absent() -> void:
	var p: Player = _make_scene_player()
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	p.equip_item(_make_1h_weapon_instance())
	p._facing = Vector2.DOWN
	p.try_attack(Player.ATTACK_HEAVY, Vector2.DOWN)
	assert_eq(
		asprite.animation,
		StringName("attack_heavy_s"),
		"1H heavy + no swing art → plays fist 'attack_heavy_s' (stub fallback)"
	)


# ---- When the _1h art EXISTS, the swing plays (forward-proofing) ------


func test_one_hand_attack_plays_1h_anim_when_swing_art_present() -> void:
	# Proves the path is wired for when art lands: inject a synthetic
	# SpriteFrames that DOES carry the 1H keys, equip 1H, fire light → the
	# attack_light_1h_<dir> anim plays (no fallback). Catches a regression where
	# the resolver/fallback silently always collapses to fist.
	var p: Player = _make_scene_player()
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	var frames: SpriteFrames = asprite.sprite_frames.duplicate(true) as SpriteFrames
	for dir_suffix in ANIM_DIRS:
		var key: StringName = StringName("attack_light_1h_%s" % dir_suffix)
		frames.add_animation(key)
		frames.add_frame(key, _one_px_texture())
	asprite.sprite_frames = frames
	p.equip_item(_make_1h_weapon_instance())
	p._facing = Vector2.RIGHT
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_eq(
		asprite.animation,
		StringName("attack_light_1h_e"),
		"1H equipped + swing art present → plays 'attack_light_1h_e' (no fallback)"
	)


func _one_px_texture() -> Texture2D:
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(img)


# ---- WeaponHand overlay node lifecycle + show/hide -------------------


func test_weapon_hand_overlay_exists_as_sibling_sprite2d_z1() -> void:
	var p: Player = _make_scene_player()
	var overlay: Sprite2D = p.get_weapon_hand_overlay()
	assert_not_null(overlay, "WeaponHand overlay node exists")
	assert_eq(overlay.name, StringName("WeaponHand"), "overlay node is named 'WeaponHand'")
	assert_eq(overlay.get_parent(), p, "overlay is a child of Player (NOT of the body Sprite)")
	assert_eq(overlay.z_index, 1, "overlay z_index = 1 (over body at z=0)")


func test_weapon_hand_overlay_hidden_when_unarmed() -> void:
	var p: Player = _make_scene_player()
	var overlay: Sprite2D = p.get_weapon_hand_overlay()
	assert_false(overlay.visible, "overlay hidden at boot (unarmed)")


func test_weapon_hand_overlay_shows_on_equip_hides_on_unequip() -> void:
	var p: Player = _make_scene_player()
	var overlay: Sprite2D = p.get_weapon_hand_overlay()
	p.equip_item(_make_1h_weapon_instance())
	assert_true(overlay.visible, "overlay shown after equipping a weapon")
	p.unequip_item(Player.SLOT_WEAPON)
	assert_false(overlay.visible, "overlay hidden after unequip (unarmed again)")


# ---- equipped_armor_changed signal + body-look swap seam -------------


func test_equipped_armor_changed_fires_on_armor_equip_and_unequip() -> void:
	var p: Player = _make_scene_player()
	watch_signals(p)
	p.equip_item(_make_armor_instance(ItemDef.Tier.T1))
	assert_signal_emitted(p, "equipped_armor_changed", "armor equip fires equipped_armor_changed")
	p.unequip_item(Player.SLOT_ARMOR)
	assert_signal_emit_count(
		p, "equipped_armor_changed", 2, "armor unequip fires equipped_armor_changed again"
	)


func test_armor_equip_does_not_fire_weapon_signal() -> void:
	# Armor and weapon are independent reads — equipping armor must NOT emit
	# equipped_weapon_changed (and vice versa).
	var p: Player = _make_scene_player()
	watch_signals(p)
	p.equip_item(_make_armor_instance(ItemDef.Tier.T1))
	assert_signal_not_emitted(
		p, "equipped_weapon_changed", "armor equip does NOT fire equipped_weapon_changed"
	)


func test_armor_body_swap_is_noop_when_tier_frames_unregistered() -> void:
	# STUB state: no armor bodies registered, so the body SpriteFrames must NOT
	# change on armor equip (the swap map is empty). Pins that the seam is a
	# safe no-op pre-art rather than null-deref'ing the body.
	var p: Player = _make_scene_player()
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	var frames_before: SpriteFrames = asprite.sprite_frames
	p.equip_item(_make_armor_instance(ItemDef.Tier.T2))
	assert_eq(
		asprite.sprite_frames,
		frames_before,
		"body SpriteFrames unchanged on armor equip (STUB — no tier bodies yet)"
	)


# ---- hit-flash cache invalidation on a registered SpriteFrames swap --


func test_armor_body_swap_invalidates_hit_flash_cache_and_replays_state() -> void:
	# Drew-flagged edge (§5 #5): when a tier body IS registered and the swap
	# runs, the cached _hit_flash_target must be invalidated so the next hit
	# re-resolves the rest-color snapshot against the swapped frames. Register a
	# synthetic tier body, prime the hit-flash cache, swap, assert invalidated.
	var p: Player = _make_scene_player()
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	# Prime the hit-flash cache via a non-fatal hit (resolves _hit_flash_target).
	p.take_damage(5, Vector2.ZERO, null)
	assert_not_null(p._hit_flash_target, "precondition: hit-flash target cached after first hit")
	# Register a synthetic body for T1 and drive the swap path directly.
	var tier_frames: SpriteFrames = asprite.sprite_frames.duplicate(true) as SpriteFrames
	p._armor_body_frames_by_tier[int(ItemDef.Tier.T1)] = tier_frames
	p._apply_armor_body_look(int(ItemDef.Tier.T1))
	assert_eq(asprite.sprite_frames, tier_frames, "body SpriteFrames swapped to the tier body")
	assert_null(
		p._hit_flash_target, "hit-flash target cache invalidated after the body SpriteFrames swap"
	)
	# Next flash must re-resolve cleanly (no crash, target re-populated). Call
	# `_play_hit_flash` directly — the first `take_damage` granted HIT_IFRAMES,
	# so a second `take_damage` would be blocked and never reach the flash (same
	# direct-call pattern as test_player_animation_wire's reference-flip test).
	p._play_hit_flash()
	assert_not_null(p._hit_flash_target, "hit-flash target re-resolves after the swap")

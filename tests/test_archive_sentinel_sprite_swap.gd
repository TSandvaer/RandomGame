extends GutTest
## Paired test — ArchiveSentinel v3 sprite-swap (devon/archive-sentinel-v3-spriteswap).
##
## Pins the sprite-swap contract introduced when the Stage-5 placeholder
## ColorRect was replaced with the Sponsor-approved PixelLab v3 static art:
##
##   1. The production .tscn boots cleanly (no parse / instantiate failure).
##   2. The "Sprite" child is a Sprite2D (NOT the old ColorRect) with a
##      non-null Texture2D — proves the south.png texture resolves through
##      the import pipeline. This is the regression guard: if the .import is
##      dropped or the texture path drifts, `texture == null` and this fails.
##   3. The texture path resolves (ResourceLoader.exists) — drift detector
##      for the south.png asset path.
##   4. The Sprite child is NOT a ColorRect and NOT an AnimatedSprite2D —
##      static-suffices determination is pinned (a future accidental revert
##      to ColorRect, or a half-done AnimatedSprite2D swap without frames,
##      fails here).
##   5. `_play_anim` no-ops harmlessly on the static Sprite2D — no broken
##      anim references, no USER WARNING / USER ERROR (NoWarningGuard).
##   6. Hit-flash still produces a visible delta via the self.modulate
##      fallback branch (branch 3) — the Sprite2D child has no `color`
##      property so the resolver must route through self.modulate. Tier 1
##      color-delta invariant per `.claude/docs/test-conventions.md`.
##   7. take_damage → _die path completes without warnings on the swapped
##      scene (death tween + safety-net unaffected by the node-type change).
##
## Companion to `tests/test_archive_sentinel.gd` (HP / phase / layers /
## knockback-reject invariants on bare-instanced sentinels). This file is the
## SCENE-loaded swap contract — bare instances have no Sprite child.

const SENTINEL_SCENE: PackedScene = preload("res://scenes/mobs/ArchiveSentinel.tscn")
const SOUTH_TEX_PATH: String = "res://assets/sprites/ArchiveSentinel/south.png"

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0


# ---- Helpers ----------------------------------------------------------


class FakePlayer:
	extends Node2D
	# Dummy player target. The boss only reads global_position.


func _make_scene_sentinel() -> ArchiveSentinel:
	var s: ArchiveSentinel = SENTINEL_SCENE.instantiate() as ArchiveSentinel
	s.skip_intro_for_tests = true  # start in IDLE_ACTIVE, not DORMANT
	add_child_autofree(s)
	return s


func _make_scene_sentinel_in_room() -> Array:
	# Parented sentinel + room — the _die path needs a parent for the
	# room-parented CPUParticles2D deferred add.
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var s: ArchiveSentinel = SENTINEL_SCENE.instantiate() as ArchiveSentinel
	s.skip_intro_for_tests = true
	room.add_child(s)
	return [s, room]


# ---- 1. Scene boots ---------------------------------------------------


func test_scene_instantiates_cleanly() -> void:
	var s: ArchiveSentinel = _make_scene_sentinel()
	assert_not_null(s, "ArchiveSentinel.tscn must instantiate as an ArchiveSentinel")
	assert_true(s is CharacterBody2D, "root node is a CharacterBody2D")


# ---- 2/4. Sprite child is Sprite2D with a non-null texture -------------


func test_sprite_child_is_sprite2d_with_texture() -> void:
	var s: ArchiveSentinel = _make_scene_sentinel()
	var sprite: Node = s.get_node_or_null("Sprite")
	assert_not_null(sprite, "scene must have a 'Sprite' child node")
	assert_true(sprite is Sprite2D, "Sprite child is a Sprite2D after the v3 swap")
	assert_false(sprite is ColorRect, "Sprite child is NOT the old ColorRect placeholder")
	assert_false(
		sprite is AnimatedSprite2D,
		"static suffices — Sprite is a plain Sprite2D, not a half-wired AnimatedSprite2D"
	)
	var s2d: Sprite2D = sprite as Sprite2D
	assert_not_null(s2d.texture, "Sprite2D.texture must resolve (regression guard for the import)")


# ---- 3. Texture path resolves -----------------------------------------


func test_south_texture_path_resolves() -> void:
	assert_true(
		ResourceLoader.exists(SOUTH_TEX_PATH),
		"%s must exist — drift detector for the v3 south asset" % SOUTH_TEX_PATH
	)


# ---- 5. _play_anim no-ops harmlessly on the static sprite -------------


func test_state_transitions_emit_no_warnings_on_static_sprite() -> void:
	# Drive a few state transitions (each calls _play_anim). On a static
	# Sprite2D, _play_anim must early-return — no broken anim refs, no warning.
	var s: ArchiveSentinel = _make_scene_sentinel()
	var player: FakePlayer = autofree(FakePlayer.new())
	player.global_position = Vector2(40, 0)
	add_child(player)
	s.set_player(player)
	# Several physics ticks to push the boss through cast telegraph/recovery.
	for _i in range(8):
		s._physics_process(0.2)
	# assert_clean in after_each() catches any USER WARNING from _play_anim.
	assert_true(true, "state transitions drove _play_anim without warnings (see assert_clean)")


# ---- 6. Hit-flash visible delta via self.modulate fallback ------------


func test_hit_flash_uses_modulate_fallback_branch() -> void:
	var s: ArchiveSentinel = _make_scene_sentinel()
	s.take_damage(10, Vector2.ZERO, null)
	# First hit resolves the 3-branch resolver. A Sprite2D child is neither
	# AnimatedSprite2D nor ColorRect → branch 3 (self.modulate fallback).
	assert_false(
		s._hit_flash_uses_sprite,
		"Sprite2D child routes hit-flash through the self.modulate fallback branch (not a Sprite branch)"
	)
	assert_false(
		s._hit_flash_uses_animated_sprite,
		"Sprite2D is not an AnimatedSprite2D — animated branch off"
	)
	assert_eq(
		s._hit_flash_target, s, "fallback target is the CharacterBody2D itself (self.modulate)"
	)
	assert_true(
		s._hit_flash_tween != null and s._hit_flash_tween.is_valid(),
		"a hit-flash tween was created on the swapped scene"
	)


func test_hit_flash_tint_is_visible_delta_and_html5_safe() -> void:
	# Tier 1 invariant per `.claude/docs/test-conventions.md`: assert the
	# CONSTANTS differ (live mid-tween modulate is unreliable in headless).
	# If HIT_FLASH_TINT == rest white, the tween is the PR #115/#140 no-op trap.
	var rest: Color = Color(1, 1, 1, 1)
	var tint: Color = ArchiveSentinel.HIT_FLASH_TINT
	assert_ne(tint, rest, "HIT_FLASH_TINT differs from rest white (tween is not a no-op)")
	var delta: float = absf(tint.r - rest.r) + absf(tint.g - rest.g) + absf(tint.b - rest.b)
	assert_gte(delta, 0.20, "HIT_FLASH_TINT sum-delta >= 0.20 (visible flash, delta=%.3f)" % delta)
	# HTML5 HDR-clamp guard — every channel in [0, 1].
	assert_between(tint.r, 0.0, 1.0, "HIT_FLASH_TINT.r in [0,1] — HTML5 safe")
	assert_between(tint.g, 0.0, 1.0, "HIT_FLASH_TINT.g in [0,1] — HTML5 safe")
	assert_between(tint.b, 0.0, 1.0, "HIT_FLASH_TINT.b in [0,1] — HTML5 safe")
	assert_between(tint.a, 0.0, 1.0, "HIT_FLASH_TINT.a in [0,1] — HTML5 safe")


# ---- 7. take_damage → _die completes without warnings -----------------


func test_death_path_clean_on_swapped_scene() -> void:
	var pair: Array = _make_scene_sentinel_in_room()
	var s: ArchiveSentinel = pair[0]
	# One lethal blow.
	s.take_damage(s.get_max_hp(), Vector2.ZERO, null)
	assert_true(s.is_dead(), "lethal damage kills the sentinel")
	await get_tree().process_frame  # let the deferred particle add drain
	# assert_clean in after_each() catches death-path warnings.
	assert_true(true, "death path ran without warnings (see assert_clean)")

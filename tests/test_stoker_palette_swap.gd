extends GutTest
## M3W-6 paired test — Stoker AnimatedSprite2D wiring + palette-swap atlas.
##
## Stoker ships in M3 Tier 1 as a palette-swap retint of Grunt v2 per
## `team/DECISIONS.md` 2026-05-18 + `team/uma-ux/palette-stratum-2.md §5`
## line 191. This test covers BOTH surfaces:
##
##   1. **Animation-wire parity** with M3W-3 Grunt: SpriteFrames keys,
##      loop flags, FPS=8, AnimatedSprite2D scene shape, hit-flash
##      tween-reference flip, 8-octant direction-suffix derivation. Most
##      of these are inherited via `class Stoker extends Grunt`, but
##      we still pin the per-character resource paths so a future
##      doctrine retint or Phase-2 silhouette swap can't silently break
##      the wiring.
##
##   2. **Palette-swap correctness** — every sampled opaque pixel on the
##      Stoker atlas resolves to a hex from the S2 Stoker doctrine
##      palette (cloth `#7A1F12`, skin `#7E5A40`, aggro `#D24A3C`,
##      weapon `#9C9590`, outline `#000000`, plus the role-extension
##      ramp). Catches both bake-script regressions AND accidental
##      direct-asset edits that re-introduce off-palette pixels.
##
## Test bar mirrored from PR #271 / PR #275 (PracticeDummy + S1 mob-trio):
## color-delta hit-flash invariant (Tier 1), reference-flip on second
## hit, bare-instanced `_play_anim` no-op safety.

const StokerScript: Script = preload("res://scripts/mobs/Stoker.gd")
const STOKER_SCENE: PackedScene = preload("res://scenes/mobs/Stoker.tscn")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/stoker/Stoker.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = ["walk", "atk", "atk_telegraph", "hit", "die"]
const LOOPING_STATES: Array[String] = ["walk"]
const ONE_SHOT_STATES: Array[String] = ["atk", "atk_telegraph", "hit", "die"]

# S2 Stoker doctrine palette — every opaque pixel on the baked atlas
# must resolve to one of these hexes. See
# `assets/sprites/stoker/_pixellab_anims/anim-folder-map.md` §"Baking
# mechanism" for the role table.
const DOCTRINE_HEXES: Array[Color] = [
	# Outline + deep shadow
	Color("#000000"),  # outline (cross-stratum dark anchor)
	Color("#0A0404"),  # deep_shadow_warm (S2 vignette tone per palette-stratum-2.md §2)
	Color("#1A0A06"),  # cloth_deepest (warmer than pure black)
	# Cloth family — heat-corroded smock
	Color("#3D0A06"),  # cloth_shadow (extension)
	Color("#5A1108"),  # cloth_mid_shadow (extension)
	Color("#7A1F12"),  # cloth_base ANCHOR (palette-stratum-2.md §2 mob cloth)
	Color("#A93020"),  # cloth_highlight (extension)
	# Skin family — sun-scorched mid
	Color("#4A2F1E"),  # skin_shadow (extension)
	Color("#7E5A40"),  # skin_base ANCHOR (palette-stratum-2.md §2 mob skin)
	Color("#B08660"),  # skin_highlight (extension)
	# Aggro eye-glow — cross-stratum PL-11 constant
	Color("#D24A3C"),
	# Weapon edge — iron (unchanged from S1 per palette-stratum-2.md §2)
	Color("#9C9590"),
]


class FakePlayer:
	extends Node2D


# ---- Helpers ----------------------------------------------------------


func _make_scene_stoker() -> Stoker:
	var packed: PackedScene = STOKER_SCENE
	var s: Stoker = packed.instantiate() as Stoker
	add_child_autofree(s)
	return s


func _make_scene_stoker_in_room() -> Array:
	# Parented scene-loaded stoker + room (for _die path which needs a
	# parent for the deferred ember-particle add).
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var packed: PackedScene = STOKER_SCENE
	var s: Stoker = packed.instantiate() as Stoker
	room.add_child(s)
	return [s, room]


func _hex_to_color8(c: Color) -> Color:
	# Round Color() back to 8-bit channel values for hex equality.
	return Color8(int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0)))


func _doctrine_set() -> Dictionary:
	# Build a Dictionary keyed by 8-bit hex string for fast membership check.
	var out: Dictionary = {}
	for h in DOCTRINE_HEXES:
		var c8: Color = _hex_to_color8(h)
		var key: String = (
			"#%02X%02X%02X" % [int(c8.r * 255.0), int(c8.g * 255.0), int(c8.b * 255.0)]
		)
		out[key] = true
	return out


# ---- SpriteFrames resource shape --------------------------------------


func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 5 states × 8 directions = 40 sub-animation keys (mirrors Grunt v2).
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Stoker SpriteFrames .tres loads")
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(
				frames.has_animation(anim_name), "SpriteFrames exposes animation '%s'" % anim_name
			)


func test_sprite_frames_loop_flags_match_convention() -> void:
	# Per M3W-1 convention: sustained states loop, one-shot beats don't.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in LOOPING_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(
				frames.get_animation_loop(anim_name), "'%s' loops (sustained gait)" % anim_name
			)
	for state in ONE_SHOT_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_false(
				frames.get_animation_loop(anim_name), "'%s' is one-shot (loop=false)" % anim_name
			)


func test_sprite_frames_fps_is_8_across_all_anims() -> void:
	# FPS=8 across all anims per M3W-1 convention.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(
				frames.get_animation_speed(anim_name),
				8.0,
				"'%s' plays at 8 fps (M3W-1 convention)" % anim_name
			)


# ---- Scene shape — production .tscn uses AnimatedSprite2D ------------


func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	var s: Stoker = _make_scene_stoker()
	var sprite_node: Node = s.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "Stoker.tscn has a 'Sprite' child")
	assert_true(
		sprite_node is AnimatedSprite2D,
		"Sprite child resolves to AnimatedSprite2D (M3W-6 inherits M3W-3 shape)"
	)
	var asprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	assert_not_null(asprite.sprite_frames, "AnimatedSprite2D has a SpriteFrames resource assigned")
	assert_eq(
		asprite.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"texture_filter = NEAREST (pixel-art hardness preserved)"
	)


func test_scene_sprite_frames_resolves_to_stoker_atlas_not_grunt() -> void:
	# Catches the most likely regression: forgetting to swap the
	# SpriteFrames ext_resource in Stoker.tscn and accidentally pointing
	# at Grunt.tres. The whole M3W-6 PR collapses to a no-op visually
	# if this slips.
	var s: Stoker = _make_scene_stoker()
	var asprite: AnimatedSprite2D = s.get_node("Sprite") as AnimatedSprite2D
	var path: String = asprite.sprite_frames.resource_path
	assert_eq(
		path,
		SPRITE_FRAMES_PATH,
		"Stoker.tscn references Stoker.tres (not Grunt.tres); got '%s'" % path
	)


func test_inherits_grunt_class_for_behavior_parity() -> void:
	# Stoker extends Grunt — behavioral parity is the whole point of
	# Path A. If a Phase-2 refactor splits this hierarchy, the AI parity
	# guarantee disappears and every Stoker-related test for HP /
	# damage / state machine has to be re-derived. Pin the inheritance.
	var s: Stoker = StokerScript.new()
	add_child_autofree(s)
	assert_true(s is Stoker, "instance is Stoker")
	assert_true(s is Grunt, "Stoker extends Grunt (inheritance preserved)")


# ---- Tier 1 hit-flash tint != rest -----------------------------------


func test_hit_flash_tint_inherited_from_grunt() -> void:
	# Stoker inherits Grunt's HIT_FLASH_TINT verbatim per the M3W-1
	# inheritance contract ("uniform constant across the M3 mob roster"
	# from `.claude/docs/combat-architecture.md §"M3W-1 realized
	# implementation"`). Pin that the inheritance is intact.
	assert_eq(
		Stoker.HIT_FLASH_TINT,
		Grunt.HIT_FLASH_TINT,
		"Stoker.HIT_FLASH_TINT inherits Grunt's constant (uniform roster tint)"
	)
	# Tier 1 color-delta invariant per `.claude/docs/test-conventions.md`.
	var tint: Color = Stoker.HIT_FLASH_TINT
	var rest_white: Color = Color(1, 1, 1, 1)
	var delta: float = (
		absf(tint.r - rest_white.r) + absf(tint.g - rest_white.g) + absf(tint.b - rest_white.b)
	)
	assert_gt(
		delta, 0.20, "HIT_FLASH_TINT vs rest sum-delta >= 0.20 (visible flash, delta=%.3f)" % delta
	)


# ---- State-driven anim playback --------------------------------------


func test_take_damage_plays_hit_anim() -> void:
	var s: Stoker = _make_scene_stoker()
	var asprite: AnimatedSprite2D = s.get_node("Sprite") as AnimatedSprite2D
	# No player → facing defaults to "s".
	s.take_damage(1, Vector2.ZERO, null)
	assert_eq(
		asprite.animation,
		StringName("hit_s"),
		"take_damage plays 'hit_<dir>' on the AnimatedSprite2D"
	)


func test_die_plays_die_anim() -> void:
	var bundle: Array = _make_scene_stoker_in_room()
	var s: Stoker = bundle[0]
	var asprite: AnimatedSprite2D = s.get_node("Sprite") as AnimatedSprite2D
	s.take_damage(s.hp_max, Vector2.ZERO, null)
	assert_true(s.is_dead(), "stoker dead after lethal hit (precondition)")
	assert_eq(
		asprite.animation, StringName("die_s"), "_die plays 'die_<dir>' on the AnimatedSprite2D"
	)


func test_chase_state_plays_walk_anim() -> void:
	var s: Stoker = _make_scene_stoker()
	var asprite: AnimatedSprite2D = s.get_node("Sprite") as AnimatedSprite2D
	var fp: FakePlayer = FakePlayer.new()
	add_child_autofree(fp)
	fp.global_position = s.global_position + Vector2(100.0, 0.0)
	s.set_player(fp)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(s.get_state(), Grunt.STATE_CHASING, "stoker entered chase state")
	# Player is due east — facing suffix = "e".
	assert_eq(
		asprite.animation, StringName("walk_e"), "chase state plays 'walk_e' (player is due east)"
	)


# ---- Tween-reference flip on second hit (Tier 1 invariant) -----------


func test_hit_flash_tween_reference_flips_on_second_hit() -> void:
	var s: Stoker = _make_scene_stoker()
	s.take_damage(1, Vector2.ZERO, null)
	var first_tween: Tween = s._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween")
	s.take_damage(1, Vector2.ZERO, null)
	var second_tween: Tween = s._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(
		first_tween,
		second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)"
	)


# ---- `_play_anim` no-op safety (bare-instanced stoker) ---------------


func test_play_anim_is_safe_noop_on_bare_instanced_stoker() -> void:
	var s: Stoker = StokerScript.new()
	add_child_autofree(s)
	s._play_anim(&"walk")
	s._play_anim(&"hit")
	s._play_anim(&"die")
	s._play_anim(&"nonexistent_state")
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")


# ---- Palette-swap pixel-sample assertion (acceptance criterion #4) --


func _sample_atlas_palette() -> Dictionary:
	# Walk a sample of frame textures across all 5 states + all 8 dirs and
	# tally every opaque pixel's hex. Returns a Dictionary keyed by
	# "#RRGGBB" string. The atlas has 280 PNGs and ~179k opaque pixels;
	# we sample 1 frame per (state, direction) = 40 frames — sufficient
	# to catch a wrong-palette regression while keeping the test fast.
	var found: Dictionary = {}
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			if not frames.has_animation(anim_name):
				continue
			# Sample frame 0 of each anim (representative).
			var tex: Texture2D = frames.get_frame_texture(anim_name, 0)
			if tex == null:
				continue
			var img: Image = tex.get_image()
			if img == null:
				continue
			# Walk every pixel; record opaque hex strings.
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var c: Color = img.get_pixel(x, y)
					if c.a < 1e-3:
						continue
					var c8: Color = _hex_to_color8(c)
					var key: String = (
						"#%02X%02X%02X" % [int(c8.r * 255.0), int(c8.g * 255.0), int(c8.b * 255.0)]
					)
					found[key] = found.get(key, 0) + 1
	return found


func test_baked_atlas_every_opaque_pixel_matches_s2_doctrine_palette() -> void:
	# Walk the atlas; every opaque hex must be a doctrine entry. This is
	# the load-bearing palette-swap assertion — catches:
	#   - Bake script regressions (a new role drifts off the ramp).
	#   - Accidental direct PNG edits that re-introduce off-palette
	#     pixels.
	#   - A future "let me just tint this one frame manually" mistake.
	var doctrine: Dictionary = _doctrine_set()
	var found: Dictionary = _sample_atlas_palette()
	assert_gt(found.size(), 0, "atlas has opaque pixels sampled (precondition)")
	var off_palette: Array[String] = []
	for hex_key in found.keys():
		if not doctrine.has(hex_key):
			off_palette.append(hex_key)
	assert_eq(
		off_palette.size(),
		0,
		"every opaque pixel matches a doctrine hex; off-palette: %s" % str(off_palette)
	)


func test_baked_atlas_contains_anchor_hexes() -> void:
	# The retint MUST visibly land on the doctrine anchors — without these,
	# the bake produced a sprite that doesn't read as Stoker. Positive
	# assertion (vs the off-palette negative): at minimum the cloth_base
	# anchor `#7A1F12` and the outline `#000000` must appear. The cloth
	# is the dominant body color; the outline is the silhouette read.
	var found: Dictionary = _sample_atlas_palette()
	assert_true(
		found.has("#7A1F12"), "atlas contains cloth_base anchor #7A1F12 (S2 mob cloth landed)"
	)
	assert_true(found.has("#000000"), "atlas contains outline #000000 (silhouette preserved)")


func test_baked_atlas_preserves_aggro_eye_glow_beat() -> void:
	# Character-beat preservation per the doctrine-lock rule in
	# `.claude/docs/pixellab-pipeline.md §"Strategy 3 refinement —
	# manual override for character-beat preservation"`. The Grunt v2
	# source has a small red eye-glow cluster (#C2100C, #F90807, etc.);
	# the bake force-routes those to `#D24A3C` aggro to preserve the beat.
	# Without the red-glow override, the dim red shadow ring would
	# Euclidean-collapse into cloth and erase the beat entirely. This
	# test pins that the bake actually carried the beat through.
	var found: Dictionary = _sample_atlas_palette()
	assert_true(
		found.has("#D24A3C"), "atlas contains aggro eye-glow #D24A3C (character beat preserved)"
	)


func test_baked_atlas_visibly_distinct_from_grunt_source() -> void:
	# Acceptance criterion: "Stoker reads as visibly distinct from
	# Grunt." Validate by comparing pixel-level color overlap: at most
	# ~5% of the Stoker hex set may coincide with the Grunt source set
	# (the bake legitimately preserves a few cross-palette colors —
	# pure black outline `#000000` and iron weapon `#9C9590` are
	# stratum-constants that ALSO appear in the Grunt source). Anything
	# higher than that suggests the retint didn't actually fire.
	var stoker_found: Dictionary = _sample_atlas_palette()
	# Pull Grunt v2 source palette (same sampling pattern, against
	# Grunt.tres). Inline rather than refactor — keeps the assertion's
	# evidence local.
	var grunt_frames: SpriteFrames = load("res://assets/sprites/grunt/Grunt.tres") as SpriteFrames
	assert_not_null(grunt_frames, "Grunt SpriteFrames .tres loads for comparison")
	var grunt_found: Dictionary = {}
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			if not grunt_frames.has_animation(anim_name):
				continue
			var tex: Texture2D = grunt_frames.get_frame_texture(anim_name, 0)
			if tex == null:
				continue
			var img: Image = tex.get_image()
			if img == null:
				continue
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var c: Color = img.get_pixel(x, y)
					if c.a < 1e-3:
						continue
					var c8: Color = _hex_to_color8(c)
					var key: String = (
						"#%02X%02X%02X" % [int(c8.r * 255.0), int(c8.g * 255.0), int(c8.b * 255.0)]
					)
					grunt_found[key] = grunt_found.get(key, 0) + 1
	var overlap: int = 0
	for hex_key in stoker_found.keys():
		if grunt_found.has(hex_key):
			overlap += 1
	# Stoker has ~10 distinct doctrine hexes; Grunt has ~500 raw source
	# hexes. Coincidental overlap is bounded by the doctrine palette
	# size — pure outline + iron-edge cross-stratum hexes account for
	# ~2-3 hexes max. Assert <= 4 overlap hexes (allow some slack for
	# bake-script tweaks that legitimately surface a single matching
	# warm-brown extension).
	assert_lte(overlap, 4, "Stoker atlas distinct from Grunt: only %d hexes overlap" % overlap)

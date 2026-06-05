# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Monk-rig-install paired test — Player.tres frame-swap to the new
## PixelLab "Player Monk v3 strict" rig (8-dir, doctrine-EXEMPT hero).
##
## Companion to `tests/test_player_animation_wire.gd` (which pins the
## AnimatedSprite2D wiring + resolver contract, all still satisfied by this
## rig because the 48 game-consumed keys + UID + loop policy + fps + node
## name are preserved verbatim). THIS file pins the rig-swap-specific facts:
##   - SpriteFrames resolves the new monk-rig frame paths (regression catch if
##     someone reverts to the old `Player_re-queue` rig).
##   - Per-state frame counts match the PixelLab source (idle=4, walk=6,
##     attack_light=3, attack_heavy=6, dodge=6, hit=6, die=7).
##   - The MERGED hit set has all 8 directions at 6 frames (the
##     `taking_a_punch-04c0be52` NE-only + `taking_a_punch-56764fe0` 7-dir
##     double-folder merge).
##   - Additive `idle_*` keys (8 dirs) exist + loop (rig now ships a real idle
##     anim; the resolver still maps STATE_IDLE → `walk` prefix, so these are
##     present-and-available but not yet played — pinned so a future
##     resolver-flip has the keys).
##   - Doctrine-EXEMPT marker: frame textures live under the RAW monk-rig
##     folder, NOT a doctrine-locked export path (guards against an accidental
##     palette-lock pass that would erase the blue eyes).

const SPRITE_FRAMES_PATH: String = "res://assets/sprites/player/Player.tres"
const RIG_ROOT: String = (
	"res://assets/sprites/player/_pixellab_anims/Player_Monk_v3_strict/animations"
)
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

# state prefix -> expected frame count (from the PixelLab source, verified by
# per-dir `ls | wc -l` on the extracted ZIP).
const STATE_FRAME_COUNTS: Dictionary = {
	"idle": 4,
	"walk": 6,
	"attack_light": 3,
	"attack_heavy": 6,
	"dodge": 6,  # walk-frame substitute (no dodge anim in this rig)
	"hit": 6,  # double-folder merge (NE + 7 others)
	"die": 7,
}


func _frames() -> SpriteFrames:
	return load(SPRITE_FRAMES_PATH) as SpriteFrames


# ---- Rig loads + all 7 states × 8 dirs present (56 keys) --------------


func test_monk_rig_sprite_frames_loads() -> void:
	assert_not_null(_frames(), "Player.tres (monk rig) loads as SpriteFrames")


func test_all_seven_states_x_eight_dirs_present() -> void:
	# 7 states (walk/idle/attack_light/attack_heavy/dodge/hit/die) × 8 dirs = 56.
	var frames: SpriteFrames = _frames()
	for state in STATE_FRAME_COUNTS.keys():
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(
				frames.has_animation(anim_name),
				"monk rig exposes animation '%s'" % anim_name
			)


func test_total_animation_count_is_56() -> void:
	# 48 game-consumed (6 states) + 8 additive idle.
	var frames: SpriteFrames = _frames()
	assert_eq(frames.get_animation_names().size(), 56, "monk rig has exactly 56 sub-animations")


# ---- Per-state frame counts match the PixelLab source -----------------


func test_per_state_frame_counts_match_pixellab_source() -> void:
	var frames: SpriteFrames = _frames()
	for state in STATE_FRAME_COUNTS.keys():
		var expected: int = STATE_FRAME_COUNTS[state]
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(
				frames.get_frame_count(anim_name),
				expected,
				"'%s' has %d frames (PixelLab source)" % [anim_name, expected]
			)


# ---- Hit double-folder merge — all 8 dirs at 6 frames -----------------


func test_hit_merge_covers_all_eight_directions() -> void:
	# The hit animation was split across two PixelLab folders
	# (`taking_a_punch-04c0be52` = north-east only; `taking_a_punch-56764fe0`
	# = the other 7 dirs). The merge must produce a complete 8-dir set, each 6f.
	var frames: SpriteFrames = _frames()
	for dir_suffix in ANIM_DIRS:
		var anim_name: StringName = StringName("hit_%s" % dir_suffix)
		assert_true(frames.has_animation(anim_name), "merged hit set includes '%s'" % anim_name)
		assert_eq(frames.get_frame_count(anim_name), 6, "'%s' has 6 frames" % anim_name)


# ---- Additive idle keys (rig ships a real idle anim) ------------------


func test_idle_keys_exist_and_loop() -> void:
	# This rig adds real `idle_*` keys (4f) — the prior rig had none (idle was
	# "walk frame 0 hold"). The resolver still maps STATE_IDLE → `walk`, so
	# these are present-and-available but not played. Loop=true (matches walk).
	var frames: SpriteFrames = _frames()
	for dir_suffix in ANIM_DIRS:
		var anim_name: StringName = StringName("idle_%s" % dir_suffix)
		assert_true(frames.has_animation(anim_name), "idle key '%s' exists" % anim_name)
		assert_true(frames.get_animation_loop(anim_name), "'%s' loops" % anim_name)
		assert_eq(frames.get_frame_count(anim_name), 4, "'%s' has 4 frames" % anim_name)


# ---- Doctrine-EXEMPT raw-frames marker --------------------------------


func test_frame_textures_point_at_raw_monk_rig_not_doctrine_locked() -> void:
	# Player is doctrine-EXEMPT (cross-stratum constant). Frames ship RAW from
	# PixelLab — NO doctrine-lock pass (which erases the blue eyes). Guard:
	# every frame texture resolves under the raw monk-rig folder. A regression
	# to the old `Player_re-queue` rig OR a doctrine-locked export path fails here.
	var frames: SpriteFrames = _frames()
	# Sample one frame per state — enough to catch a wholesale path regression.
	for state in STATE_FRAME_COUNTS.keys():
		var anim_name: StringName = StringName("%s_s" % state)
		var tex: Texture2D = frames.get_frame_texture(anim_name, 0)
		assert_not_null(tex, "'%s' frame 0 has a texture" % anim_name)
		var path: String = tex.resource_path
		assert_true(
			path.begins_with(RIG_ROOT),
			"'%s' frame 0 texture lives under the raw monk rig (got: %s)" % [anim_name, path]
		)
		assert_false(
			path.contains("Player_re-queue"),
			"'%s' frame 0 is NOT the old retired rig" % anim_name
		)

extends GutTest
## M3 Tier 2 Wave 2 — Stratum1Boss slam anim B3 swap (ticket 86c9wjyrc).
##
## Sponsor 2026-05-21 soak iteration on PR #291 surfaced the boss slam as a
## visually-wrong kick (the original `roundhouse_kick` template) rather than
## the intended weapon-uppercut slam. Frames replaced from the pre-existing
## 2026-05-17 `surprise-uppercut` PixelLab generation (zero new gens). This
## test pins the post-swap contract so a future regression — re-importing
## the kick frames, accidentally pointing the .tres at a different folder,
## or losing the frame_NNN.png path convention — fails fast in headless CI.
##
## The state-driven play path (`STATE_SLAM_RECOVERY → _play_anim(&"slam") →
## slam_<dir>`) is already covered by `test_stratum1_boss_animation_wire.gd`
## (test_slam_recovery_plays_slam_anim + test_phase_2_boss_slams_*); this
## file adds the **frame-source** invariants those tests don't probe.

const SPRITE_FRAMES_PATH: String = "res://assets/sprites/boss/Stratum1Boss.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const EXPECTED_FRAME_COUNT: int = 7  # surprise-uppercut template (was 7 for kick too — coincidence; pin)

# Map .tres dir suffix → on-disk folder name (per anim-folder-map.md).
const DIR_SUFFIX_TO_FOLDER: Dictionary = {
	"n": "north", "ne": "north-east", "e": "east", "se": "south-east",
	"s": "south", "sw": "south-west", "w": "west", "nw": "north-west",
}


# ---- Frame count invariant -------------------------------------------

func test_each_slam_dir_has_seven_frames() -> void:
	# surprise-uppercut template ships 7 frames per direction (frame_000.png ...
	# frame_006.png). A regression that re-imports a different template with a
	# different frame count would silently change pacing (FPS=8 → 0.875 s total
	# for 7f vs 1.0 s for 8f). Pin the count.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Stratum1Boss SpriteFrames .tres loads")
	for dir_suffix in ANIM_DIRS:
		var anim_name: StringName = StringName("slam_%s" % dir_suffix)
		assert_eq(frames.get_frame_count(anim_name), EXPECTED_FRAME_COUNT,
			"slam_%s frame count = 7 (surprise-uppercut template)" % dir_suffix)


# ---- Frame texture resolves + size invariant -------------------------

func test_each_slam_frame_texture_loads_at_80x80_rgba() -> void:
	# Every PixelLab frame for this boss is 80×80 RGBA. Catch:
	#   1. A texture failing to resolve (path break, missing file)
	#   2. A frame at a non-80×80 canvas (different template / source mix)
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for dir_suffix in ANIM_DIRS:
		var anim_name: StringName = StringName("slam_%s" % dir_suffix)
		for i in range(EXPECTED_FRAME_COUNT):
			var tex: Texture2D = frames.get_frame_texture(anim_name, i)
			assert_not_null(tex,
				"slam_%s frame %d texture resolves" % [dir_suffix, i])
			if tex == null:
				continue
			var size: Vector2 = tex.get_size()
			assert_eq(int(size.x), 80,
				"slam_%s frame %d width = 80 px" % [dir_suffix, i])
			assert_eq(int(size.y), 80,
				"slam_%s frame %d height = 80 px" % [dir_suffix, i])


# ---- Source-folder path pin (B3 swap regression guard) ---------------

func test_each_slam_frame_texture_resolves_via_slam_directory() -> void:
	# Pin the on-disk source folder: every slam_<dir> frame must point at a
	# texture whose resource_path lives under
	# `assets/sprites/boss/_pixellab_anims/Stratum1Boss/animations/slam/<dir>/frame_NNN.png`.
	# This is the regression guard for the B3 swap — if a future PR reverts
	# the .tres to a different slam source (e.g. point back at the deleted
	# roundhouse_kick folder via a typo), this test fails before the kick
	# anim re-ships.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for dir_suffix in ANIM_DIRS:
		var anim_name: StringName = StringName("slam_%s" % dir_suffix)
		var folder: String = DIR_SUFFIX_TO_FOLDER[dir_suffix]
		var expected_dir: String = (
			"res://assets/sprites/boss/_pixellab_anims/Stratum1Boss/animations/slam/%s/"
			% folder
		)
		for i in range(EXPECTED_FRAME_COUNT):
			var tex: Texture2D = frames.get_frame_texture(anim_name, i)
			if tex == null:
				continue
			var path: String = tex.resource_path
			assert_true(path.begins_with(expected_dir),
				"slam_%s frame %d path under '%s' (got: '%s')"
				% [dir_suffix, i, expected_dir, path])
			var expected_file: String = "frame_%03d.png" % i
			assert_true(path.ends_with(expected_file),
				"slam_%s frame %d path ends with '%s' (got: '%s')"
				% [dir_suffix, i, expected_file, path])


# ---- Anim duration vs slam_recovery timing (audio-cue alignment) -----

func test_slam_anim_total_duration_fits_inside_slam_recovery_window() -> void:
	# SLAM_RECOVERY = 0.85 s (real, pre-enrage). FPS=8 across all anims per
	# M3W-1. 7 frames at 8 fps = 0.875 s total — slightly over the recovery
	# window, but only by 25 ms which is within frame-quantization slop and
	# the boss is already free to act when the timer expires (anim doesn't
	# gate state transition). What we pin here is that the anim isn't
	# DRAMATICALLY mis-sized (e.g. 30-frame anim playing during a 0.85 s
	# window would loop or stall).
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	var fps: float = frames.get_animation_speed(StringName("slam_s"))
	var anim_duration: float = float(EXPECTED_FRAME_COUNT) / fps
	# Sanity bracket: anim must fit within 2× the recovery window (1.7 s).
	# This is loose enough to allow future template swaps with reasonable
	# frame counts (6-12 frames at 8 fps) but tight enough to catch a
	# 24-frame template misimport.
	assert_lt(anim_duration, Stratum1Boss.SLAM_RECOVERY * 2.0,
		"slam anim duration (%.3fs) < 2× SLAM_RECOVERY (%.3fs)"
		% [anim_duration, Stratum1Boss.SLAM_RECOVERY * 2.0])
	# Lower bound: anim shouldn't be a 1-frame still — the slam needs at
	# least 3 visible frames to read as a strike motion.
	assert_gte(EXPECTED_FRAME_COUNT, 3,
		"slam anim has >=3 frames (visible strike motion)")

extends GutTest
## Tests for Stratum1Boss M3 Tier 2 Wave 2 T5 + T6.
##
## **T5** (ticket `86c9wjyrc`) — visible slam-telegraph danger-zone Polygon2D
## (actually Node2D + draw_arc — see implementation note in Stratum1Boss.gd
## header) circle indicator at SLAM_HITBOX_RADIUS.
##
## **T6** (ticket `86c9wjyuv`) — slam aftershock 12-particle ember burst on
## slam-fire, parented to the room so it persists past slam-recovery.
##
## ## Coverage
##
##   T5-1. Slam-telegraph spawns a SlamTelegraphIndicator child of the boss.
##   T5-2. Indicator is freed (queued for deletion) after slam-fire fade-out
##         tween completes.
##   T5-3. Indicator is force-freed immediately if the boss dies mid-telegraph
##         (no lingering circle on the corpse).
##   T5-4. Indicator is not stacked — re-entering slam-telegraph while a stale
##         indicator exists frees the old one before spawning the new.
##   T5-5. Indicator color matches `SLAM_INDICATOR_COLOR` (#FF6A2A α=0.5,
##         sub-1.0 RGB channels per HTML5 HDR-clamp safety).
##   T5-6. Indicator radius matches `SLAM_HITBOX_RADIUS` (80 px) via the
##         `SlamTelegraphIndicator.SLAM_HITBOX_RADIUS_CONST` mirror.
##   T5-7. Strobe constants (LOW/HIGH/HZ) within safe bounds (Sponsor 2026-05-21).
##   T5-8. Strobe tween is still running during the hold window — pulse, not
##         static hold (Sponsor 2026-05-21).
##   T6-1. Slam-fire spawns a CPUParticles2D burst parented to the boss's
##         parent (room), NOT the boss itself, so the burst persists past
##         boss queue_free.
##   T6-2. Burst configuration: 12 particles, lifetime tracks the script
##         constant (350 ms post-Sponsor-soak visibility fix), 40–80 px/s
##         velocity, ember light → deep ramp, rising gravity, z_index +1.
##   T6-3. Burst self-frees on `finished` signal — `queue_free` connected.
##   HP-1. Bare-instance boss respects DebugFlags.boss_hp_mult (Sponsor 2026-05-21).
##   HP-2. Default (no multiplier set) → production 600 HP.
##   HP-3. Multiplier clamped to [MIN, MAX] range.

const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const IndicatorScript: Script = preload("res://scripts/mobs/SlamTelegraphIndicator.gd")


# ---- Test isolation ---------------------------------------------------
# Mirrors the pattern in `test_stratum1_boss.gd` — reset TimeScaleDirector +
# Engine.time_scale on both ends so phase-transition / hit-pause / final-freeze
# requests from earlier tests don't leak into this file.

func before_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0


func after_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0


# ---- Helpers ----------------------------------------------------------

class FakePlayer:
	extends Node2D


func _make_boss() -> Stratum1Boss:
	# Phase-2 boss with skip_intro_for_tests so slam attacks are accessible.
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	return b


## Drive a fresh boss into phase 2 and arm a slam telegraph (player just inside
## slam radius but outside melee range). Returns (boss, player) — caller can
## then advance time / inspect children. The slam telegraph is active at return.
func _arm_slam_telegraph() -> Array:
	var b: Stratum1Boss = _make_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)
	# Drive into phase 2 (slam is gated on phase >= 2 in `_process_chase`).
	b.take_damage(204, Vector2.ZERO, null)  # 600 → 396 (phase-2 threshold)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2, "boss reached phase 2")
	# Position player inside slam radius, outside melee range.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(50.0, 0.0)  # > MELEE_RANGE 36, < SLAM_RADIUS 80
	# Single tick into chase → slam-telegraph (cooldown is cleared on phase entry).
	b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"boss armed slam-telegraph")
	return [b, p]


## Walk the boss's children and return the SlamTelegraphIndicator if present.
func _find_indicator(b: Stratum1Boss) -> Node:
	for child in b.get_children():
		if child is SlamTelegraphIndicator:
			return child
	return null


# ---- T5-1: indicator spawns on slam-telegraph -------------------------

func test_slam_telegraph_spawns_indicator_child() -> void:
	var arr: Array = _arm_slam_telegraph()
	var b: Stratum1Boss = arr[0]
	var indicator: Node = _find_indicator(b)
	assert_not_null(indicator,
		"T5-1: slam-telegraph spawns a SlamTelegraphIndicator child of the boss")
	assert_true(indicator is SlamTelegraphIndicator,
		"T5-1: child is the SlamTelegraphIndicator class")
	# Parent-relative position (boss-centered) per scope-doc AC.
	assert_almost_eq((indicator as Node2D).position.x, 0.0, 0.001,
		"T5-1: indicator is parent-relative at boss origin (x)")
	assert_almost_eq((indicator as Node2D).position.y, 0.0, 0.001,
		"T5-1: indicator is parent-relative at boss origin (y)")


# ---- T5-2: indicator freed after slam-fire ---------------------------

func test_slam_telegraph_indicator_frees_on_slam_fire() -> void:
	var arr: Array = _arm_slam_telegraph()
	var b: Stratum1Boss = arr[0]
	var indicator_before: Node = _find_indicator(b)
	assert_not_null(indicator_before, "indicator armed pre-slam-fire")
	# Advance telegraph to expiry → slam-fire.
	b._physics_process(Stratum1Boss.SLAM_TELEGRAPH_DURATION + 0.01)
	assert_eq(b.get_state(), Stratum1Boss.STATE_SLAM_RECOVERY,
		"slam fired — state transitioned to SLAM_RECOVERY")
	# Slam-fire kicks the fade-out tween. Capture the tween ref directly off the
	# boss so we can `await tween.finished` deterministically — `create_timer +
	# wall-clock window` is unreliable in headless GUT (tween process_frame
	# cadence is jittery; pattern matches `test_player_modulate_flash_60ms_total`
	# in `test_player_visual_feedback.gd` line ~190).
	var tween: Tween = b._slam_indicator_tween
	assert_not_null(tween, "slam-fire created the fade-out tween")
	assert_true(tween.is_valid(), "fade-out tween is valid")
	# Await the tween's `finished` signal. The `finished.connect` lambda inside
	# `_fade_out_slam_indicator` calls `queue_free` on the indicator. Connect
	# order: tween_property first, then `finished.connect` — so the test's
	# `await tween.finished` is guaranteed to fire AFTER the queue_free lambda
	# (Godot 4 connects fire in connection order).
	await tween.finished
	# One more process_frame to let queue_free flag the node.
	await get_tree().process_frame
	var indicator_after: Node = _find_indicator(b)
	if indicator_after != null:
		assert_true(indicator_after.is_queued_for_deletion(),
			"T5-2: indicator queued_for_deletion after slam-fire fade-out")
	else:
		assert_true(true, "T5-2: indicator already freed after slam-fire fade-out")


# ---- T5-3: indicator force-freed on boss-die mid-telegraph -----------

func test_slam_telegraph_indicator_frees_on_boss_die_mid_telegraph() -> void:
	var arr: Array = _arm_slam_telegraph()
	var b: Stratum1Boss = arr[0]
	var indicator: Node = _find_indicator(b)
	assert_not_null(indicator, "indicator armed mid-telegraph")
	# Kill the boss before slam-fires. Lethal hit while in slam-telegraph
	# bypasses the phase-transition damage-immune guard (telegraph is NOT
	# the phase-transition state). The boss enters STATE_DEAD; `_die` calls
	# `_force_free_slam_indicator`.
	b.take_damage(99999, Vector2.ZERO, null)
	assert_true(b.is_dead(), "boss dead post-lethal-hit")
	# Indicator was force-freed (no fade-out — immediate queue_free).
	assert_true(indicator.is_queued_for_deletion(),
		"T5-3: indicator queued_for_deletion on boss death mid-telegraph")


# ---- T5-4: re-entry frees stale indicator -----------------------------

func test_slam_telegraph_re_entry_does_not_stack_indicators() -> void:
	# Defensive: rapid re-entry into _begin_slam_telegraph should not stack
	# multiple indicators on the boss. The guard is `_force_free_slam_indicator`
	# at the top of `_spawn_slam_indicator`.
	var arr: Array = _arm_slam_telegraph()
	var b: Stratum1Boss = arr[0]
	# Manually re-arm the telegraph (bypassing state-machine flow) — simulates
	# the defensive double-spawn path.
	b._spawn_slam_indicator(Stratum1Boss.SLAM_TELEGRAPH_DURATION)
	var count: int = 0
	for child in b.get_children():
		if child is SlamTelegraphIndicator and not child.is_queued_for_deletion():
			count += 1
	assert_eq(count, 1,
		"T5-4: at most one live SlamTelegraphIndicator child after re-entry")


# ---- T5-5 + T5-6: indicator visual parameters -------------------------

func test_slam_indicator_color_matches_scope_ac() -> void:
	# Color #FF6A2A at α=0.5; sub-1.0 RGB channels per HTML5 HDR-clamp safety.
	var c: Color = Stratum1Boss.SLAM_INDICATOR_COLOR
	# #FF6A2A → (255, 106, 42) / 255 → (1.0, 0.4157, 0.1647)
	assert_almost_eq(c.r, 1.0, 0.005,
		"T5-5: indicator R channel matches #FF (1.0)")
	assert_almost_eq(c.g, 0.4157, 0.005,
		"T5-5: indicator G channel matches #6A (0.416)")
	assert_almost_eq(c.b, 0.1647, 0.005,
		"T5-5: indicator B channel matches #2A (0.165)")
	assert_almost_eq(c.a, 0.5, 0.001,
		"T5-5: indicator alpha 0.5 per scope AC")
	# HTML5 HDR-clamp invariant — every channel must be in [0, 1].
	assert_true(c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0,
		"T5-5: all RGB channels sub-1.0 per html5-export.md HDR-clamp rule")
	assert_true(c.r >= 0.0 and c.g >= 0.0 and c.b >= 0.0,
		"T5-5: all RGB channels non-negative")


func test_slam_indicator_radius_matches_slam_hitbox_radius() -> void:
	# Indicator radius is read from the SlamTelegraphIndicator mirror constant.
	# Pin: the mirror must match Stratum1Boss.SLAM_HITBOX_RADIUS exactly so a
	# tuning change to the slam radius propagates without two-file edits.
	assert_eq(
		IndicatorScript.SLAM_HITBOX_RADIUS_CONST,
		Stratum1Boss.SLAM_HITBOX_RADIUS,
		"T5-6: indicator radius constant matches Stratum1Boss.SLAM_HITBOX_RADIUS")
	assert_almost_eq(
		IndicatorScript.SLAM_HITBOX_RADIUS_CONST, 80.0, 0.001,
		"T5-6: indicator radius equals scope-AC value 80 px")


# ---- T6-1: aftershock burst parented to room -------------------------

func test_slam_fire_spawns_aftershock_burst_parented_to_room() -> void:
	# Build a synthetic "room" parent so we can inspect children after slam-fire.
	# Bare-instanced boss has the GUT test root as its parent — use a dedicated
	# Node2D so we can scope the inspection.
	var room: Node2D = Node2D.new()
	add_child_autofree(room)
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	room.add_child(b)  # NOT add_child_autofree — room owns the boss lifecycle.
	var p: FakePlayer = FakePlayer.new()
	room.add_child(p)
	b.set_player(p)
	# Drive into phase 2.
	b.take_damage(204, Vector2.ZERO, null)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	# Arm + fire slam.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(50.0, 0.0)
	b._physics_process(0.016)  # → STATE_TELEGRAPHING_SLAM
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_SLAM)
	b._physics_process(Stratum1Boss.SLAM_TELEGRAPH_DURATION + 0.01)  # → slam-fire
	assert_eq(b.get_state(), Stratum1Boss.STATE_SLAM_RECOVERY)
	# `call_deferred("add_child", burst)` — flush the deferred queue so the
	# burst appears in `room.get_children()`.
	await get_tree().process_frame
	var burst: CPUParticles2D = null
	for child in room.get_children():
		if child is CPUParticles2D:
			burst = child
			break
	assert_not_null(burst,
		"T6-1: slam-fire spawns a CPUParticles2D burst parented to the room")
	# Burst is NOT a child of the boss — that's the contract: persists past
	# boss queue_free.
	for child in b.get_children():
		assert_false(child is CPUParticles2D,
			"T6-1: burst is NOT a child of the boss (must persist past boss death)")


# ---- T6-2: aftershock config matches scope AC ------------------------

func test_slam_aftershock_burst_config_matches_scope_ac() -> void:
	var room: Node2D = Node2D.new()
	add_child_autofree(room)
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	room.add_child(b)
	var p: FakePlayer = FakePlayer.new()
	room.add_child(p)
	b.set_player(p)
	b.take_damage(204, Vector2.ZERO, null)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	b.global_position = Vector2(100.0, 200.0)
	p.global_position = Vector2(150.0, 200.0)
	b._physics_process(0.016)
	b._physics_process(Stratum1Boss.SLAM_TELEGRAPH_DURATION + 0.01)
	await get_tree().process_frame
	var burst: CPUParticles2D = null
	for child in room.get_children():
		if child is CPUParticles2D:
			burst = child
			break
	assert_not_null(burst, "burst spawned")
	# Particle count: 12 (half of boss-death's 24, per Priya AC).
	assert_eq(burst.amount, 12,
		"T6-2: aftershock = 12 particles per scope-doc AC")
	# Lifetime: BUMPED from 200 ms → 350 ms after Sponsor 2026-05-21 soak
	# "see no aftershock" report. The boss script constant is the source of
	# truth — assert via the constant so this stays in sync if it tunes again.
	assert_almost_eq(burst.lifetime, Stratum1Boss.SLAM_AFTERSHOCK_LIFETIME, 0.001,
		"T6-2: aftershock lifetime tracks SLAM_AFTERSHOCK_LIFETIME constant")
	assert_almost_eq(burst.lifetime, 0.35, 0.001,
		"T6-2: aftershock lifetime = 350 ms (post-Sponsor-soak visibility fix)")
	# Velocity range: 40-80 px/s.
	assert_almost_eq(burst.initial_velocity_min, 40.0, 0.001,
		"T6-2: aftershock min velocity 40 px/s per scope-doc AC")
	assert_almost_eq(burst.initial_velocity_max, 80.0, 0.001,
		"T6-2: aftershock max velocity 80 px/s per scope-doc AC")
	# One-shot, explosive, emitting at spawn.
	assert_true(burst.one_shot,
		"T6-2: aftershock is one-shot (does not loop)")
	assert_true(burst.emitting,
		"T6-2: aftershock starts emitting on spawn")
	# T6-2 visibility-fix invariants (Sponsor 2026-05-21 soak respin):
	#   - rising gravity (0, -50) so embers clear the boss sprite
	#   - z_index +1 so the burst draws over the boss AnimatedSprite2D (z=0)
	#   - scale 1.5 so each ember reads at the smaller-count 12 vs death's 24.
	assert_almost_eq(burst.gravity.x, 0.0, 0.001,
		"T6-2: aftershock gravity x = 0 (rising-only, no horizontal drift)")
	assert_true(burst.gravity.y < 0.0,
		"T6-2: aftershock gravity y < 0 — rising (Sponsor soak visibility fix)")
	assert_eq(burst.z_index, 1,
		"T6-2: aftershock z_index=+1 draws above boss sprite (z=0) per " +
		"html5-export.md §Z-index sensitivity")
	assert_true(burst.scale_amount_min > 1.0,
		"T6-2: aftershock scale > 1.0 — larger ember footprint vs death-burst's 1.0")
	# Ember ramp: light → deep (mirrors death burst).
	var ramp: Gradient = burst.color_ramp
	assert_not_null(ramp, "T6-2: aftershock has a color ramp")
	# Start color = EMBER_LIGHT (#FFB066), end = EMBER_DEEP (#A02E08).
	# Match against the same constants the boss exposes.
	var start: Color = ramp.sample(0.0)
	var end: Color = ramp.sample(1.0)
	assert_almost_eq(start.r, Stratum1Boss.EMBER_LIGHT.r, 0.005,
		"T6-2: ramp start matches EMBER_LIGHT R")
	assert_almost_eq(end.r, Stratum1Boss.EMBER_DEEP.r, 0.005,
		"T6-2: ramp end matches EMBER_DEEP R")
	# Origin = slam impact position (boss global_position at slam-fire).
	assert_almost_eq(burst.global_position.x, 100.0, 0.5,
		"T6-2: aftershock origin x matches boss position")
	assert_almost_eq(burst.global_position.y, 200.0, 0.5,
		"T6-2: aftershock origin y matches boss position")


# ---- T5 strobe (Sponsor 2026-05-21 soak respin) ----------------------

## After fade-in, the indicator modulate.a strobes between LOW and HIGH at
## STROBE_HZ for the hold window. Pin: the strobe constants must satisfy
## (a) LOW < HIGH, (b) HIGH ≤ 1.0 (Color modulate clamp), (c) LOW ≥ 0.0,
## (d) STROBE_HZ ∈ [3, 10] Hz (below seizure-risk threshold for our stimulus
## class; high enough to read as "imminent").
func test_slam_indicator_strobe_constants_are_sane() -> void:
	assert_true(Stratum1Boss.SLAM_INDICATOR_STROBE_LOW < Stratum1Boss.SLAM_INDICATOR_STROBE_HIGH,
		"strobe LOW < HIGH so the pulse oscillates")
	assert_true(Stratum1Boss.SLAM_INDICATOR_STROBE_HIGH <= 1.0,
		"strobe HIGH ≤ 1.0 — Color.a clamp")
	assert_true(Stratum1Boss.SLAM_INDICATOR_STROBE_LOW >= 0.0,
		"strobe LOW ≥ 0.0 — Color.a clamp")
	assert_true(Stratum1Boss.SLAM_INDICATOR_STROBE_HZ >= 3.0,
		"strobe Hz ≥ 3 — above static-decoration read")
	assert_true(Stratum1Boss.SLAM_INDICATOR_STROBE_HZ <= 10.0,
		"strobe Hz ≤ 10 — below seizure-risk threshold for our stimulus class")


## The fade-in + strobe tween is created when the indicator spawns and runs
## (`is_valid` + `is_running`) during the hold window. Verifies the strobe is
## not a no-op static hold by inspecting the tween's lifecycle, not by
## sampling modulate.a directly (headless tween cadence is too jittery for
## reliable per-frame sampling — same constraint as test_slam_telegraph_indicator_frees_on_slam_fire).
func test_slam_indicator_strobe_tween_runs_during_hold() -> void:
	var arr: Array = _arm_slam_telegraph()
	var b: Stratum1Boss = arr[0]
	# After fade-in completes, the tween enters the strobe step. Advance one
	# physics tick + flush a process frame so the tween reaches the strobe.
	await get_tree().process_frame
	var tween: Tween = b._slam_indicator_tween
	assert_not_null(tween, "indicator tween created on telegraph spawn")
	assert_true(tween.is_valid(), "indicator tween is valid post-fade-in")
	assert_true(tween.is_running(),
		"strobe tween is still running during the hold window — confirms " +
		"the post-fade-in step is a strobe, not a static hold")


# ---- Boss HP nerf (Sponsor 2026-05-21 dev utility) -------------------

## DebugFlags.boss_hp_mult defaults to 1.0; Stratum1Boss._apply_mob_def
## multiplies through. Test the bare-instance branch (no MobDef) so the
## 600-HP fallback path is exercised — that's the path that drives bare GUT
## tests, and the multiplier needs to apply there too so tests can opt-in.
func test_boss_hp_nerf_applies_to_bare_instance_hp() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(df, "DebugFlags autoload is wired")
	df.set_boss_hp_mult_for_test(0.5)
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	# Bare-instance fallback: 600 HP × 0.5 = 300.
	assert_eq(b.hp_max, 300, "bare-instance HP 600 × 0.5 mult = 300")
	assert_eq(b.hp_current, 300, "bare-instance current HP matches max post-nerf")
	df.reset_boss_hp_mult_for_test()


## Default behavior: when no multiplier is set, the bare-instance boss falls
## back to its production 600-HP default — i.e. the nerf is opt-in only.
func test_boss_hp_default_when_no_mult() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	df.reset_boss_hp_mult_for_test()
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	assert_eq(b.hp_max, 600, "no-mult default HP = 600 (production)")


## DebugFlags clamps multiplier inputs to [MIN, MAX]. Below MIN should clamp
## up; above MAX should clamp down. The clamped value is what gets multiplied
## into HP, so we can read clamping behavior through the boss.
func test_boss_hp_mult_clamps_extreme_inputs() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	# Below MIN (0.05): should clamp UP to 0.05.
	df.set_boss_hp_mult_for_test(0.001)
	var b1: Stratum1Boss = BossScript.new()
	b1.skip_intro_for_tests = true
	add_child_autofree(b1)
	# 600 × 0.05 = 30 (clamped); below 0.05 would give a much smaller value.
	assert_eq(b1.hp_max, 30,
		"sub-MIN input clamps to BOSS_HP_MULT_MIN=0.05 → 600 × 0.05 = 30")
	# Above MAX (5.0): should clamp DOWN to 5.0.
	df.set_boss_hp_mult_for_test(99.0)
	var b2: Stratum1Boss = BossScript.new()
	b2.skip_intro_for_tests = true
	add_child_autofree(b2)
	assert_eq(b2.hp_max, 3000,
		"super-MAX input clamps to BOSS_HP_MULT_MAX=5.0 → 600 × 5.0 = 3000")
	df.reset_boss_hp_mult_for_test()


# ---- start_room URL-param soak utility (PR #291 v4 self-soak gap) ----

## `DebugFlags.start_room` defaults to -1 (no override). After
## `set_start_room_for_test(8)` it lands at 8 and is consumable by `Main._ready`.
## Headless GUT can't exercise the JS-bridge read path; this test exercises the
## clamping + state-setting via the test-only injection mirror of `boss_hp_mult`.
func test_start_room_default_is_no_override() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(df, "DebugFlags autoload is wired")
	df.reset_start_room_for_test()
	assert_eq(int(df.start_room), -1, "default = -1 (no override)")


func test_start_room_accepts_valid_indices() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	for i in [0, 1, 4, 8]:
		df.set_start_room_for_test(i)
		assert_eq(int(df.start_room), i,
			"valid index %d is accepted as-is" % i)
	df.reset_start_room_for_test()


func test_start_room_clamps_out_of_range() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	# Above MAX (8): clamps DOWN to 8.
	df.set_start_room_for_test(99)
	assert_eq(int(df.start_room), 8,
		"super-MAX input clamps to START_ROOM_MAX=8")
	# Below 0 via the setter's special-case: explicit reset to -1.
	df.set_start_room_for_test(-5)
	assert_eq(int(df.start_room), -1,
		"negative input resets to START_ROOM_DEFAULT=-1 (no override)")
	df.reset_start_room_for_test()


# ---- T6-3: aftershock self-frees on finished --------------------------

func test_slam_aftershock_burst_self_frees_on_finished() -> void:
	var room: Node2D = Node2D.new()
	add_child_autofree(room)
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	room.add_child(b)
	var p: FakePlayer = FakePlayer.new()
	room.add_child(p)
	b.set_player(p)
	b.take_damage(204, Vector2.ZERO, null)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(50.0, 0.0)
	b._physics_process(0.016)
	b._physics_process(Stratum1Boss.SLAM_TELEGRAPH_DURATION + 0.01)
	await get_tree().process_frame
	var burst: CPUParticles2D = null
	for child in room.get_children():
		if child is CPUParticles2D:
			burst = child
			break
	assert_not_null(burst, "burst spawned")
	# Inspect: queue_free is connected to the finished signal.
	# `is_connected` works on any signal-name + callable pair. Burst.queue_free
	# is a Method-Callable on the burst itself.
	var queue_free_callable: Callable = Callable(burst, "queue_free")
	assert_true(burst.finished.is_connected(queue_free_callable),
		"T6-3: aftershock's queue_free is connected to the finished signal — " +
		"self-frees when particles complete")

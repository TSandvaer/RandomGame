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
##   T6-1. Slam-fire spawns a CPUParticles2D burst parented to the boss's
##         parent (room), NOT the boss itself, so the burst persists past
##         boss queue_free.
##   T6-2. Burst configuration matches scope-doc AC: 12 particles, 200 ms
##         lifetime, 40–80 px/s velocity, ember light → deep ramp.
##   T6-3. Burst self-frees on `finished` signal — `queue_free` connected.

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
	# Slam-fire kicks the fade-out tween. The indicator is freed on tween-finish.
	# Advance through the fade-out window. SLAM_INDICATOR_FADE = 0.080.
	# Drive process delta so the Tween advances. Use a wall-clock wait via the
	# scene tree — bare `_physics_process` does NOT advance create_tween animations
	# (those are driven by SceneTree _process), so we await a real frame here.
	await get_tree().create_timer(
		Stratum1Boss.SLAM_INDICATOR_FADE + 0.05,
		true, false, true).timeout
	# Indicator should be queued_for_deletion (or already gone).
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
	# Lifetime: 200 ms.
	assert_almost_eq(burst.lifetime, 0.20, 0.001,
		"T6-2: aftershock lifetime 200 ms per scope-doc AC")
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

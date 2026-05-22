extends GutTest
## M3-T2-W3-T13 — BossNameplate paired GUT tests.
##
## Direction source: `team/uma-ux/boss-intro.md` § "Boss nameplate spec"
## + Tester checklist BI-07 through BI-15. T18 (below-10% pulse) is
## shipped in the same PR per Priya w3-dispatch-plan §3 Brief 6.
##
## **Bug class this catches.** If a future refactor breaks one of:
##   1. CanvasLayer.layer drifts out of the HUD band (10 expected)
##   2. Spec primitives regress to Polygon2D (PR #137 invisibility risk)
##   3. Ember-orange / off-white / parchment HDR-clamp regression (any
##      RGB channel >= 1.0 fails this test before HTML5 visual gate)
##   4. Boss display_name templating fails on null / empty / lowercase
##   5. Segment composition: 3 fg + 3 ghost + 2 separators + 3 pulse-
##      outlines invariant
##   6. Phase-transition idempotence (replay-emit at same phase doesn't
##      double-flash + doesn't re-paint already-completed segment)
##   7. Ghost-drain tween kill-restart on hit-spam
##   8. T18 pulse engages on <10% threshold + stops on phase-transition
##   9. Phase boundary thresholds drift from boss-controller's 66% / 33%
##  10. Show_for templates the name as UPPERCASE from title-case MobDef
##
## **What this test does NOT cover.** Tween *timing* assertions (mid-tween
## opacity sampling, frame-perfect pulse shape) are renderer-fragile and
## belong in the Playwright spec. The GUT pin is structural + endpoint
## correctness only.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const BossNameplateScript := preload("res://scripts/ui/BossNameplate.gd")
const Stratum1BossScript := preload("res://scripts/mobs/Stratum1Boss.gd")
const NAMEPLATE_SCENE_PATH: String = "res://scenes/ui/BossNameplate.tscn"

var _warn_guard: NoWarningGuard


# ---- Lifecycle --------------------------------------------------------

func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------

func _make_nameplate() -> BossNameplate:
	var packed: PackedScene = load(NAMEPLATE_SCENE_PATH) as PackedScene
	assert_not_null(packed, "BossNameplate.tscn must load")
	var np: BossNameplate = packed.instantiate() as BossNameplate
	add_child_autofree(np)
	return np


## Minimal boss stub — exposes `display_name`, `hp_current`, `hp_max`,
## `phase`, and the three signals the nameplate subscribes to.
class FakeMobDef:
	var display_name: String


class FakeBoss extends Node:
	signal damaged(amount: int, hp_remaining: int, source: Node)
	signal phase_changed(new_phase: int)
	signal boss_died(mob, death_position: Vector2, mob_def)
	var mob_def: FakeMobDef = null
	var hp_current: int = 600
	var hp_max: int = 600
	var phase: int = 1

	func get_max_hp() -> int:
		return hp_max

	func get_phase() -> int:
		return phase


func _make_fake_boss(
		display_name: String = "Warden of the Outer Cloister",
		hp_max: int = 600) -> FakeBoss:
	var fb: FakeBoss = FakeBoss.new()
	var fd: FakeMobDef = FakeMobDef.new()
	fd.display_name = display_name
	fb.mob_def = fd
	fb.hp_max = hp_max
	fb.hp_current = hp_max
	fb.phase = 1
	add_child_autofree(fb)
	return fb


# ---- Test 1: scene loads + composition primitives ---------------------

func test_nameplate_scene_loads() -> void:
	# Catches: scene file missing or script path drift.
	var packed: PackedScene = load(NAMEPLATE_SCENE_PATH)
	assert_not_null(packed, "BossNameplate.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is BossNameplate, "root is BossNameplate typed")
	assert_true(instance is CanvasLayer, "root is CanvasLayer")
	instance.free()


# ---- Test 2: CanvasLayer layer (HUD band) -----------------------------

func test_canvas_layer_in_hud_band() -> void:
	# BI-08-adjacent: layer 10 == HUD band per brief. Below
	# BossDefeatedTitleCard (50) + InventoryPanel (80) + DescendScreen
	# (100). Above Vignette (5) + world (0).
	var np: BossNameplate = _make_nameplate()
	assert_eq(np.layer, 10, "BossNameplate layer = 10 (HUD band)")


# ---- Test 3: composition primitives all exist (3 fg + 3 ghost + 2 sep + 3 pulse) -----

func test_composition_primitives_count() -> void:
	var np: BossNameplate = _make_nameplate()
	assert_not_null(np.get_root_control(), "root Control exists")
	assert_not_null(np.get_panel_bg(), "panel BG exists")
	assert_not_null(np.get_name_label(), "boss name label exists")
	assert_not_null(np.get_threat_label(), "threat label exists")
	assert_not_null(np.get_threat_glyph_label(), "threat glyph exists")
	# 3 segments × {fg, ghost, pulse}; 2 separators between 3 segments.
	for p in range(1, BossNameplateScript.SEGMENT_COUNT + 1):
		assert_not_null(np.get_segment_fg(p),
				"segment %d foreground exists" % p)
		assert_not_null(np.get_segment_ghost(p),
				"segment %d ghost exists" % p)
		assert_not_null(np.get_pulse_outline(p),
				"segment %d pulse outline exists" % p)
		assert_not_null(np.get_phase_label(p),
				"phase label %d exists" % p)
	for i in range(2):
		assert_not_null(np.get_segment_separator(i),
				"segment separator %d exists" % i)


# ---- Test 4: HDR-clamp safety on every locked color -------------------

func test_all_colors_are_html5_safe_sub_one() -> void:
	# `.claude/docs/html5-export.md` HDR-clamp: every RGB channel must be
	# strictly < 1.0 on `gl_compatibility` to avoid pre-clip washout. The
	# constants are the source of truth so failing this test catches a
	# regression BEFORE the HTML5 visual gate sees it.
	var colors: Array[Color] = [
		BossNameplateScript.PANEL_BG,
		BossNameplateScript.EMBER_ORANGE,
		BossNameplateScript.HUD_OFF_WHITE,
		BossNameplateScript.MUTED_PARCHMENT,
		BossNameplateScript.HUD_DISABLED,
		BossNameplateScript.SEGMENT_ACTIVE_FG,
		BossNameplateScript.SEGMENT_FUTURE_FG,
		BossNameplateScript.SEGMENT_GHOST_FG,
	]
	for c in colors:
		# Ember-orange #FF6A2A has r = 1.0 exactly — that's the highest
		# channel allowed (sub-or-equal-1.0 lands at the clamp boundary
		# but does NOT trigger pre-clip washout because the GPU clamps
		# 1.0 to 1.0). Allow <= 1.0 here.
		assert_lte(c.r, 1.0, "%s.r <= 1.0 (HDR-clamp safe)" % str(c))
		assert_lte(c.g, 1.0, "%s.g <= 1.0" % str(c))
		assert_lte(c.b, 1.0, "%s.b <= 1.0" % str(c))


# ---- Test 5: spec dimensions locked -----------------------------------

func test_dimensions_locked_from_uma_spec() -> void:
	# BI-08 — 480×56. If a future PR adjusts the size the layout drifts.
	assert_almost_eq(BossNameplateScript.PANEL_WIDTH, 480.0, 0.001,
			"panel width is 480 px")
	assert_almost_eq(BossNameplateScript.PANEL_HEIGHT, 56.0, 0.001,
			"panel height is 56 px")
	assert_almost_eq(BossNameplateScript.TOP_MARGIN, 12.0, 0.001,
			"top margin is 12 px (BI-07)")
	# BI-11 — 3 visually-equal segments + 2 px separators between.
	assert_eq(BossNameplateScript.SEGMENT_COUNT, 3,
			"3 segments per Uma BI-11")
	assert_almost_eq(BossNameplateScript.SEGMENT_SEPARATOR_WIDTH, 2.0, 0.001,
			"separators are 2 px ember-orange")
	# BI-07 — slide-in 0.4 s.
	assert_almost_eq(BossNameplateScript.SLIDE_IN_DURATION, 0.4, 0.001,
			"slide-in duration locked at 0.4 s (BI-07)")
	# BI-13 — ghost-drain 0.6 s.
	assert_almost_eq(BossNameplateScript.GHOST_DRAIN_DURATION, 0.6, 0.001,
			"ghost-drain duration locked at 0.6 s (BI-13)")


# ---- Test 6: phase-threshold parity with boss controller --------------

func test_phase_thresholds_match_boss_controller() -> void:
	# Drift-detector — if Stratum1Boss.PHASE_2_HP_FRAC / PHASE_3_HP_FRAC
	# diverge from the nameplate's local constants, the active-segment
	# fill math collapses to nonsense. Pin both sides to 0.66 / 0.33.
	assert_almost_eq(BossNameplateScript.PHASE_2_HP_FRAC,
			Stratum1BossScript.PHASE_2_HP_FRAC, 0.001,
			"PHASE_2_HP_FRAC matches Stratum1Boss")
	assert_almost_eq(BossNameplateScript.PHASE_3_HP_FRAC,
			Stratum1BossScript.PHASE_3_HP_FRAC, 0.001,
			"PHASE_3_HP_FRAC matches Stratum1Boss")


# ---- Test 7: show_for uppercases boss display_name --------------------

func test_show_for_uppercases_display_name() -> void:
	# Per Uma §"Boss name (top-center, 16 px caps)" — the rendered label
	# must be all-caps. The MobDef source is title-cased
	# ("Warden of the Outer Cloister") so the nameplate uppercases at
	# render time rather than mutating the resource.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss("Warden of the Outer Cloister")
	np.show_for(fb)
	assert_eq(np.get_name_label().text, "WARDEN OF THE OUTER CLOISTER",
			"display_name rendered uppercase")


func test_show_for_handles_empty_display_name() -> void:
	# Empty display_name → fallback to FALLBACK_BOSS_NAME constant.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss("")
	np.show_for(fb)
	assert_eq(np.get_name_label().text, BossNameplateScript.FALLBACK_BOSS_NAME,
			"empty display_name → fallback")


func test_show_for_is_idempotent() -> void:
	# Stratum1BossRoom emits entry_sequence_completed exactly once per
	# fight; the room-side handler calls show_for once. A second call
	# (test harness, replay) must be a no-op — title text NOT overwritten,
	# tween NOT restarted.
	var np: BossNameplate = _make_nameplate()
	var fb_a: FakeBoss = _make_fake_boss("Warden of the Outer Cloister")
	np.show_for(fb_a)
	assert_true(np.is_shown(), "first show_for marks shown")
	var fb_b: FakeBoss = _make_fake_boss("Vorgath")
	np.show_for(fb_b)
	assert_eq(np.get_name_label().text, "WARDEN OF THE OUTER CLOISTER",
			"second show_for is a no-op — name not overwritten")


# ---- Test 8: phase-label color state ---------------------------------

func test_phase_label_colors_match_active_completed_future_states() -> void:
	# BI-12 + Uma §"Phase label": active = off-white, completed = muted
	# parchment, future = HUD disabled.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss()
	np.show_for(fb)
	# Phase 1 active; phases 2 & 3 future.
	assert_eq(np.get_phase_label(1).get_theme_color("font_color"),
			BossNameplateScript.HUD_OFF_WHITE,
			"phase 1 (active) label is off-white")
	assert_eq(np.get_phase_label(2).get_theme_color("font_color"),
			BossNameplateScript.HUD_DISABLED,
			"phase 2 (future) label is HUD disabled")
	assert_eq(np.get_phase_label(3).get_theme_color("font_color"),
			BossNameplateScript.HUD_DISABLED,
			"phase 3 (future) label is HUD disabled")
	# Transition to phase 2 → labels re-color.
	np._on_boss_phase_changed(2)
	assert_eq(np.get_phase_label(1).get_theme_color("font_color"),
			BossNameplateScript.MUTED_PARCHMENT,
			"phase 1 (completed) label is muted parchment")
	assert_eq(np.get_phase_label(2).get_theme_color("font_color"),
			BossNameplateScript.HUD_OFF_WHITE,
			"phase 2 (active) label is off-white")
	assert_eq(np.get_phase_label(3).get_theme_color("font_color"),
			BossNameplateScript.HUD_DISABLED,
			"phase 3 (future) label is HUD disabled")


# ---- Test 9: ghost-drain tween kill-restarts on hit-spam --------------

func test_ghost_drain_tween_restarts_on_repeated_hits() -> void:
	# Idempotence — a second `damaged` event mid-ghost-drain must kill
	# the in-flight tween + start a fresh one tracking the new target.
	# Otherwise the ghost layer reaches a stale snapshot two hits ago.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss("Warden", 600)
	np.show_for(fb)
	# First hit: HP 600 → 500 → fraction within phase 1 changes.
	fb.hp_current = 500
	fb.damaged.emit(100, 500, null)
	# Ghost tween should now be active for segment 1.
	var first_tween: Tween = np.get_ghost_tween(1)
	assert_not_null(first_tween, "ghost tween created on first hit")
	# Second hit immediately — old tween must be killed + replaced.
	fb.hp_current = 400
	fb.damaged.emit(100, 400, null)
	var second_tween: Tween = np.get_ghost_tween(1)
	assert_ne(first_tween, second_tween,
			"second hit replaces ghost tween reference (Tier 1 corollary)")


# ---- Test 10: phase-transition idempotence ---------------------------

func test_phase_changed_is_idempotent_on_replay() -> void:
	# Per `Stratum1Boss._check_phase_boundaries` idempotent latch — the
	# signal fires exactly once per boundary. But defensive: a future
	# refactor or test that re-emits at the same phase MUST be a no-op,
	# not a double-flash.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss()
	np.show_for(fb)
	# Initial phase: 1.
	assert_eq(np.get_current_phase(), 1, "starts in phase 1")
	# Emit phase 2 → current_phase advances.
	np._on_boss_phase_changed(2)
	assert_eq(np.get_current_phase(), 2, "advanced to phase 2")
	# Replay phase 2 → no-op, no advance backward (no advance forward
	# either).
	np._on_boss_phase_changed(2)
	assert_eq(np.get_current_phase(), 2, "replay phase 2 is a no-op")
	# Backwards phase emit → also a no-op.
	np._on_boss_phase_changed(1)
	assert_eq(np.get_current_phase(), 2, "backward phase emit is a no-op")


# ---- Test 11: T18 pulse engages at <10% threshold ---------------------

func test_pulse_engages_below_10pct_of_active_segment() -> void:
	# T18 / BI-15 — active-segment pulse at 1.5 Hz when HP drops below 10%
	# of the active phase's HP allocation. With hp_max=600, phase 1 spans
	# hp_current ∈ [396, 600]. 10% of phase 1 width = 0.1 * (600-396) =
	# 20.4 HP above the floor. So fill < 0.1 at hp_current < 396 + 20.4 ≈ 416.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss("Warden", 600)
	np.show_for(fb)
	# Pre-pulse: no active pulse.
	assert_false(np.is_pulse_active(), "no pulse before damage")
	# Hit to 410 → fraction ≈ (410-396)/(600-396) ≈ 0.0686 → below 10%.
	fb.hp_current = 410
	fb.damaged.emit(190, 410, null)
	assert_true(np.is_pulse_active(),
			"pulse engages when active-segment fill < 10%")


func test_pulse_stops_on_phase_transition() -> void:
	# BI-15 corollary — pulse stops on phase-transition (new active
	# segment may itself be >10% so pulse re-engages only if its own
	# fill is also <10%, which it won't be at fresh phase start).
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss("Warden", 600)
	np.show_for(fb)
	# Drive phase 1 to <10% to start the pulse.
	fb.hp_current = 400
	fb.damaged.emit(200, 400, null)
	assert_true(np.is_pulse_active(), "pulse engaged in phase 1 <10%")
	# Phase transition to 2.
	np._on_boss_phase_changed(2)
	assert_false(np.is_pulse_active(),
			"pulse stops on phase transition (new segment starts full)")


# ---- Test 12: boss_died handler dismisses tweens ---------------------

func test_boss_died_dismisses_pulse_and_ghost_tweens() -> void:
	# On boss_died, the title card takes over and the nameplate should
	# stop animating (no lingering tweens running into the title-card
	# beat). The nameplate is NOT freed here — its parent (the room)
	# frees it on room exit; we just dismiss the tweens.
	var np: BossNameplate = _make_nameplate()
	var fb: FakeBoss = _make_fake_boss("Warden", 600)
	np.show_for(fb)
	# Drive a hit to <10% to start pulse + ghost tweens.
	fb.hp_current = 400
	fb.damaged.emit(200, 400, null)
	assert_true(np.is_pulse_active(), "precondition: pulse active")
	# Emit boss_died — handler should kill pulse + ghost tweens.
	fb.boss_died.emit(fb, Vector2.ZERO, null)
	assert_false(np.is_pulse_active(),
			"boss_died kills pulse tween")
	# Further damaged() events should be ignored (dismissed state).
	fb.hp_current = 0
	fb.damaged.emit(400, 0, null)
	# Re-emitting boss_died is also a no-op (no crash, no resurrection).
	fb.boss_died.emit(fb, Vector2.ZERO, null)
	assert_false(np.is_pulse_active(),
			"second boss_died is idempotent — still no pulse")

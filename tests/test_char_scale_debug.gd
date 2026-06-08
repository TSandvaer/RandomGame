# gdlint:disable=max-public-methods
# GUT test class — one test per scenario IS the design.
extends GutTest
## Paired tests for the character-scale control — now LOCKED at the SHIPPED 0.6
## production default (ticket 86ca3rgxq; locks the soak dial from 86ca3kpzz).
##
## Sibling of the `?cam_zoom` dial (ticket 86ca3kjyg): cam_zoom dials the CAMERA
## perspective; char_scale dials how BIG the player + non-boss mobs render inside
## that perspective. The Sponsor dialed 0.6 on the Stage-1 soak; SOAK-REVISION #426
## (2026-06-08) drops it a further 20% to 0.48 (CHAR_SCALE_PRODUCTION_DEFAULT) as the
## "small player, large world" tune; this lock keeps the production default applied while
## keeping the `?char_scale` param + `[`/`]`/`\` dial fully working for re-tuning.
##
## RESOLUTION (default vs param vs explicit-disable) — pinned by tests below:
##   - param ABSENT → effective_char_scale() == CHAR_SCALE_PRODUCTION_DEFAULT (0.48;
##     shipped default; tests 1/3/8a)
##   - param/dial PRESENT → effective_char_scale() == the override (tests 2/3/8b)
##   - explicit-disable → 1.0 / `\` reset returns to full size (tests 5/8c)
##
## What these cover (the bug CLASS, not just an instance):
##   1. DebugFlags.char_scale var defaults to the no-PARAM sentinel (-1.0) on
##      desktop / headless (no JS bridge) — the param layer is unchanged; the 0.6
##      default lives in effective_char_scale().
##   2. set_char_scale_for_test clamps to [CHAR_SCALE_MIN, CHAR_SCALE_MAX].
##   3. char_scale_changed signal fires with the clamped value (Main subscribes
##      to re-apply + update the HUD readout). effective default is 0.6 (not 1.0).
##   4. The `[`/`]` step path steps from the CURRENT value + clamps at edges.
##   5. Reset path returns to 1.0× (the explicit-disable / full-size value).
##   6. NO USER WARNING across the in-range path (NoWarningGuard); the clamp-
##      warning path is exercised with an explicit expect_warning.
##   7. `_unhandled_input` char-scale keys are web-gated — inert on desktop /
##      headless GUT (soak keys must never fire outside the HTML5 artifact).
##   8. **Main apply — the integration seam.** (a) NO-param default scales the
##      PLAYER + every NON-BOSS mob's root to 0.6 (the lock); (b) a param/dial
##      override supersedes the 0.6 default; (c) explicit 1.0 disables (full size).
##   9. **Boss exclusion** — `_char_scale_is_boss` returns true for a node with a
##      `boss_died` signal (the codebase boss discriminator) and false for a
##      regular mob, so `_apply_char_scale` never touches a boss — bosses stay
##      1.0× under the 0.6 default too.
##
## Why GUT can't test the URL-param parse directly: `_resolve_char_scale` reads
## `OS.has_feature("web")` + JavaScriptBridge, both false/absent in headless GUT.
## The test-injection helpers drive the SAME clamp + emit path the URL parser +
## key handler reach, bypassing only the unreachable bridge/input surface. The
## web-gate itself is pinned structurally in test 7.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const DEBUGFLAGS_SOURCE_PATH := "res://scripts/debug/DebugFlags.gd"
const MAIN_SOURCE_PATH := "res://scenes/Main.gd"

var _warn_guard: NoWarningGuard
var _flags: Node
var _char_scale_signals: Array = []


func before_each() -> void:
	_flags = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	if _flags != null and _flags.has_method("reset_char_scale_for_test"):
		_flags.reset_char_scale_for_test()
	_char_scale_signals.clear()
	if _flags != null and _flags.has_signal("char_scale_changed"):
		_flags.char_scale_changed.connect(_on_char_scale_changed)
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	if _flags != null and _flags.has_signal("char_scale_changed"):
		if _flags.char_scale_changed.is_connected(_on_char_scale_changed):
			_flags.char_scale_changed.disconnect(_on_char_scale_changed)
	if _flags != null and _flags.has_method("reset_char_scale_for_test"):
		_flags.reset_char_scale_for_test()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


func _on_char_scale_changed(normalized: float) -> void:
	_char_scale_signals.append(normalized)


# --- 1. Default / no-override (production play untouched) --------------------


func test_char_scale_defaults_to_no_override_sentinel() -> void:
	assert_almost_eq(_flags.char_scale, _flags.CHAR_SCALE_DEFAULT, 0.0001)
	assert_lt(_flags.char_scale, _flags.CHAR_SCALE_MIN, "default sentinel is below the valid range")


func test_has_char_scale_override_false_at_default() -> void:
	assert_false(
		_flags.has_char_scale_override(), "no override active at the -1.0 default sentinel"
	)


func test_effective_char_scale_is_production_default_at_no_override() -> void:
	# THE LOCK (ticket 86ca3rgxq): with no param override, the effective scale Main
	# applies is the SHIPPED production default — NOT 1.0 ship size. This is the
	# load-bearing change; a default boot renders player + non-boss mobs at the default.
	assert_almost_eq(
		_flags.effective_char_scale(),
		_flags.CHAR_SCALE_PRODUCTION_DEFAULT,
		0.0001,
		"effective scale is the production default when no override is set"
	)
	# SOAK-REVISION #426: production default dropped 0.6→0.48 (Sponsor "player + normal
	# mobs 20% smaller", 2026-06-08; 0.6 × 0.8, stays above CHAR_SCALE_MIN 0.3).
	assert_almost_eq(
		_flags.CHAR_SCALE_PRODUCTION_DEFAULT,
		0.48,
		0.0001,
		"the production default is the soak-revised 0.48 (Sponsor's 20%-smaller tune)",
	)


func test_param_override_supersedes_production_default() -> void:
	# The dial is INTACT: a param/dial override returns the override value, NOT the
	# 0.6 default — so `?char_scale=N` still wins and the soak control keeps working.
	_flags.set_char_scale_for_test(0.9)
	assert_true(_flags.has_char_scale_override(), "override active after a param/dial value")
	assert_almost_eq(
		_flags.effective_char_scale(),
		0.9,
		0.0001,
		"override value supersedes the 0.6 production default (dial intact)",
	)


func test_explicit_one_disables_scaling_full_size() -> void:
	# Explicit-disable resolution: `?char_scale=1.0` (or the `\` reset key) returns
	# to full size. 1.0 IS the disable value — there is no separate disable flag.
	_flags.set_char_scale_for_test(_flags.CHAR_SCALE_RESET)
	assert_almost_eq(
		_flags.effective_char_scale(),
		1.0,
		0.0001,
		"explicit 1.0 disables scaling — characters render full size",
	)


# --- 2. Clamp -----------------------------------------------------------------


func test_set_char_scale_in_range_applies_exactly() -> void:
	_flags.set_char_scale_for_test(0.8)
	assert_almost_eq(_flags.char_scale, 0.8, 0.0001, "in-range value stored exactly")
	assert_true(_flags.has_char_scale_override(), "override now active")


func test_set_char_scale_clamps_below_min() -> void:
	_flags.set_char_scale_for_test(0.05)  # below CHAR_SCALE_MIN (0.3)
	assert_almost_eq(
		_flags.char_scale, _flags.CHAR_SCALE_MIN, 0.0001, "below-min input clamps to MIN"
	)


func test_set_char_scale_clamps_above_max_value() -> void:
	_flags.set_char_scale_for_test(9.0)  # above CHAR_SCALE_MAX (2.0)
	assert_almost_eq(
		_flags.char_scale, _flags.CHAR_SCALE_MAX, 0.0001, "above-max input clamps to MAX"
	)


# --- 3. Signal emission -------------------------------------------------------


func test_char_scale_changed_emits_clamped_value() -> void:
	_flags.set_char_scale_for_test(0.7)
	assert_eq(_char_scale_signals.size(), 1, "exactly one char_scale_changed emission")
	assert_almost_eq(
		_char_scale_signals[0], 0.7, 0.0001, "payload carries the clamped value Main reads"
	)


# --- 4. Step path -------------------------------------------------------------


func test_step_char_scale_walks_from_production_default_on_first_step() -> void:
	# Post-lock (ticket 86ca3rgxq): the first step with no prior override walks from
	# the effective baseline, which is now the 0.6 production default — NOT the -1.0
	# sentinel and NOT 1.0 ship size. So pressing `]` once goes 0.6 → 0.65. The dial
	# now starts where production renders, which is the intended re-tune ergonomics.
	_flags.step_char_scale_for_test(_flags.CHAR_SCALE_STEP)
	assert_almost_eq(
		_flags.char_scale,
		_flags.CHAR_SCALE_PRODUCTION_DEFAULT + _flags.CHAR_SCALE_STEP,
		0.0001,
		"first up-step walks from the 0.6 production default (0.6 → 0.65)",
	)


func test_step_char_scale_down_from_current() -> void:
	_flags.set_char_scale_for_test(1.0)
	_char_scale_signals.clear()
	_flags.step_char_scale_for_test(-_flags.CHAR_SCALE_STEP)
	assert_almost_eq(
		_flags.char_scale, 1.0 - _flags.CHAR_SCALE_STEP, 0.0001, "down-step from current value"
	)


func test_step_char_scale_clamps_at_min_edge() -> void:
	_flags.set_char_scale_for_test(_flags.CHAR_SCALE_MIN)
	_flags.step_char_scale_for_test(-_flags.CHAR_SCALE_STEP)
	assert_almost_eq(
		_flags.char_scale, _flags.CHAR_SCALE_MIN, 0.0001, "down-step at MIN edge stays clamped"
	)


# --- 5. Reset -----------------------------------------------------------------


func test_reset_returns_to_ship_size() -> void:
	_flags.set_char_scale_for_test(0.5)
	_flags.set_char_scale_for_test(_flags.CHAR_SCALE_RESET)
	assert_almost_eq(_flags.char_scale, 1.0, 0.0001, "reset path returns to 1.0× ship size")


# --- 6. Clamp warning is the ONLY warning path ------------------------------


func test_no_warning_on_in_range_path() -> void:
	# In-range apply must be silent — the AC "no USER WARNING" gate. after_each's
	# assert_clean enforces zero captured warnings; we also assert in-body so GUT
	# doesn't flag the test as risky/no-assert.
	_flags.set_char_scale_for_test(0.8)
	_flags.step_char_scale_for_test(_flags.CHAR_SCALE_STEP)
	_flags.set_char_scale_for_test(_flags.CHAR_SCALE_RESET)
	assert_eq(
		_warn_guard.get_captured_texts().size(),
		0,
		"no USER WARNING captured across the in-range char-scale path"
	)


# --- 7. Web-gate: the `[`/`]`/`\` keys are inert on desktop/headless ----------


func test_char_scale_keys_gated_on_web_feature() -> void:
	# The soak keys must NEVER fire outside the HTML5 release artifact. The
	# handler early-returns on `not OS.has_feature("web")`. Structural pin: the
	# `_unhandled_input` body references the web gate and the three char-scale
	# keycodes, so the gate can't be dropped without this failing.
	var source: String = FileAccess.get_file_as_string(DEBUGFLAGS_SOURCE_PATH)
	var fn_start: int = source.find("func _unhandled_input(")
	assert_gt(fn_start, -1, "DebugFlags defines _unhandled_input")
	var body_start: int = source.find("\n", fn_start)
	var next_fn: int = source.find("\nfunc ", body_start)
	var fn_body: String = source.substr(body_start, next_fn - body_start)
	assert_true(
		fn_body.find('OS.has_feature("web")') > -1,
		"_unhandled_input is web-feature-gated (soak keys inert off-web)"
	)
	assert_true(fn_body.find("KEY_BRACKETLEFT") > -1, "`[` key wired for char-scale down")
	assert_true(fn_body.find("KEY_BRACKETRIGHT") > -1, "`]` key wired for char-scale up")
	assert_true(fn_body.find("KEY_BACKSLASH") > -1, "`\\` key wired for char-scale reset")


# --- 8. Main apply — player + non-boss mobs scaled together (integration) ----


func test_main_apply_char_scale_scales_player_and_nonboss_mobs() -> void:
	# Boot Main, load the widened Room02 (4 grunts), apply a 0.6 char-scale, and
	# assert the PLAYER root scale == 0.6 while every spawned (non-boss) mob's ROOT
	# scale == 0.6 × MOB_SCALE_FACTOR (the soak-rev #426 mobs-bigger tune). Scaling
	# the root scales sprite + CollisionShape2D together — the no-big-hitbox-on-
	# small-sprite contract. `pickup_count > 0`-style weak assertions would miss a
	# mob spawned at default scale; we assert the actual delta on every mob.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_load_room_at_index", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	# Apply via the same internal Main uses for the boot override + key step.
	main.call("_apply_char_scale", 0.6)
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	var player: Node = main.get("_player")
	assert_not_null(player, "Main has a player after boot")
	assert_almost_eq((player as Node2D).scale.x, 0.6, 0.0001, "player root scaled to 0.6 (no factor)")
	assert_almost_eq((player as Node2D).scale.y, 0.6, 0.0001, "player root scaled uniformly")
	var room: Node = main.get("_current_room")
	assert_not_null(room, "Room02 loaded")
	var mobs: Array = room.call("get_spawned_mobs")
	assert_gt(mobs.size(), 0, "Room02 spawned at least one mob")
	for m in mobs:
		assert_almost_eq(
			(m as Node2D).scale.x,
			0.6 * mob_factor,
			0.0001,
			"non-boss mob %s scaled to 0.6 × MOB_SCALE_FACTOR (bigger than player)" % str(m.name)
		)


func test_apply_char_scale_scales_assembler_floor_mobs() -> void:
	# REGRESSION-86ca5hwmx (Sponsor soak of a1a809d): in the `?s1_assembler=1`
	# yard a full-size (1.0) grunt stood ~2x the 0.48 player. Root cause: the
	# pre-fix `_apply_char_scale` early-returned on `_current_room == null` —
	# which is exactly the state on the assembler path (`_render_assembled_s1_floor`
	# tears the static room down). So the PLAYER scaled but the assembled-floor
	# mobs (`_s1_mobs`) NEVER did. This test boots the assembler floor and asserts
	# every spawned non-boss mob's ROOT scale tracks the applied value — the
	# `_current_room == null`-guard regression cannot recur silently.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("load_s1_zone_for_test")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.call("is_s1_floor_active"), "S1 assembler floor active")
	# The static room is null on the assembler path — the exact pre-fix early-out.
	assert_null(main.get("_current_room"), "assembler path has no static _current_room")
	main.call("_apply_char_scale", 0.48)
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	var player: Node = main.get("_player")
	assert_not_null(player, "Main has a player on the assembler floor")
	assert_almost_eq(
		(player as Node2D).scale.x, 0.48, 0.0001, "player root scaled to 0.48 on assembler floor"
	)
	var s1_mobs: Array = main.call("get_s1_mobs")
	assert_gt(s1_mobs.size(), 0, "assembler yard slice spawned the authored grunt mobs")
	for m in s1_mobs:
		if m == null or not is_instance_valid(m):
			continue
		# Boss exclusion still holds — the yard slice spawns only grunts, but the
		# filter is the same `_char_scale_is_boss` path, so a future boss spawn
		# stays 1.0. Here every mob is a non-boss grunt → must be 0.48 × MOB_SCALE_FACTOR
		# (the soak-rev #426 mobs-bigger tune — bigger than the 0.48 player).
		assert_almost_eq(
			(m as Node2D).scale.x,
			0.48 * mob_factor,
			0.0001,
			"assembler-floor non-boss mob %s scaled to 0.48 × MOB_SCALE_FACTOR (app-gap fix + bigger-mob tune)"
			% str(m.name)
		)
	main.queue_free()


func test_main_room_load_applies_production_default_with_no_param() -> void:
	# THE LOCK end-to-end (ticket 86ca3rgxq): with NO `?char_scale` param active
	# (the default headless/desktop state — no JS bridge), loading a room must scale
	# the player + every non-boss mob to the 0.6 production default via the actual
	# `_load_room_at_index` → `_reapply_char_scale_if_active` → `effective_char_scale`
	# path — NOT a direct `_apply_char_scale(0.6)` call. This catches a regression
	# where the boot/room-load path stops applying the default (the silent-killer
	# class: a weak "scale != 1.0" assertion would pass; we assert the actual 0.6).
	assert_false(_flags.has_char_scale_override(), "no param override active (default state)")
	# SOAK-REVISION #426: assert the CONSTANT (now 0.48), not a hardcoded 0.6, so the test
	# tracks the production-default tune intentionally rather than pinning the old value.
	assert_almost_eq(
		_flags.effective_char_scale(),
		_flags.CHAR_SCALE_PRODUCTION_DEFAULT,
		0.0001,
		"effective default is the production default going in"
	)
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_load_room_at_index", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	var player: Node = main.get("_player")
	assert_not_null(player, "Main has a player after boot")
	assert_almost_eq(
		(player as Node2D).scale.x,
		_flags.CHAR_SCALE_PRODUCTION_DEFAULT,
		0.0001,
		"player scaled to the production default by the room-load path (no param)",
	)
	var room: Node = main.get("_current_room")
	var mobs: Array = room.call("get_spawned_mobs")
	assert_gt(mobs.size(), 0, "Room02 spawned at least one mob")
	for m in mobs:
		# Non-boss mobs render at production_default × MOB_SCALE_FACTOR (soak-rev #426
		# mobs-bigger tune) — clearly bigger than the player at production_default.
		assert_almost_eq(
			(m as Node2D).scale.x,
			_flags.CHAR_SCALE_PRODUCTION_DEFAULT * mob_factor,
			0.0001,
			"non-boss mob %s scaled to production_default × MOB_SCALE_FACTOR (no param)" % str(m.name),
		)


func test_main_room_load_param_override_supersedes_default() -> void:
	# The dial is INTACT end-to-end: with a param/dial override active, the room-load
	# path applies the OVERRIDE (0.8), not the 0.6 default — proving `?char_scale=N`
	# still wins after the lock.
	_flags.set_char_scale_for_test(0.8)
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_load_room_at_index", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	var player: Node = main.get("_player")
	assert_almost_eq(
		(player as Node2D).scale.x,
		0.8,
		0.0001,
		"override (0.8) supersedes the 0.6 default on room load (dial intact)",
	)
	var room: Node = main.get("_current_room")
	for m in room.call("get_spawned_mobs"):
		# Mobs honor the OVERRIDE base (0.8) × MOB_SCALE_FACTOR — the bigger-mob factor
		# rides on whatever scale is applied, override or default.
		assert_almost_eq(
			(m as Node2D).scale.x,
			0.8 * mob_factor,
			0.0001,
			"non-boss mob honors the 0.8 override × MOB_SCALE_FACTOR, not 0.6"
		)


func test_main_apply_char_scale_one_leaves_player_ship_size_mobs_bigger() -> void:
	# The PLAYER production-safety contract: applying 1.0 leaves the PLAYER at ship
	# scale (1,1). Post soak-rev #426, NON-BOSS mobs ALWAYS render MOB_SCALE_FACTOR
	# bigger than the applied scale — even at the 1.0 "full size" apply a mob is
	# 1.15×. The bigger-mob silhouette is intentional at every scale, not just the
	# 0.48 default; the player is the size reference, mobs read bigger than it.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_load_room_at_index", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_apply_char_scale", 1.0)
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	var player: Node = main.get("_player")
	assert_almost_eq(
		(player as Node2D).scale.x, 1.0, 0.0001, "player at ship scale under 1.0 apply"
	)
	var room: Node = main.get("_current_room")
	for m in room.call("get_spawned_mobs"):
		assert_almost_eq(
			(m as Node2D).scale.x,
			1.0 * mob_factor,
			0.0001,
			"mob at 1.0 × MOB_SCALE_FACTOR under 1.0 apply (bigger than the 1.0 player)"
		)


# --- 8d. MOB_SCALE_FACTOR — mobs render bigger than the player (soak-rev #426) -


func test_nonboss_mob_renders_mob_scale_factor_bigger_than_player() -> void:
	# THE soak-rev #426 contract (Sponsor 2026-06-08): a NON-BOSS mob renders
	# clearly BIGGER than the player. The ratio of mob.scale ÷ player.scale must
	# be EXACTLY MOB_SCALE_FACTOR (1.15) — asserted as the ratio itself so the
	# test tracks the constant, not a hardcoded 0.552. This is the load-bearing
	# pin: at the 0.48 production default the player reads 0.48 and every grunt
	# reads 0.552, i.e. 15% bigger.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_load_room_at_index", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_apply_char_scale", _flags.CHAR_SCALE_PRODUCTION_DEFAULT)
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	assert_almost_eq(mob_factor, 1.15, 0.0001, "MOB_SCALE_FACTOR is the 15%-bigger tune")
	var player: Node = main.get("_player")
	var player_scale: float = (player as Node2D).scale.x
	assert_gt(player_scale, 0.0, "player has a positive scale to ratio against")
	var room: Node = main.get("_current_room")
	var mobs: Array = room.call("get_spawned_mobs")
	assert_gt(mobs.size(), 0, "Room02 spawned at least one mob")
	for m in mobs:
		var mob_scale: float = (m as Node2D).scale.x
		# The RATIO is MOB_SCALE_FACTOR — mob is 15% bigger than the player.
		assert_almost_eq(
			mob_scale / player_scale,
			mob_factor,
			0.0001,
			"non-boss mob %s renders MOB_SCALE_FACTOR (1.15×) bigger than the player" % str(m.name)
		)
		assert_gt(mob_scale, player_scale, "mob is strictly bigger than the player")


# --- 9. Boss exclusion --------------------------------------------------------


func test_char_scale_is_boss_discriminates_on_boss_died_signal() -> void:
	# `_char_scale_is_boss` must use the `boss_died` signal — the SAME
	# discriminator `_wire_mob` uses — so every boss (S1 / S2 / future) is auto-
	# excluded and no regular mob is. A real Stratum1Boss has boss_died; a real
	# Grunt does not.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var boss: Node = preload("res://scenes/mobs/Stratum1Boss.tscn").instantiate()
	add_child_autofree(boss)
	var grunt: Node = preload("res://scenes/mobs/Grunt.tscn").instantiate()
	add_child_autofree(grunt)
	assert_true(boss.has_signal("boss_died"), "Stratum1Boss has boss_died (boss discriminator)")
	assert_false(grunt.has_signal("boss_died"), "Grunt has no boss_died (regular mob)")
	assert_true(main.call("_char_scale_is_boss", boss), "boss is excluded from char-scale")
	assert_false(main.call("_char_scale_is_boss", grunt), "regular grunt is scaled (not excluded)")


func test_apply_char_scale_leaves_boss_full_size_among_mobs() -> void:
	# End-to-end exclusion at the apply seam: even when a boss is present alongside
	# regular mobs, `_apply_char_scale(0.6)` (the production default) scales the
	# regular mob to 0.6 but leaves the boss at full size 1.0. This is the
	# Sponsor's "bosses stay full size" lock under the 0.6 default. (Production boss
	# rooms double-exclude — they expose get_boss(), not get_spawned_mobs() — but
	# this pins the in-loop `_char_scale_is_boss` continue branch directly.)
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var boss: Node = preload("res://scenes/mobs/Stratum1Boss.tscn").instantiate()
	var grunt: Node = preload("res://scenes/mobs/Grunt.tscn").instantiate()
	var stub_room: Node = StubRoom.new()
	stub_room.mobs = [boss, grunt]
	main.set("_current_room", stub_room)
	add_child_autofree(stub_room)
	stub_room.add_child(boss)
	stub_room.add_child(grunt)
	await get_tree().process_frame
	main.call("_apply_char_scale", 0.6)
	var mob_factor: float = main.get("MOB_SCALE_FACTOR")
	assert_almost_eq(
		(boss as Node2D).scale.x, 1.0, 0.0001, "boss stays full size 1.0 under the 0.6 default"
	)
	# Boss-unaffected pin (soak-rev #426): the boss must NOT receive the bigger-mob
	# multiply either — it is excluded before the multiply, so it stays a clean 1.0,
	# explicitly NOT 0.6 (scaled) and NOT 0.6 × 1.15 (scaled + factored).
	assert_ne(
		(boss as Node2D).scale.x, 0.6 * mob_factor, "boss is NOT multiplied by MOB_SCALE_FACTOR"
	)
	# The bigger-mob factor (soak-rev #426) rides on the regular grunt, NOT the boss
	# — the boss is excluded before the multiply, so it stays a clean 1.0.
	assert_almost_eq(
		(grunt as Node2D).scale.x,
		0.6 * mob_factor,
		0.0001,
		"regular grunt scaled to 0.6 × MOB_SCALE_FACTOR (boss exempt from both scale + factor)"
	)


func test_main_source_apply_char_scale_excludes_boss() -> void:
	# Structural pin: `_apply_char_scale` body calls `_char_scale_is_boss` and
	# `continue`s on a true result — guards against a future refactor that drops
	# the boss-exclusion branch (which would shrink the boss, violating the
	# Sponsor's explicit "bosses stay full size" choice).
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var fn_start: int = source.find("func _apply_char_scale(")
	assert_gt(fn_start, -1, "Main defines _apply_char_scale")
	var body_start: int = source.find("\n", fn_start)
	var next_fn: int = source.find("\nfunc ", body_start)
	var fn_body: String = source.substr(body_start, next_fn - body_start)
	assert_true(
		fn_body.find("_char_scale_is_boss") > -1,
		"_apply_char_scale consults _char_scale_is_boss for boss exclusion"
	)
	assert_true(fn_body.find("get_spawned_mobs") > -1, "_apply_char_scale iterates spawned mobs")


# --- Test helpers -------------------------------------------------------------


## Minimal stand-in for a room that exposes `get_spawned_mobs()` — lets the
## boss-exclusion test feed a boss + a regular mob through `_apply_char_scale`'s
## iteration without instantiating the full boss-room fixture graph.
class StubRoom:
	extends Node2D
	var mobs: Array = []

	func get_spawned_mobs() -> Array:
		return mobs

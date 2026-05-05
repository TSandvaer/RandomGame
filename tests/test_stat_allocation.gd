extends GutTest
## Tests for `scripts/ui/StatAllocationPanel.gd` — the level-up panel that
## consumes banked stat points and writes V/F/E into PlayerStats.
##
## Per Devon run-006 task spec (`86c9kxx2y`):
##   1. Panel auto-opens on the first-ever level-up (Uma's BI-7 / LU-05).
##   2. Player presses 1 -> vigor incremented, focus/edge unchanged.
##   3. Player presses Enter -> allocation saved, panel closes.
##   4. Player presses Esc -> allocation banked (unsaved points carry to
##      next session via save).
##   5. Time-slow active while panel open.
##   6. 12 tooltip strings load from `stat_strings.tres`.

const StatAllocationPanelScript: Script = preload("res://scripts/ui/StatAllocationPanel.gd")
const StatStringsScript: Script = preload("res://scripts/content/StatStrings.gd")
const TEST_SLOT: int = 987


func _ps() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("PlayerStats")
	assert_not_null(n, "PlayerStats autoload registered")
	return n


func _levels() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Levels")
	assert_not_null(n, "Levels autoload registered")
	return n


func _save() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(n, "Save autoload registered")
	return n


func _make_panel() -> StatAllocationPanel:
	var packed: PackedScene = load("res://scenes/ui/StatAllocationPanel.tscn")
	assert_not_null(packed, "panel scene loads")
	var panel: StatAllocationPanel = packed.instantiate()
	add_child_autofree(panel)
	return panel


func before_each() -> void:
	_ps().reset()
	_levels().reset()
	# Reset Engine.time_scale in case a prior test left it slowed.
	Engine.time_scale = 1.0
	# Wipe save slot so first-level-up auto-open behavior is deterministic.
	if _save().has_save(0):
		_save().delete_save(0)
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func after_each() -> void:
	Engine.time_scale = 1.0
	if _save().has_save(0):
		_save().delete_save(0)
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	_ps().reset()
	_levels().reset()


# =======================================================================
# Spec test 1: panel auto-opens on first-ever level-up (LU-05 / BI-7)
# =======================================================================

func test_panel_auto_opens_on_first_level_up() -> void:
	var panel: StatAllocationPanel = _make_panel()
	# Sanity: hidden by default.
	assert_false(panel.is_open(), "panel starts closed")
	# Drive the player past L1 -> L2 (100 XP needed).
	_levels().gain_xp(100)
	# Panel should have opened automatically.
	assert_true(panel.is_open(),
		"panel auto-opens on first level-up (LU-05)")
	assert_eq(_ps().get_unspent_points(), 1,
		"first level-up grants 1 unspent stat point")


func test_panel_does_not_auto_open_on_subsequent_level_ups() -> void:
	# Mark first-level-up as already-seen via the save (simulating a
	# returning player past L2).
	var data: Dictionary = _save().default_payload()
	data["character"]["first_level_up_seen"] = true
	_save().save_game(0, data)
	var panel: StatAllocationPanel = _make_panel()
	_levels().gain_xp(100)  # crosses L1 -> L2
	assert_false(panel.is_open(),
		"panel does NOT auto-open on subsequent level-ups (LU-06)")
	# The point is still banked.
	assert_eq(_ps().get_unspent_points(), 1)


# =======================================================================
# Spec test 2: pressing 1 increments vigor, leaves focus/edge alone
# =======================================================================

func test_press_1_allocates_to_vigor_only() -> void:
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	panel.force_press_for_test(&"1")
	assert_eq(_ps().get_stat(&"vigor"), 1,
		"pressing 1 incremented vigor")
	assert_eq(_ps().get_stat(&"focus"), 0, "focus unchanged")
	assert_eq(_ps().get_stat(&"edge"), 0, "edge unchanged")


func test_press_2_allocates_to_focus_only() -> void:
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	panel.force_press_for_test(&"2")
	assert_eq(_ps().get_stat(&"focus"), 1)
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_eq(_ps().get_stat(&"edge"), 0)


func test_press_3_allocates_to_edge_only() -> void:
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	panel.force_press_for_test(&"3")
	assert_eq(_ps().get_stat(&"edge"), 1)
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_eq(_ps().get_stat(&"focus"), 0)


# =======================================================================
# Spec test 3: Enter saves and closes
# =======================================================================

func test_enter_closes_panel() -> void:
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(2)
	panel.open(false)
	assert_true(panel.is_open())
	# Allocate one then Enter to close (1 banked stays).
	panel.force_press_for_test(&"1")
	panel.force_press_for_test(&"enter")
	assert_false(panel.is_open(), "Enter closes the panel")


func test_allocation_persists_to_save_immediately() -> void:
	# Per panel spec: every allocate writes to Save so quit-mid-allocation
	# preserves progress.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	panel.force_press_for_test(&"3")  # +1 edge
	# The panel auto-dismisses at bank=0 (Uma LU-24); confirm allocation
	# made it to disk.
	var loaded: Dictionary = _save().load_game(0)
	assert_false(loaded.is_empty(), "save was written")
	assert_eq(loaded["character"]["stats"]["edge"], 1,
		"edge=1 persisted to save")


# =======================================================================
# Spec test 4: Esc banks the unspent point(s)
# =======================================================================

func test_esc_closes_and_banks_remaining_points() -> void:
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(3)
	panel.open(false)
	# Allocate once (now 2 left), press Esc to bank.
	panel.force_press_for_test(&"1")
	assert_eq(_ps().get_unspent_points(), 2, "2 banked after 1 spend of 3")
	panel.force_press_for_test(&"esc")
	assert_false(panel.is_open(), "Esc closes the panel")
	assert_eq(_ps().get_unspent_points(), 2,
		"Esc preserves banked points (no auto-spend)")


func test_banked_points_carry_via_save() -> void:
	# Allocate, Esc, save round-trip — the unspent count survives.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(2)
	panel.open(false)
	panel.force_press_for_test(&"1")
	# 1 left in bank — the allocate path called _persist_to_save, so the
	# disk-side state should already reflect 1 banked.
	var loaded: Dictionary = _save().load_game(0)
	assert_false(loaded.is_empty())
	assert_eq(loaded["character"]["unspent_stat_points"], 1,
		"banked points written to save during allocate")


# =======================================================================
# Spec test 5: time-slow active while panel open (LU-09)
# =======================================================================

func test_time_slow_factor_is_uma_10_percent() -> void:
	# Static contract — Uma `level-up-panel.md` Beat 2 specifies 10%.
	# If this drifts the test bounces.
	assert_almost_eq(StatAllocationPanel.TIME_SLOW_FACTOR, 0.10, 0.001,
		"time slow factor is 10% per Uma spec")


func test_time_slow_applied_while_panel_open() -> void:
	var panel: StatAllocationPanel = _make_panel()
	assert_almost_eq(Engine.time_scale, 1.0, 0.001,
		"time scale starts at 1.0")
	panel.open(false)
	assert_almost_eq(Engine.time_scale, 0.10, 0.001,
		"opening the panel sets time_scale to 0.10 (Uma 10%)")
	panel.close()
	assert_almost_eq(Engine.time_scale, 1.0, 0.001,
		"closing the panel restores time_scale to 1.0")


# =======================================================================
# Spec test 6: 12 tooltip strings load from stat_strings.tres
# =======================================================================

func test_stat_strings_resource_loads_with_12_strings() -> void:
	var ss: Resource = load("res://content/ui/stat_strings.tres")
	assert_not_null(ss, "stat_strings.tres must exist and load")
	assert_true(ss is StatStrings, "loaded resource is StatStrings")
	var statstrings: StatStrings = ss
	var d: Dictionary = statstrings.to_dict()
	assert_eq(d.size(), 12,
		"resource exposes exactly 12 canonical strings (Uma's tooltip language standard)")
	# Spot-check each stat has all 4 keys (header / sub_header / body / flavor).
	for stat: String in ["vigor", "focus", "edge"]:
		assert_true(d.has(stat + "_header"))
		assert_true(d.has(stat + "_sub_header"))
		assert_true(d.has(stat + "_body"))
		assert_true(d.has(stat + "_flavor"))
		assert_ne(d[stat + "_header"], "", "%s_header is non-empty" % stat)
		assert_ne(d[stat + "_sub_header"], "", "%s_sub_header is non-empty" % stat)
		assert_ne(d[stat + "_body"], "", "%s_body is non-empty" % stat)
		assert_ne(d[stat + "_flavor"], "", "%s_flavor is non-empty" % stat)


func test_stat_strings_lookup_api_returns_uma_canonical_strings() -> void:
	var ss: StatStrings = load("res://content/ui/stat_strings.tres")
	# Per Uma's canonical 12 strings table.
	assert_eq(ss.get_header(&"vigor"), "VIGOR")
	assert_eq(ss.get_header(&"focus"), "FOCUS")
	assert_eq(ss.get_header(&"edge"), "EDGE")
	assert_eq(ss.get_sub_header(&"vigor"), "toughness · health pool · stamina")
	# Body lines start with a "+" prefix per Uma's affix-style numerics.
	assert_true(ss.get_body(&"vigor").begins_with("+"),
		"vigor body starts with '+' per Uma's affix-style numerics")
	# Flavor uses second-person "you" or quoted second-person voice.
	var flavor: String = ss.get_flavor(&"vigor")
	assert_true(flavor.contains("you") or flavor.contains("You") or flavor.contains("\""),
		"vigor flavor uses second-person voice")


func test_unknown_stat_id_returns_empty_string() -> void:
	var ss: StatStrings = load("res://content/ui/stat_strings.tres")
	assert_eq(ss.get_header(&"unknown_stat"), "",
		"unknown stat id returns empty string (no crash)")


# =======================================================================
# Edge probes
# =======================================================================

func test_press_with_empty_bank_is_noop() -> void:
	# Edge probe — pressing 1/2/3 with no banked points is a silent no-op.
	var panel: StatAllocationPanel = _make_panel()
	panel.open(false)
	# Bank is empty.
	panel.force_press_for_test(&"1")
	assert_eq(_ps().get_stat(&"vigor"), 0,
		"pressing 1 with empty bank does NOT increment")


func test_panel_auto_dismisses_when_bank_empties() -> void:
	# Uma LU-24: panel auto-dismisses when the bank empties.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	assert_true(panel.is_open())
	panel.force_press_for_test(&"1")
	assert_false(panel.is_open(),
		"panel auto-dismisses after spending the last point")


func test_multi_level_catch_up_keeps_panel_open() -> void:
	# Uma LU-23: with 2+ banked, allocating 1 leaves the panel open
	# until the bank empties.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(3)
	panel.open(false)
	panel.force_press_for_test(&"1")
	assert_true(panel.is_open(), "panel stays open while bank > 0")
	panel.force_press_for_test(&"2")
	assert_true(panel.is_open(), "still open after 2 spends with 3 in bank")
	panel.force_press_for_test(&"3")
	# 3 -> 0 — should auto-dismiss now.
	assert_false(panel.is_open(),
		"panel auto-dismisses on spending the final banked point")


# =======================================================================
# BB-4 (`86c9m395d`): P-key reopen handler
# =======================================================================
#
# Tess bug-bash run-024 caught: panel auto-opens on level-up, player presses
# Esc to bank, then expects "press P" (per docstring + HUD pip cue) to
# reopen — but no P-key handler existed. These tests lock the fix:
#
#   1. P after a close-with-bank reopens the panel (the load-bearing repro).
#   2. P while open closes (idempotent toggle).
#   3. P with empty bank is a silent no-op (don't open an empty panel —
#      Tess's "verification gate" in `m1-bugbash-4484196.md` §BB-4).
#   4. Live `_unhandled_input` path raised via Input.parse_input_event so
#      we cover the wiring in production, not just `force_p_keypress_for_test`.

func _send_p_key_event() -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.physical_keycode = KEY_P
	Input.parse_input_event(ev)
	# Drain the event queue so _unhandled_input fires before we assert.
	# parse_input_event posts to the queue; flush + advance one process tick.
	Input.flush_buffered_events()


func test_p_key_reopens_panel_after_close_with_banked_points() -> void:
	# The exact Tess run-024 repro: open panel, close (bank), P-key reopens.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	assert_true(panel.is_open(), "panel opened (auto-open simulation)")
	panel.close()
	assert_false(panel.is_open(), "panel closed (bank with 1 point left)")
	assert_eq(_ps().get_unspent_points(), 1,
		"point still banked after close")
	# This is the load-bearing assertion — pre-fix this would stay false.
	panel.force_p_keypress_for_test()
	assert_true(panel.is_open(),
		"BB-4: P-key reopens panel after close with banked points")


func test_p_key_toggles_closed_when_panel_already_open() -> void:
	# Idempotent toggle — pressing P with the panel already open closes it.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(2)
	panel.open(false)
	assert_true(panel.is_open(), "open before toggle")
	panel.force_p_keypress_for_test()
	assert_false(panel.is_open(),
		"BB-4: P toggles closed when already open")
	# And points are NOT auto-spent on the toggle-close.
	assert_eq(_ps().get_unspent_points(), 2,
		"toggle-close preserves banked points (Esc-equivalent semantics)")


func test_p_key_is_noop_when_bank_empty() -> void:
	# Per Tess `m1-bugbash-4484196.md` §BB-4 verification gate: P with an
	# empty bank should NOT open the panel. The HUD pip is hidden in this
	# state — opening would be a UX dead-end (no points to spend).
	var panel: StatAllocationPanel = _make_panel()
	assert_false(panel.is_open(), "starts closed")
	assert_eq(_ps().get_unspent_points(), 0, "bank empty before press")
	panel.force_p_keypress_for_test()
	assert_false(panel.is_open(),
		"BB-4: P with empty bank does NOT open (don't open empty panel)")


func test_p_key_full_cycle_open_close_reopen_close() -> void:
	# The full Tess run-024 cycle: open -> close -> P reopen -> P close.
	# Single test asserts at least one open-then-reopen cycle (Self-Test
	# Report mandates the cycle is exercised).
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(2)
	panel.open(false)
	assert_true(panel.is_open(), "step 1: open")
	panel.close()
	assert_false(panel.is_open(), "step 2: close (banks 2)")
	panel.force_p_keypress_for_test()
	assert_true(panel.is_open(), "step 3: P reopens")
	panel.force_p_keypress_for_test()
	assert_false(panel.is_open(), "step 4: P closes again")
	# Bank is intact across the whole cycle (no toggle ate a point).
	assert_eq(_ps().get_unspent_points(), 2,
		"full toggle cycle preserves the 2 banked points")


func test_p_key_via_live_input_event_reopens_panel() -> void:
	# Defense-in-depth — drive the actual `_unhandled_input` wiring (NOT
	# the test-only `force_p_keypress_for_test` shim) so a future regression
	# of "the helper works but the live event handler doesn't" fails here.
	var panel: StatAllocationPanel = _make_panel()
	_ps().add_unspent_points(1)
	panel.open(false)
	panel.close()
	assert_false(panel.is_open(), "closed before live P press")
	# Raise a real KEY_P pressed event through the engine's input pipeline.
	_send_p_key_event()
	# _unhandled_input runs at end-of-frame; one process tick is enough.
	await get_tree().process_frame
	assert_true(panel.is_open(),
		"BB-4: live P keypress through _unhandled_input reopens the panel")

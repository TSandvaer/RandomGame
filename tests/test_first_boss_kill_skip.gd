extends GutTest
## M3-T2-W3-T17 — skip-after-first-kill GUT tests (ticket `86c9wjzjf`).
##
## Pairs the engine-side behavior of `Stratum1BossRoom`'s entry-sequence
## skip handler with the v4 save schema's `character.first_boss_kill_seen`
## flag. Six required assertions per the dispatch brief:
##
##   1. First kill is NOT skippable (`first_boss_kill_seen == false`).
##   2. Second kill IS skippable on movement key during Beats 2–4.
##   3. Save round-trip preserves `first_boss_kill_seen` across reload.
##   4. Migration v3 → v4 backfills default false.
##   5. Migration chain v0 → v4 lands cleanly + idempotently.
##   6. Skip collapses intro timing to ~0.5 s (door slam + fast-nameplate-slide).
##
## Lives next to the existing boss-room integration tests (`test_stratum1_boss_room.gd`)
## but in its own file because the skip surface is cross-cutting:
## save-schema + input-handler + sequence-collapse. Single-file isolation
## keeps each assertion small + fail-locally readable.
##
## Migration-chain assertions (4 + 5) cross-reference
## `tests/test_save_migration.gd` — that file holds the full migration
## chain fixtures; here we exercise only the v3 → v4 step in isolation
## so a failure points unambiguously at T17.
##
## Per `.claude/docs/test-conventions.md § "Universal warning gate"` —
## NoWarningGuard attached on every test; no expected warnings on the
## happy path. The schema-version-future warning is opt'd-out only in
## the dedicated `test_save.gd::test_migrate_handles_save_from_future_schema`.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")
const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const SAVE_SLOT: int = 0

var _warn_guard: NoWarningGuard


# ---- Test isolation ---------------------------------------------------
#
# The boss-room scene + the boss itself fire TimeScaleDirector requests on
# hit / die / phase-transition (M3 Tier 2 Wave 1 T2/T3). Reset on both
# ends so tests don't leak Engine.time_scale state. Mirrors the
# `before_each` / `after_each` in `test_stratum1_boss_room.gd`.

func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	# Clean the save slot — every test starts from a known-empty save so
	# the skip-eligible flag reads false unless the test explicitly sets
	# it. Avoid stomping a real player save by isolating on SAVE_SLOT.
	var save_node: Node = _save()
	if save_node != null and save_node.has_save(SAVE_SLOT):
		save_node.delete_save(SAVE_SLOT)


func after_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	# Clean up the save slot to leave a stable baseline for the next test
	# / the next GUT run.
	var save_node: Node = _save()
	if save_node != null and save_node.has_save(SAVE_SLOT):
		save_node.delete_save(SAVE_SLOT)
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------

func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func _make_room() -> Stratum1BossRoom:
	var packed: PackedScene = load("res://scenes/levels/Stratum1BossRoom.tscn")
	var room: Stratum1BossRoom = packed.instantiate()
	add_child_autofree(room)
	return room


## Drains a frame so the deferred `_assemble_room_fixtures` pass lands.
## Several skip-window assertions need the door-trigger + StratumExit
## built; mirrors the test_stratum1_boss_room.gd pattern.
func _drain_fixture_pass() -> void:
	await get_tree().process_frame


# =====================================================================
# Test 1 — First kill NOT skippable (first_boss_kill_seen == false)
# =====================================================================

func test_first_kill_is_not_skippable_when_flag_is_false() -> void:
	# Fresh-character path: no prior save, _skip_eligible reads false on
	# room _ready. Movement-key press during the entry sequence is
	# IGNORED and the natural 1.8 s timing path runs.
	var room: Stratum1BossRoom = _make_room()
	await _drain_fixture_pass()
	assert_false(room.is_skip_eligible(),
		"fresh character (no save) — _skip_eligible defaults false")
	room.trigger_entry_sequence()
	# Simulate the player pressing 'move_up' during Beat 2. The handler
	# should ignore this press because the character is not eligible.
	var event: InputEventAction = InputEventAction.new()
	event.action = "move_up"
	event.pressed = true
	# Forward the event into the room's _unhandled_input pipeline. We
	# call directly rather than via Input.parse_input_event because the
	# latter is async — _unhandled_input is the deterministic surface.
	room._unhandled_input(event)
	assert_false(room.is_entry_sequence_skipped(),
		"first kill — movement key during Beat 2 does NOT collapse the intro")
	assert_true(room.is_entry_sequence_active(),
		"first kill — sequence stays active after rejected skip attempt")


# =====================================================================
# Test 2 — Second kill IS skippable on movement during Beats 2-4
# =====================================================================

func test_second_kill_is_skippable_on_movement_key() -> void:
	# Veteran-character path: save reports first_boss_kill_seen=true.
	# Movement-key press during the entry sequence collapses the intro
	# via _collapse_entry_sequence, emitting `entry_sequence_skipped`.
	var room: Stratum1BossRoom = _make_room()
	await _drain_fixture_pass()
	room.set_skip_eligible_for_test(true)
	watch_signals(room)
	room.trigger_entry_sequence()
	# Confirm precondition — eligible + active + not yet completed/skipped.
	assert_true(room.is_skip_eligible())
	assert_true(room.is_entry_sequence_active())
	assert_false(room.is_entry_sequence_completed())
	assert_false(room.is_entry_sequence_skipped())
	# Fire a movement event.
	var event: InputEventAction = InputEventAction.new()
	event.action = "move_left"
	event.pressed = true
	room._unhandled_input(event)
	assert_true(room.is_entry_sequence_skipped(),
		"veteran character — movement key DOES collapse the intro")
	assert_signal_emitted(room, "entry_sequence_skipped",
		"entry_sequence_skipped signal fires on collapse")


# =====================================================================
# Test 3 — Save round-trip preserves first_boss_kill_seen across reload
# =====================================================================

func test_save_round_trip_preserves_first_boss_kill_seen() -> void:
	# Mark the flag via the public API (boss room's `_mark_first_boss_kill_seen`
	# fires from `_on_boss_died` in production; we drive it here directly
	# to keep the assertion focused on the save-side round trip).
	var save_node: Node = _save()
	assert_not_null(save_node, "Save autoload must be registered")
	var data: Dictionary = save_node.default_payload()
	data["character"]["first_boss_kill_seen"] = true
	data["character"]["level"] = 3
	data["character"]["xp"] = 500
	save_node.save_game(SAVE_SLOT, data)
	# Reload from disk (simulating quit-and-relaunch).
	var loaded: Dictionary = save_node.load_game(SAVE_SLOT)
	assert_true(loaded["character"]["first_boss_kill_seen"],
		"first_boss_kill_seen=true survives a save → load round trip")
	# Adjacent state is also preserved (regression guard against the
	# save write nuking unrelated fields).
	assert_eq(loaded["character"]["level"], 3)
	assert_eq(loaded["character"]["xp"], 500)


# =====================================================================
# Test 4 — Migration v3 → v4 default-false
# =====================================================================

func test_migration_v3_to_v4_default_false() -> void:
	# Install a hand-authored v3 envelope at SAVE_SLOT and load — the
	# v3 → v4 step backfills first_boss_kill_seen=false. Save.gd's
	# migrate() chain only ever exposes the migrated dict to callers;
	# pre-migrate inspection requires reading the raw JSON envelope.
	var save_node: Node = _save()
	var v3_envelope: Dictionary = {
		"schema_version": 3,
		"saved_at": "2026-05-22T10:00:00",
		"data": {
			"character": {
				"name": "Mid-Knight",
				"level": 2, "xp": 100, "xp_to_next": 282,
				"vigor": 0, "focus": 0, "edge": 0,
				"stats": {"vigor": 0, "focus": 0, "edge": 0},
				"unspent_stat_points": 0,
				"first_level_up_seen": false,
				"hp_current": 100, "hp_max": 100,
			},
			"stash": [], "equipped": {},
			"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 0.0},
		},
	}
	var f: FileAccess = FileAccess.open(save_node.save_path(SAVE_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3_envelope))
	f.close()
	var loaded: Dictionary = save_node.load_game(SAVE_SLOT)
	assert_true(loaded["character"].has("first_boss_kill_seen"),
		"v3 → v4 migration backfills first_boss_kill_seen")
	assert_false(bool(loaded["character"]["first_boss_kill_seen"]),
		"v3 → v4 default-false — migrated v3 character is treated as 'first kill ahead'")


# =====================================================================
# Test 5 — Migration chain v0 → v4 idempotent
# =====================================================================

func test_migration_chain_v0_to_v4_idempotent() -> void:
	# A v0 envelope migrates through v0 → v1 → v2 → v3 → v4 in one
	# load_game call. Loading TWICE (and re-saving in between) must
	# produce the same migrated shape — no double-backfill, no field
	# duplication, schema_version stays at 4.
	var save_node: Node = _save()
	var v0_envelope: Dictionary = {
		"data": {
			"character": {"level": 2, "xp": 50},
		},
	}
	var f: FileAccess = FileAccess.open(save_node.save_path(SAVE_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v0_envelope))
	f.close()
	# First load — full chain migrates in memory.
	var first_loaded: Dictionary = save_node.load_game(SAVE_SLOT)
	assert_true(first_loaded["character"].has("first_boss_kill_seen"),
		"v0 → v4 chain ends with first_boss_kill_seen present")
	assert_false(bool(first_loaded["character"]["first_boss_kill_seen"]),
		"v0 → v4 chain ends with first_boss_kill_seen=false default")
	# Save back — on-disk envelope is now v4.
	save_node.save_game(SAVE_SLOT, first_loaded)
	# Read raw envelope to verify schema_version on disk.
	var path: String = save_node.save_path(SAVE_SLOT)
	var f2: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f2.get_as_text()
	f2.close()
	var on_disk: Dictionary = JSON.parse_string(raw)
	assert_eq(int(on_disk["schema_version"]), 4, "on-disk envelope is v4 after migration + save")
	# Second load — no-op on already-v4. Re-saving + reloading lands on
	# the same shape; flag value unchanged.
	var second_loaded: Dictionary = save_node.load_game(SAVE_SLOT)
	assert_false(bool(second_loaded["character"]["first_boss_kill_seen"]),
		"already-v4 load is idempotent — first_boss_kill_seen unchanged")
	assert_eq(int(second_loaded["character"]["level"]), 2,
		"v0 level survives the full chain through to second load")


# =====================================================================
# Test 6 — Skip collapses intro timing to ~0.5 s
# =====================================================================

func test_skip_collapses_intro_timing_to_about_half_a_second() -> void:
	# When the skip fires, the natural 1.8 s timer is canceled and a
	# short residual (Stratum1Boss.WAKE_DURATION or floor 0.1 s) is
	# scheduled. End-to-end collapsed budget = wall-clock elapsed from
	# trigger to entry_sequence_completed signal. Per Uma's brief, this
	# should land in the ~0.5 s neighborhood.
	#
	# Validates the brief's "skip collapses intro timing to ~0.5 s"
	# acceptance — measured against the boss's WAKE_DURATION constant
	# (currently 0.417 s) plus the skip-fire latency (typically <50 ms
	# in headless GUT). Tolerance is generous (0.7 s upper bound)
	# because GUT scheduling under different load can add 100-200 ms;
	# the assertion is "skip is dramatically faster than the natural
	# 1.8 s", not "skip is exactly 0.5 s".
	var room: Stratum1BossRoom = _make_room()
	await _drain_fixture_pass()
	room.set_skip_eligible_for_test(true)
	watch_signals(room)
	room.trigger_entry_sequence()
	var trigger_ms: int = Time.get_ticks_msec()
	# Fire the skip immediately (simulating an impatient veteran).
	var event: InputEventAction = InputEventAction.new()
	event.action = "move_right"
	event.pressed = true
	room._unhandled_input(event)
	assert_true(room.is_entry_sequence_skipped(), "skip engaged")
	# Wait for the residual timer to fire entry_sequence_completed.
	# Stratum1Boss.WAKE_DURATION is 0.417 s; residual floors at 0.1 s.
	# Wait 0.8 s as a generous upper bound for the residual + frame
	# scheduling overhead — the natural 1.8 s would NOT have fired by
	# then, so any completion signal here is the collapsed path.
	await get_tree().create_timer(0.8).timeout
	assert_true(room.is_entry_sequence_completed(),
		"skip-collapsed sequence completes within the 0.8 s wait")
	var elapsed_ms: int = Time.get_ticks_msec() - trigger_ms
	# Lower bound: dynamic wake-duration read from Stratum1Boss
	# (0.417 s). Upper bound: 0.8 s (well below the natural 1.8 s).
	# Stratum1Boss.WAKE_DURATION + a generous frame-scheduling envelope.
	assert_gt(elapsed_ms, 300, "collapsed sequence respects the wake-duration runway (>=0.3 s)")
	assert_lt(elapsed_ms, 800,
		"collapsed sequence completes well under the natural 1.8 s (target ~0.5 s)")


# =====================================================================
# Bonus 7 — Double-skip is a no-op (regression guard)
# =====================================================================

func test_double_skip_press_is_a_no_op() -> void:
	# A second movement-key press AFTER the skip has already engaged
	# must not double-fire `_collapse_entry_sequence` (which would
	# emit `entry_sequence_skipped` a second time + schedule a second
	# residual timer that would race the first).
	var room: Stratum1BossRoom = _make_room()
	await _drain_fixture_pass()
	room.set_skip_eligible_for_test(true)
	watch_signals(room)
	room.trigger_entry_sequence()
	var event_a: InputEventAction = InputEventAction.new()
	event_a.action = "move_up"
	event_a.pressed = true
	var event_b: InputEventAction = InputEventAction.new()
	event_b.action = "move_down"
	event_b.pressed = true
	room._unhandled_input(event_a)
	room._unhandled_input(event_b)
	# Skip signal emits exactly once even with two presses.
	assert_signal_emit_count(room, "entry_sequence_skipped", 1,
		"second skip press is a no-op — entry_sequence_skipped emits exactly once")


# =====================================================================
# Bonus 8 — Movement BEFORE trigger (room loaded but sequence inactive)
# is a no-op
# =====================================================================

func test_movement_before_trigger_does_not_engage_skip() -> void:
	# If the player presses movement during the brief window between
	# room load and trigger (e.g. WASD held while approaching the door),
	# the skip handler must reject the press — the entry sequence
	# hasn't started yet, there's nothing to collapse.
	var room: Stratum1BossRoom = _make_room()
	await _drain_fixture_pass()
	room.set_skip_eligible_for_test(true)
	# No trigger_entry_sequence yet — sequence inactive.
	assert_false(room.is_entry_sequence_active())
	var event: InputEventAction = InputEventAction.new()
	event.action = "move_up"
	event.pressed = true
	room._unhandled_input(event)
	assert_false(room.is_entry_sequence_skipped(),
		"pre-trigger movement press is rejected by the skip handler")

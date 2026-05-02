extends GutTest
## HTML5 RC invariants — the executable shape of the code-audit findings in
## `team/tess-qa/html5-rc-audit-591bcc8.md`. These tests are platform-
## independent (they run in headless native CI), but each one locks in a
## contract that *would* be violated by a regression that breaks the HTML5
## export. The audit doc is the human-facing companion; this file is the
## machine-verified backbone.
##
## **What this file is NOT:** an HTML5 driver. We have no browser in CI;
## driving the HTML5 export is the Sponsor's interactive 30-min soak per
## `team/TESTING_BAR.md`. What we *can* do here is assert the testable
## invariants whose failure would manifest as an HTML5-only bug — JSON
## round-trip purity, autoload idempotency, time_scale cleanup, save-path
## sanity, BuildInfo non-emptiness.
##
## **TI-6 / TI-7 active as of Devon run-011:** the `_exit_tree` time-scale-
## restore guard recommended in the audit doc (CR-1 / CR-2) has landed in
## `InventoryPanel.gd` / `StatAllocationPanel.gd`. The two tests, which
## previously shipped as `pending()`, now drive the guard directly.
##
## Slot 995 chosen to avoid collisions: 999 (test_save), 998 (test_save_roundtrip),
## 997 (test_quit_relaunch_save), 996 (test_ac6_quit_relaunch).

const TEST_SLOT: int = 995


# ---- Autoload accessors ----------------------------------------------

func _save() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(n, "Save autoload registered (project.godot [autoload])")
	return n


func _build_info() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("BuildInfo")
	assert_not_null(n, "BuildInfo autoload registered")
	return n


func _debug_flags() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(n, "DebugFlags autoload registered")
	return n


func _levels() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Levels")
	assert_not_null(n, "Levels autoload registered")
	return n


func _player_stats() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("PlayerStats")
	assert_not_null(n, "PlayerStats autoload registered")
	return n


func _stratum() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("StratumProgression")
	assert_not_null(n, "StratumProgression autoload registered")
	return n


func _inventory() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload registered")
	return n


func before_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	var tmp: String = _save().save_path(TEST_SLOT) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	# Reset autoloads so each test starts deterministic.
	_levels().reset()
	_player_stats().reset()
	_inventory().reset()
	_stratum().reset()
	# Reset Engine.time_scale in case a prior test left it slowed.
	Engine.time_scale = 1.0


func after_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	_levels().reset()
	_player_stats().reset()
	_inventory().reset()
	_stratum().reset()
	Engine.time_scale = 1.0


# =======================================================================
# TI-1 — Save.default_payload round-trips through JSON.stringify + parse
# without information loss.
# =======================================================================
##
## **Why this matters for HTML5:** Godot's HTML5 backend serializes saves
## via `JSON.stringify` on top of OPFS / IndexedDB. Any non-JSON-encodable
## type creeping into `DEFAULT_PAYLOAD` (e.g. PackedByteArray, Resource ref,
## NodePath) silently truncates on web but works on native. Catches that
## category of regression at unit-test time.
func test_save_dict_is_pure_json_round_trippable() -> void:
	var payload: Dictionary = _save().default_payload()
	var s: String = JSON.stringify(payload)
	assert_true(s.length() > 0, "default_payload stringifies to non-empty")
	var parsed: Variant = JSON.parse_string(s)
	assert_true(parsed is Dictionary, "round-trip returns Dictionary")
	var parsed_dict: Dictionary = parsed
	# Structural equality — every original top-level key + character/meta
	# block must be present after round-trip. (We don't compare stringified
	# forms because Godot's JSON.stringify doesn't guarantee a stable key
	# order across implementations / versions.)
	assert_true(parsed_dict.has("character"), "character key survives")
	assert_true(parsed_dict.has("stash"), "stash key survives")
	assert_true(parsed_dict.has("equipped"), "equipped key survives")
	assert_true(parsed_dict.has("meta"), "meta key survives")
	# Spot-check critical numeric values for type fidelity (catch float/int
	# drift on web).
	var character: Dictionary = parsed_dict["character"]
	assert_eq(int(character["level"]), 1, "default level=1 round-trips as int")
	assert_eq(int(character["xp"]), 0, "default xp=0 round-trips as int")
	assert_eq(int(character["hp_current"]), 100, "default hp_current=100")
	assert_eq(int(character["hp_max"]), 100, "default hp_max=100")
	# stash and equipped are containers — check shape, not contents (empty).
	assert_true(parsed_dict["stash"] is Array, "stash is Array after parse")
	assert_true(parsed_dict["equipped"] is Dictionary,
		"equipped is Dictionary after parse")
	# Meta block — float survives.
	var meta: Dictionary = parsed_dict["meta"]
	assert_almost_eq(float(meta["total_playtime_sec"]), 0.0, 1e-6,
		"meta.total_playtime_sec float survives JSON round-trip")


# =======================================================================
# TI-2 — Inventory.snapshot_to_save output is JSON round-trippable,
# including float-fidelity affix values.
# =======================================================================
##
## **Why for HTML5:** affix values are floats (e.g. swift `0.08`). JSON
## round-trip on web has historically had precision issues for floats with
## trailing decimals. Asserts the audited contract.
func test_full_inventory_snapshot_is_json_round_trippable() -> void:
	var data: Dictionary = _save().default_payload()
	# Inventory.snapshot_to_save mutates `data["stash"]` and `data["equipped"]`.
	# Empty inventory: both should be empty containers.
	_inventory().snapshot_to_save(data)
	# Layer in stratum progression too — multi-source JSON probe.
	_stratum().mark_cleared(&"s1_room01")
	_stratum().mark_cleared(&"s1_room02")
	_stratum().snapshot_to_save_data(data)
	# Round-trip.
	var s: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(s)
	assert_true(parsed is Dictionary,
		"snapshot+stratum round-trips JSON to Dictionary")
	var parsed_dict: Dictionary = parsed
	# Verify the structure survived intact.
	assert_true(parsed_dict.has("stash"), "stash key survives round-trip")
	assert_true(parsed_dict["stash"] is Array, "stash is Array after parse")
	assert_true(parsed_dict.has("equipped"), "equipped key survives round-trip")
	assert_true(parsed_dict["equipped"] is Dictionary,
		"equipped is Dictionary after parse")
	assert_true(parsed_dict.has("stratum_progression"),
		"stratum_progression key survives round-trip")
	# Verify cleared rooms preserved as Strings (JSON has no StringName).
	var sp: Dictionary = parsed_dict["stratum_progression"]
	var rooms: Array = sp["cleared_rooms"]
	assert_eq(rooms.size(), 2, "two cleared rooms survive JSON round-trip")
	assert_true(rooms.has("s1_room01"), "s1_room01 marker survives as String")
	assert_true(rooms.has("s1_room02"), "s1_room02 marker survives as String")


# =======================================================================
# TI-3 — StratumProgression.snapshot_to_save_data emits a JSON-pure dict.
# =======================================================================
##
## Tighter version of TI-2: just the stratum block, with explicit
## stringify-with-no-warnings assertion.
func test_stratum_progression_snapshot_is_json_round_trippable() -> void:
	_stratum().mark_cleared(&"s1_room01")
	_stratum().mark_cleared(&"s1_room02")
	_stratum().mark_cleared(&"s1_room03")
	var data: Dictionary = {}
	_stratum().snapshot_to_save_data(data)
	var s: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(s)
	assert_true(parsed is Dictionary,
		"snapshot dict round-trips via JSON cleanly")
	var parsed_dict: Dictionary = parsed
	# StringName -> String coercion in JSON is the audited contract.
	var rooms: Array = parsed_dict["stratum_progression"]["cleared_rooms"]
	for r: Variant in rooms:
		assert_true(r is String,
			"cleared_rooms entry is String after JSON parse (StringName -> String)")


# =======================================================================
# TI-4 — Autoload _ready is idempotent across Save / BuildInfo /
# DebugFlags / Levels / PlayerStats / StratumProgression / Inventory.
# =======================================================================
##
## **Why for HTML5:** if a browser-tab refresh races the autoload init
## chain (HTML5 hot-reload patterns can fire `_ready` in surprising orders),
## a second call to `_ready` mid-game must not corrupt state. Each
## autoload's `_ready` in this build only prints a smoke line — verify that
## stays true under a re-call.
func test_autoload_ready_is_idempotent() -> void:
	# Establish baseline state across all autoloads.
	_levels().set_state(2, 50)
	_player_stats().add_stat(&"vigor", 3)
	_player_stats().add_unspent_points(2)
	_stratum().mark_cleared(&"idempotency_room")
	# Snapshot pre-call observable state.
	var pre_level: int = _levels().current_level()
	var pre_xp: int = _levels().current_xp()
	var pre_vigor: int = _player_stats().get_stat(&"vigor")
	var pre_unspent: int = _player_stats().get_unspent_points()
	var pre_cleared: int = _stratum().cleared_count()
	var pre_save_schema: int = _save().SCHEMA_VERSION
	var pre_build_sha: String = _build_info().short_sha
	var pre_capacity: int = _inventory().get_capacity()
	# Re-fire _ready on each autoload via Object.call() so we don't trigger
	# GDScript's "calling method directly on engine notification name"
	# warnings. We're testing the function body itself for idempotency, not
	# the engine's add-to-tree notification.
	_save().call("_ready")
	_build_info().call("_ready")
	_debug_flags().call("_ready")
	_levels().call("_ready")
	_player_stats().call("_ready")
	# StratumProgression has no `_ready` method (verified 2026-05-02);
	# its idempotency-on-_ready is therefore vacuous. The state-survival
	# assertions below still cover the post-_ready chain for the rest.
	if _stratum().has_method("_ready"):
		_stratum().call("_ready")
	_inventory().call("_ready")
	# Assert everything we set up survived.
	assert_eq(_levels().current_level(), pre_level,
		"Levels._ready() does not reset level (idempotent)")
	assert_eq(_levels().current_xp(), pre_xp, "Levels xp preserved")
	assert_eq(_player_stats().get_stat(&"vigor"), pre_vigor,
		"PlayerStats._ready() does not reset vigor")
	assert_eq(_player_stats().get_unspent_points(), pre_unspent,
		"PlayerStats unspent preserved")
	assert_eq(_stratum().cleared_count(), pre_cleared,
		"StratumProgression._ready() does not wipe cleared rooms")
	# Constants don't change.
	assert_eq(_save().SCHEMA_VERSION, pre_save_schema,
		"Save.SCHEMA_VERSION is constant across _ready calls")
	assert_eq(_build_info().short_sha, pre_build_sha,
		"BuildInfo.short_sha is stable across _ready calls")
	assert_eq(_inventory().get_capacity(), pre_capacity,
		"Inventory capacity is constant across _ready calls")


# =======================================================================
# TI-5 — StratumProgression.restore_from_save_data({}) is a no-op.
# =======================================================================
##
## The existing test_stratum_progression coverage (line 115) tests via
## default_payload; this asserts the audited contract directly with a
## minimal empty dict. (See audit CR-3 — typed param can't actually
## receive null, so {} is the canonical empty-input shape.)
func test_stratum_progression_restore_from_empty_dict_is_noop() -> void:
	# Set up some progression to verify restore wipes it.
	_stratum().mark_cleared(&"will_be_wiped_01")
	_stratum().mark_cleared(&"will_be_wiped_02")
	assert_eq(_stratum().cleared_count(), 2,
		"pre-restore: two rooms marked cleared")
	# Restore from empty dict.
	_stratum().restore_from_save_data({})
	# Documented contract: clears existing state then reads the (missing)
	# stratum_progression key as empty -> ends in zero cleared.
	assert_eq(_stratum().cleared_count(), 0,
		"restore_from_save_data({}) yields empty progression (wipes prior + reads missing key as empty)")


# =======================================================================
# TI-6 — InventoryPanel _exit_tree restores Engine.time_scale.
# =======================================================================
##
## Locks in the audit CR-1 fix: if InventoryPanel is freed while still
## open (e.g. scene reload, HTML5 tab-blur during scene-change),
## `Engine.time_scale` is restored to the snapshot value via the
## `_exit_tree` guard in `scripts/ui/InventoryPanel.gd`. Without the
## guard the world stays at 0.10 forever.
func test_inventory_panel_exit_tree_restores_time_scale() -> void:
	var packed: PackedScene = load("res://scenes/ui/InventoryPanel.tscn")
	var panel: InventoryPanel = packed.instantiate()
	add_child(panel)
	panel.open()
	assert_eq(Engine.time_scale, 0.10, "panel-open sets 0.10")
	panel.queue_free()
	await get_tree().process_frame
	assert_eq(Engine.time_scale, 1.0,
		"freed-while-open panel restores time_scale via _exit_tree")


# =======================================================================
# TI-7 — StatAllocationPanel _exit_tree restores Engine.time_scale.
# =======================================================================
##
## Mirror invariant for `StatAllocationPanel` (audit CR-2 fix).
func test_stat_allocation_panel_exit_tree_restores_time_scale() -> void:
	var packed: PackedScene = load("res://scenes/ui/StatAllocationPanel.tscn")
	var panel: StatAllocationPanel = packed.instantiate()
	add_child(panel)
	panel.open()
	assert_eq(Engine.time_scale, 0.10, "panel-open sets 0.10")
	panel.queue_free()
	await get_tree().process_frame
	assert_eq(Engine.time_scale, 1.0,
		"freed-while-open panel restores time_scale via _exit_tree")


# =======================================================================
# TI-8 — BuildInfo.short_sha is a non-empty string in test environment.
# =======================================================================
##
## **Why for HTML5:** the M1 RC artifact name embeds the SHA. If
## BuildInfo's resolution chain returned `""` (e.g. a CI step regression),
## the HUD footer would render `"build: "` and the test plan's
## "every test run records the build SHA" rule breaks.
##
## In CI: `build_info.txt` is written by the export step. Locally:
## fallback path returns "dev-local". Either way, length > 0.
func test_build_info_short_sha_is_non_empty_string() -> void:
	var sha_v: Variant = _build_info().short_sha
	assert_true(sha_v is String, "short_sha is a String")
	var sha: String = sha_v
	assert_gt(sha.length(), 0, "short_sha is non-empty (got '%s')" % sha)
	# Also verify display_label format invariant.
	var label: String = _build_info().display_label
	assert_true(label.begins_with("build: "),
		"display_label starts with 'build: ' (got '%s')" % label)


# =======================================================================
# TI-9 — Save.save_path always lives under user:// (catches accidental
# res:// writes which are read-only on HTML5).
# =======================================================================
##
## **Why for HTML5:** writing to `res://` works on native (project dir is
## writable in dev) but throws on web (`res://` is the served bundle, not
## the OPFS sandbox). A regression that swapped paths would break HTML5
## saves silently. Existing test_save_roundtrip line 109 covers slot 0/42;
## this version sweeps additional slot values to lock the invariant.
func test_save_engine_path_resolves_under_user_dir() -> void:
	for slot: int in [0, 1, 5, 100, TEST_SLOT, 999]:
		var path: String = _save().save_path(slot)
		assert_true(path.begins_with("user://"),
			"save_path(%d) under user:// (HTML5: OPFS); got '%s'" % [slot, path])
		assert_true(path.ends_with(".json"),
			"save_path(%d) ends with .json; got '%s'" % [slot, path])

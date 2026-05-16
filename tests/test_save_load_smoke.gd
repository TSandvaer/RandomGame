extends GutTest
## Save-load no-warning smoke spec — catches the unknown-item-id WARNING
## class surfaced by the Sponsor M2 RC soak (2026-05-15).
##
## **ClickUp: `86c9uerqx`** — "the tester should be able to test what I found."
##
## The Sponsor found `USER WARNING: ItemInstance.from_save_dict: unknown item
## id 'leather_vest'` in the boot console — zero test coverage at the time.
## Fix landed in PR #214 (ticket `86c9uemdg`): leather_vest added to
## `ContentRegistry.STARTER_ITEM_PATHS`. This spec is the long-term safety net:
## any future item added to a loot table but forgotten from STARTER_ITEM_PATHS
## will flip this spec RED before Sponsor soak sees it.
##
## **Three variants (per ticket scope):**
##
##   Variant 1 — SMOKE: default starting save, all known items registered,
##     NO `USER WARNING:` or `USER ERROR:` during the full save → load →
##     ContentRegistry.load_all → Inventory.restore_from_save pipeline.
##     This is the LOAD-BEARING test. If it's red, the Sponsor soak meta-
##     finding would recur silently.
##
##   Variant 2 — MIGRATION: a v2 save dict loaded under the current v3
##     runtime fires the v2→v3 migration path, schema is reported as v3
##     post-load, and the migration produces ZERO warnings via WarningBus.
##     (v4 migration variant deferred — schema v4 not yet landed; see
##     `test_save_v4_stress.gd` scaffolds pending W3-T6.)
##
##   Variant 3 — UNKNOWN-ID GRACEFUL: a save dict with a truly unknown item
##     id ('future_item_from_m3') triggers a WarningBus emission (expected —
##     `expect_warning` opts it out), the load continues without crashing,
##     and `Inventory.get_items()` has zero entries for the bad item (dropped
##     silently). This pins the graceful-degradation contract.
##
## **Why GUT (not Playwright):** GUT gives fast CI signal (~1m20s vs. full
## Playwright release-build cycle) and is deterministic for headless save-load
## logic. The Playwright-side console gate (ticket `86c9uf0mm` Half A, PR #217)
## covers the HTML5 surface independently. The two surfaces are complementary
## per `.claude/docs/test-conventions.md`.
##
## **Peer-review:** Tess-authored — per `tess-cant-self-qa-peer-review`,
## this PR needs Devon as peer reviewer (harness / inventory / engine surface).
##
## **CI status against main (2026-05-16):** Devon's leather_vest fix
## (`86c9uemdg`, PR #214) is merged on main — all three variants run as
## regular `test()` calls, not `test.fail()` stubs.

const TEST_SLOT: int = 995
const FIXTURE_DIR: String = "res://tests/fixtures/"
const FIXTURE_V0: String = "save_v0_pre_migration.json"
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")


# ---- Universal-warning gate (ticket 86c9uf0mm Half B) --------------------
##
## Every test in this file attaches the NoWarningGuard in before_each() and
## asserts zero emissions in after_each(). Tests that DELIBERATELY exercise a
## warning path (Variant 3) opt out precisely with `expect_warning(pattern)`.
## See `tests/test_helpers/no_warning_guard.gd` for the guard contract.

var _warn_guard: NoWarningGuard


func _save() -> Node:
	var s: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(s, "Save autoload must be registered in project.godot")
	return s


func _inv() -> Node:
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(inv, "Inventory autoload must be registered in project.godot")
	return inv


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	# Clean save slot for each test so tests are independent.
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	var tmp: String = _save().save_path(TEST_SLOT) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	_inv().reset()


func after_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	_inv().reset()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# =========================================================================
# VARIANT 1 — SMOKE: full save → load → ContentRegistry → restore_from_save
#   asserts ZERO USER WARNING: / USER ERROR: lines (load-bearing gate)
# =========================================================================

func test_smoke_default_save_load_cycle_emits_no_warnings() -> void:
	## THE LOAD-BEARING TEST. Reproduces the Sponsor soak finding:
	## save a game with a default payload (no unknown items), load it back
	## through the ContentRegistry resolver, restore Inventory — the
	## WarningBus must stay silent throughout.
	##
	## Pre-fix (before PR #214): if leather_vest was in the save dict AND
	## ContentRegistry hadn't direct-loaded it, this would fire:
	##   USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'
	## With the fix on main, this must be silent.

	# Step 1: write a save with only known items (iron_sword + leather_vest
	# — both registered in STARTER_ITEM_PATHS after PR #214).
	var data: Dictionary = _save().default_payload()
	data["equipped"] = {
		"weapon": {
			"id": "iron_sword",
			"tier": 0,
			"rolled_affixes": [],
			"stack_count": 1,
		},
	}
	data["stash"] = [
		{
			"id": "leather_vest",
			"tier": 1,
			"rolled_affixes": [],
			"stack_count": 1,
		},
	]
	var ok: bool = _save().save_game(TEST_SLOT, data)
	assert_true(ok, "save_game with known items must succeed")

	# Step 2: load the save back (migration-through, even if no migration needed).
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "load_game must return non-empty dict for a known-good save")

	# Step 3: build a real ContentRegistry (same path as Main._ready production).
	var registry: ContentRegistry = ContentRegistry.new().load_all()
	assert_true(registry.is_resolved(), "ContentRegistry.is_resolved() must be true after load_all()")

	# Step 4: restore Inventory from the loaded dict — this is the exact code
	# path that pushed_warning in the Sponsor soak. With leather_vest in
	# STARTER_ITEM_PATHS, from_save_dict must resolve it silently.
	_inv().restore_from_save(
		loaded,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	# Structural assertions: the items are actually in inventory (resolver
	# returned non-null — from_save_dict only returns null on miss).
	var equipped_weapon: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped_weapon,
		"SMOKE FAIL: iron_sword must be equipped after restore — if null, resolver returned null "
		+ "and from_save_dict push_warning'd (ticket 86c9uerqx)")
	assert_eq(equipped_weapon.def.id, &"iron_sword", "equipped weapon is iron_sword")
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1,
		"SMOKE FAIL: stash must contain one item (leather_vest) after restore — "
		+ "if zero, resolver returned null and from_save_dict push_warning'd")
	var vest: ItemInstance = items[0] as ItemInstance
	assert_not_null(vest.def, "leather_vest has non-null def (resolver did not return null)")
	assert_eq(vest.def.id, &"leather_vest",
		"REGRESSION GUARD (86c9uemdg): leather_vest must resolve via ContentRegistry.STARTER_ITEM_PATHS. "
		+ "If this fails, the item was removed from STARTER_ITEM_PATHS or leather_vest.tres was moved.")
	# NoWarningGuard asserts zero emissions in after_each() — no explicit
	# guard call needed here; the gate fires on any WarningBus emission
	# that was not opt-ed-out via expect_warning().


func test_smoke_empty_stash_save_load_emits_no_warnings() -> void:
	## Simpler smoke variant: a fresh new-game save (no items) must be silent.
	## This pins the baseline so we can distinguish "registry problem" from
	## "item-resolver problem" when investigating a future failure.
	var ok: bool = _save().save_game(TEST_SLOT)
	assert_true(ok, "save_game with default payload must succeed")
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "load_game of a fresh save must return non-empty dict")
	# An empty-inventory save doesn't exercise the item resolver, so
	# ContentRegistry and Inventory.restore_from_save are not called here.
	# This is intentional: if the smoke test above fails but this one passes,
	# the fault is in the item-resolver chain, not in Save itself.
	assert_eq(loaded["character"]["level"], 1, "fresh character level=1 round-trips")
	assert_eq(loaded["meta"]["deepest_stratum"], 1, "default deepest_stratum=1 round-trips")


func test_smoke_both_starter_items_registered_in_content_registry() -> void:
	## Drift detector: asserts that BOTH save-critical items are in
	## ContentRegistry.STARTER_ITEM_PATHS at the same time. If someone removes
	## one (thinking DirAccess covers it) this pinpoints the omission before
	## a soak test finds it.
	##
	## REGRESSION GUARD (86c9uemdg): if this assertion fires, check that the
	## item is still in `resources/loot_tables/*.tres` entries AND that the
	## STARTER_ITEM_PATHS list is up-to-date. Any item that can appear in a
	## player's save must be direct-loaded here.
	assert_true(
		ContentRegistry.STARTER_ITEM_PATHS.has("res://resources/items/weapons/iron_sword.tres"),
		"STARTER_ITEM_PATHS must list iron_sword.tres (ticket 86c9qah1f)")
	assert_true(
		ContentRegistry.STARTER_ITEM_PATHS.has("res://resources/items/armors/leather_vest.tres"),
		"STARTER_ITEM_PATHS must list leather_vest.tres (ticket 86c9uemdg)")


# =========================================================================
# VARIANT 2 — MIGRATION: v0 save → migrate to current schema → zero warnings
# =========================================================================
## The "v3 save → v4 migration" variant from the ticket is DEFERRED —
## schema v4 is not yet on main (see `test_save_v4_stress.gd` which is
## all-pending, awaiting W3-T6). The live migration variant here is v0→v3,
## which exercises the FULL migration chain (_migrate_v0_to_v1 →
## _migrate_v1_to_v2 → _migrate_v2_to_v3) and verifies it is warning-clean.
##
## Once v4 lands (W3-T6), add test_v3_to_v4_migration_no_warnings() here.

func test_migration_v0_to_current_schema_emits_no_warnings() -> void:
	## A v0 fixture (no schema_version) migrates cleanly to the current
	## schema (v3 as of 2026-05-02) without firing any WarningBus emissions.
	## The only warnings the migration path emits are for "schema newer than
	## runtime" (an intentional future-save safety net) — v0 is OLDER than
	## runtime, so that path never triggers here.

	# Install the v0 fixture verbatim at the test slot.
	var raw: String = _read_fixture(FIXTURE_V0)
	var path: String = _save().save_path(TEST_SLOT)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(raw)
	f.close()

	# load_game triggers the full migration chain.
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "v0 fixture must load without returning {}")

	# Verify migration landed at v3 fields (structural migration smoke).
	assert_true(loaded.has("meta"), "migration added 'meta' block (v0→v1)")
	assert_true(loaded["character"].has("xp_to_next"), "migration added 'xp_to_next' (v1→v2)")
	assert_true(loaded["character"].has("stats"), "migration added 'stats' block (v2→v3)")
	assert_true(loaded["character"].has("unspent_stat_points"), "migration added 'unspent_stat_points' (v2→v3)")

	# Schema post-migration — the in-memory data is at the current schema.
	# Confirm by saving back and reading the envelope.
	_save().save_game(TEST_SLOT, loaded)
	var f2: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw2: String = f2.get_as_text()
	f2.close()
	var envelope: Dictionary = JSON.parse_string(raw2)
	assert_eq(int(envelope["schema_version"]), 3,
		"on-disk envelope is v3 after migration + resave (MIGRATION VARIANT: "
		+ "schema_version on disk must equal current SCHEMA_VERSION=3, not 0)")

	# NoWarningGuard asserts zero emissions in after_each().


func test_migration_v0_with_items_restores_cleanly_no_warnings() -> void:
	## Migration variant: the v0 fixture includes stash items (iron_sword +
	## armor_leather per the fixture definition). After migration + restore_from_save
	## with a real ContentRegistry, the items must be present and no warnings
	## must fire during the resolver chain.

	var raw: String = _read_fixture(FIXTURE_V0)
	var path: String = _save().save_path(TEST_SLOT)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(raw)
	f.close()

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "v0 fixture with items must load")

	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		loaded,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	# The v0 fixture has iron_sword + armor_leather in stash. Both must be
	# in STARTER_ITEM_PATHS (armor_leather is the v1-era name for the armor
	# item). If armor_leather is NOT in STARTER_ITEM_PATHS but IS in the
	# fixture, this test should catch the gap via NoWarningGuard's after_each
	# assertion OR via the item count below.
	#
	# Note: armor_leather (the v0 fixture item) may not match the runtime
	# asset (leather_vest). If the item id doesn't resolve, from_save_dict
	# returns null and the stash entry is dropped — that IS a warning. The
	# test is intentionally load-bearing: a mismatch between fixture ids and
	# registry ids surfaces here, not in Sponsor soak.
	var items: Array = _inv().get_items()
	assert_gte(items.size(), 1,
		"MIGRATION VARIANT: at least one stash item from the v0 fixture must resolve "
		+ "via ContentRegistry. If zero, check that the fixture's item ids match the "
		+ "current STARTER_ITEM_PATHS (see ContentRegistry.STARTER_ITEM_PATHS).")
	# NoWarningGuard asserts zero emissions for resolved items in after_each().
	# If armor_leather is unknown, the guard will also catch the warning — both
	# the count assertion and the guard work together.


# =========================================================================
# VARIANT 3 — UNKNOWN-ID GRACEFUL: warning fires (expected), no crash,
#   Inventory drops the entry
# =========================================================================

func test_unknown_item_id_emits_expected_warning_and_drops_entry() -> void:
	## A save dict with an item id that doesn't exist in the registry must:
	##   (a) Emit exactly one `USER WARNING:` via WarningBus (the unknown-id
	##       warning from ItemInstance.from_save_dict).
	##   (b) NOT crash (restore_from_save returns cleanly).
	##   (c) The Inventory has ZERO items (the bad entry was dropped, not
	##       silently accepted as a null-def ItemInstance).
	##
	## The `expect_warning` call opts THIS specific warning out of the gate.
	## The gate still fires on any OTHER unexpected WarningBus emissions.
	_warn_guard.expect_warning("unknown item id 'future_item_from_m3'")

	var save_data: Dictionary = {
		"equipped": {},
		"stash": [
			{
				"id": "future_item_from_m3",
				"tier": 1,
				"rolled_affixes": [],
				"stack_count": 1,
			},
		],
	}

	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	# The entry must be DROPPED — no null-def ItemInstance lands in inventory.
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 0,
		"UNKNOWN-ID GRACEFUL: Inventory must have zero items after restore with unknown id — "
		+ "a null-def ItemInstance in the inventory would crash downstream UI code. "
		+ "The entry must be silently dropped per ItemInstance.from_save_dict contract.")

	# Verify exactly one warning was captured (the one we expect_warning'd for).
	# assert_clean() in after_each() will verify no extra unexpected warnings.
	assert_eq(_warn_guard.captured_count(), 1,
		"UNKNOWN-ID GRACEFUL: exactly one WarningBus emission must fire for the unknown id "
		+ "(the expect_warning opt-out consumes it). If zero, the warning path is broken — "
		+ "the contract of from_save_dict is to WARN on unknown ids so future regressions "
		+ "are visible in CI, not silently hidden.")


func test_unknown_item_id_with_known_items_present_drops_only_bad_entry() -> void:
	## Edge probe: a save with one known item + one unknown item must:
	##   - Drop the unknown item (with warning).
	##   - Keep the known item (no warning).
	## This pins the "only bad entries are dropped" invariant — a regression
	## where the whole restore fails on the first unknown id would also lose
	## all subsequent good items.
	_warn_guard.expect_warning("unknown item id 'not_a_real_item'")

	var save_data: Dictionary = {
		"equipped": {},
		"stash": [
			{
				"id": "iron_sword",
				"tier": 0,
				"rolled_affixes": [],
				"stack_count": 1,
			},
			{
				"id": "not_a_real_item",
				"tier": 1,
				"rolled_affixes": [],
				"stack_count": 1,
			},
		],
	}

	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	# Only the known item must survive.
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1,
		"UNKNOWN-ID GRACEFUL: only the unknown item must be dropped; the known item (iron_sword) "
		+ "must survive. If zero items, restore_from_save aborted early on the unknown id.")
	var surviving: ItemInstance = items[0] as ItemInstance
	assert_not_null(surviving.def, "surviving item has non-null def")
	assert_eq(surviving.def.id, &"iron_sword",
		"surviving item is iron_sword (the known entry comes before the unknown one in stash[])")


func test_unknown_affix_id_emits_expected_warning_drops_only_affix() -> void:
	## Edge probe: a known item with an unknown affix id must:
	##   - Emit a warning for the unknown affix.
	##   - Still produce a valid ItemInstance for the item (def non-null).
	##   - Drop only the unresolvable affix roll (not the whole item).
	##
	## This is the affix-id variant of the unknown-id graceful contract.
	_warn_guard.expect_warning("unknown affix id 'future_affix_x' on item 'iron_sword'")

	var save_data: Dictionary = {
		"equipped": {},
		"stash": [
			{
				"id": "iron_sword",
				"tier": 0,
				"rolled_affixes": [
					{"affix_id": "future_affix_x", "value": 0.99},
					{"affix_id": "swift", "value": 0.08},
				],
				"stack_count": 1,
			},
		],
	}

	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1, "iron_sword still lands in inventory despite unknown affix")
	var inst: ItemInstance = items[0] as ItemInstance
	assert_not_null(inst.def, "item def is non-null (unknown affix didn't kill the item)")
	assert_eq(inst.def.id, &"iron_sword", "iron_sword survived with the unknown affix dropped")
	# The known 'swift' affix must survive; the unknown 'future_affix_x' must be dropped.
	assert_eq(inst.rolled_affixes.size(), 1,
		"only the known affix (swift) survives; unknown affix is dropped per from_save_dict contract")
	assert_eq(inst.rolled_affixes[0].def.id, &"swift", "swift affix present in restored item")


# =========================================================================
# GATE: no-warning posture of the full pipeline (integration smoke)
# =========================================================================

func test_full_pipeline_iron_sword_leather_vest_equipped_stash_no_warnings() -> void:
	## Integration-level catch-all: the exact save shape Sponsor would have
	## at the end of a successful M2 boss run. One weapon equipped, one armor
	## in stash, level progressed. Must be COMPLETELY silent — no USER WARNING:,
	## no USER ERROR:.
	##
	## If this is the ONLY failing test, check: was a new loot-table item
	## added to resources/loot_tables/*.tres but NOT listed in
	## ContentRegistry.STARTER_ITEM_PATHS? That's the exact failure mode this
	## spec exists to surface.

	var data: Dictionary = _save().default_payload()
	data["character"]["level"] = 3
	data["character"]["xp"] = 750
	data["character"]["stats"] = {"vigor": 1, "focus": 0, "edge": 1}
	data["character"]["unspent_stat_points"] = 0
	data["meta"]["deepest_stratum"] = 2
	data["meta"]["runs_completed"] = 3
	data["equipped"] = {
		"weapon": {
			"id": "iron_sword",
			"tier": 1,
			"rolled_affixes": [{"affix_id": "swift", "value": 0.09}],
			"stack_count": 1,
		},
	}
	data["stash"] = [
		{
			"id": "leather_vest",
			"tier": 1,
			"rolled_affixes": [{"affix_id": "vital", "value": 10}],
			"stack_count": 1,
		},
	]

	assert_true(_save().save_game(TEST_SLOT, data), "save_game must succeed")
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "load_game must return the saved dict")

	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		loaded,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	# Structural verifications — all items resolved (resolver returned non-null).
	var weapon: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(weapon, "iron_sword equipped slot populated post-restore")
	assert_eq(weapon.def.id, &"iron_sword", "equipped weapon is iron_sword")
	assert_eq(weapon.rolled_affixes.size(), 1, "swift affix survives round-trip")

	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1, "leather_vest in stash survives round-trip")
	assert_eq((items[0] as ItemInstance).def.id, &"leather_vest",
		"stash item is leather_vest (REGRESSION GUARD: if unknown, leather_vest was removed "
		+ "from STARTER_ITEM_PATHS or the .tres was moved — ticket 86c9uemdg)")

	assert_eq(loaded["character"]["level"], 3, "character level survives round-trip")
	assert_eq(loaded["meta"]["deepest_stratum"], 2, "meta deepest_stratum survives round-trip")


# =========================================================================
# Internal helpers
# =========================================================================

func _read_fixture(name: String) -> String:
	var path: String = FIXTURE_DIR + name
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "fixture %s must exist at %s" % [name, path])
	var raw: String = f.get_as_text()
	f.close()
	return raw

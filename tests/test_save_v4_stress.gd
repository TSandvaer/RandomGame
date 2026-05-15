extends GutTest
## Stress tests for save schema v4 — paired with W3-T6
## (`feat(save): schema v4 stress test fixtures + HTML5 OPFS round-trip`)
## which authors 8 stress-fixture JSON files under `tests/fixtures/v4/`
## covering INV-1..INV-8 from `team/devon-dev/save-schema-v4-plan.md §5`.
##
## **Scaffold-only**: This file ships with `pending()` stubs that compile so
## CI's GUT step doesn't trip on parse errors. Tess + Devon co-fill these
## stubs once W3-T6 lands the fixture JSONs. Tess owns the fixture authoring;
## Devon assists on OPFS-specific edge cases. Mirrors the W1-T12 / W2-T10
## parallel-acceptance pattern.
##
## See `team/tess-qa/m2-acceptance-plan-week-3.md` § W3-T6 for the
## acceptance criteria this file pins (W3-T6-AC1..AC8).
##
## Sibling pattern: `tests/test_save_migration.gd` (existing on `main`).
## The W3-T6 fixtures stress eight specific shapes that the existing test
## doesn't cover (max stash, multi-stratum bags, corruption recovery,
## OPFS round-trip baseline + max, idempotent double-migration, unknown-
## keys passthrough).


# ---- W3-T6-AC1 — save_v4_full_stash_72_slots.json ------------------

func test_full_stash_72_slots_loads_clean_under_v4_runtime() -> void:
	pending("awaiting W3-T6 — tests/fixtures/v4/save_v4_full_stash_72_slots.json + load assertion")


func test_full_stash_72_slots_round_trip_bit_identical() -> void:
	pending("awaiting W3-T6 — load + save + load = bit-identical for 72-slot stash fixture")


# ---- W3-T6-AC2 — save_v4_three_stratum_bags.json -------------------

func test_three_stratum_bags_load_independently() -> void:
	## ST-21 cross-stratum independence — pin via this fixture: ember_bags
	## populated for stratum 1, 2, 3 simultaneously; each bag's items load
	## independently without inter-stratum bleed.
	pending("awaiting W3-T6 — tests/fixtures/v4/save_v4_three_stratum_bags.json loads all 3 bags")


func test_three_stratum_bags_cap_at_8_entries() -> void:
	pending("awaiting W3-T6 — bag cap = 8 entries (one per stratum) per stash-ui-v1.md")


# ---- W3-T6-AC3 — save_v4_partial_corruption_recovery.json ----------

func test_partial_corruption_emits_push_warning_drops_entry() -> void:
	pending("awaiting W3-T6 — corrupted item entry (unknown id) drops with push_warning")


func test_partial_corruption_rest_of_save_loads_clean() -> void:
	pending("awaiting W3-T6 — corruption-recovery save: rest of state survives the drop")


# ---- W3-T6-AC4 — save_v4_max_level_capped_full_inventory.json -----

func test_max_level_full_inventory_full_stash_full_bags_round_trip() -> void:
	pending("awaiting W3-T6 — maximal save round-trips bit-identical (TI-15 size budget hit)")


func test_max_level_save_size_under_100kb() -> void:
	## TI-15 size budget — save-schema-v4-plan.md §7.2 sets an upper bound.
	pending("awaiting W3-T6 — fully-populated v4 save serializes to under 100 KB")


# ---- W3-T6-AC5 — save_v4_html5_opfs_baseline.json ------------------

func test_opfs_baseline_fixture_valid_v4_envelope() -> void:
	pending("awaiting W3-T6 — minimal v4 envelope valid as OPFS round-trip baseline")


# ---- W3-T6-AC6 — save_v4_html5_opfs_max.json -----------------------

func test_opfs_max_fixture_valid_v4_envelope() -> void:
	pending("awaiting W3-T6 — maximal v4 envelope valid for OPFS stress testing")


func test_opfs_round_trip_documented_as_sponsor_probe() -> void:
	## Per W3-T6 risk note: if headless-browser GUT runner doesn't exist
	## yet, OPFS round-trip is documented as a Sponsor-soak probe target
	## (W3 acceptance plan §Sponsor probe targets) rather than gated on
	## new infra build. This test is a placeholder asserting the doc-or-
	## test flag is set somewhere visible.
	pending("awaiting W3-T6 — OPFS test or doc gate (Sponsor probe fallback per W3-T6 risk note)")


# ---- W3-T6-AC7 — save_v4_idempotent_double_migration.json ---------

func test_idempotent_double_migration_is_no_op() -> void:
	## INV-7 from save-schema-v4-plan.md §5 — re-running migration on
	## already-v4 data is a bit-identical no-op.
	pending("awaiting W3-T6 — _migrate(data, 4) twice on already-v4 data: bit-identical no-op")


# ---- W3-T6-AC8 — save_v4_unknown_keys_passthrough.json ------------

func test_unknown_keys_preserved_through_round_trip() -> void:
	## Forward-compat: extra unknown keys are preserved (not silently
	## dropped) so future M3 fields don't disappear on a v4 round-trip.
	pending("awaiting W3-T6 — unknown keys survive load → save → load round-trip")


# ---- INV-1..INV-8 cross-check (pin via the 8 fixtures collectively) -

func test_inv1_v3_to_v4_load_clean() -> void:
	pending("awaiting W3-T6 — INV-1 via the v3-baseline-loaded-under-v4 path (re-use existing fixture)")


func test_inv2_empty_stash_backfill_via_fixture() -> void:
	pending("awaiting W3-T6 — INV-2 via fixture variant (empty-stash backfill on v3 → v4)")


func test_inv3_empty_bags_backfill_via_fixture() -> void:
	pending("awaiting W3-T6 — INV-3 via fixture variant (empty-bags backfill on v3 → v4)")


func test_inv4_stash_ui_state_backfill_via_fixture() -> void:
	pending("awaiting W3-T6 — INV-4 via fixture variant (stash_ui_state.stash_room_seen = false)")


func test_inv5_v3_field_preservation_via_max_fixture() -> void:
	pending("awaiting W3-T6 — INV-5 via max-fixture round-trip (every v3 field bit-identical)")


func test_inv6_v0_to_v4_chain_through_full_history_via_fixture() -> void:
	pending("awaiting W3-T6 — INV-6 via the chain-migration fixture path")


func test_inv7_v4_idempotence_via_double_migration_fixture() -> void:
	## Same as AC7 above — INV-7 surfaces here as a cross-named test for
	## the invariant naming alignment with save-schema-v4-plan.md §5.
	pending("awaiting W3-T6 — INV-7 via save_v4_idempotent_double_migration.json")


func test_inv8_v4_envelope_schema_version_on_disk() -> void:
	pending("awaiting W3-T6 — INV-8 schema_version field = 4 on disk after any save_game()")

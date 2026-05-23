# feat(save): per-character world_seed v5-canonical promotion + migration (W2-T4)

**Ticket:** [`86c9y108t`](https://app.clickup.com/t/86c9y108t) — W2-T4
**Precursor:** PR #328 (procgen spike Part B, ticket `86c9xub9p`) — landed `world_seed` as a v4-additive field with `0` sentinel back-fill for legacy v3/v4 saves.
**Source of truth:** `team/devon-dev/save-schema-v5-plan.md` + `team/devon-dev/save-schema-v5-tier3-additions.md §5.1` (sentinel re-roll recommendation).

## Summary

Bumps `Save.SCHEMA_VERSION` from 4 to 5 and adds `_migrate_v4_to_v5` to promote `character.world_seed` from the v4-additive layer (sentinel `0` back-fill, immutable) to the v5-canonical layer (one-time re-roll of the sentinel on first v5 load, then immutable). Every loaded character now has a non-zero `world_seed` regardless of when their save was first written, satisfying the Diablo-shape per-character-variance promise (memory `m3-diablo-shape-directive`).

**Important:** this PR is the **`world_seed` canonical promotion ONLY**. The v5 multi-character lift catalogued in `save-schema-v5-plan.md` (`data.character` → `data.characters[]`, equipped lift, shared_stash lift, `active_slot`) remains paper-only and lands in a separate downstream ticket. The two promotions co-exist on schema v5 additively.

## Migration shape

```
_migrate_v4_to_v5(data):
    character = data["character"]   # defensive backfill if missing
    seed_value = int(character.get("world_seed", 0))
    if seed_value == 0:
        character["world_seed"] = randi()   # one-time re-roll of sentinel
    return data
```

Wired into the chain after `_migrate_v3_to_v4`:

```
if from_version < 5:
    out = _migrate_v4_to_v5(out)
```

The migration is **idempotent on already-v5 data** (the `if from_version < 5` guard short-circuits), and **idempotent on v4 saves with a non-zero seed** (the inner `if seed_value == 0` guard fails). The re-roll fires exactly once per legacy character.

## Backfill semantics

| Save source state | `_migrate_v3_to_v4` | `_migrate_v4_to_v5` | End state |
|---|---|---|---|
| v0..v3 (no `world_seed` key) | Backfills `world_seed = 0` | Sees `0`, re-rolls to `randi()` | Non-zero seed |
| v4 with `world_seed = 0` (legacy spike-era backfill) | (skipped, `from_version >= 4`) | Sees `0`, re-rolls to `randi()` | Non-zero seed |
| v4 with `world_seed != 0` (already-rolled on v4 build) | (skipped) | No-op (guard fails) | Preserved bit-identical |
| v5 native (any seed value) | (skipped) | (skipped, `from_version >= 5`) | Preserved bit-identical |

## Acceptance walkthrough

- **GUT in `tests/test_save.gd`** — 5 new tests:
  - `test_migrate_v4_save_with_zero_sentinel_rerolls_world_seed` — v4 `world_seed=0` → re-rolled to non-zero.
  - `test_migrate_v4_save_with_nonzero_seed_preserves_world_seed` — v4 `world_seed=0xCAFEBABE` → preserved (immutability post-roll).
  - `test_migrate_v5_save_is_idempotent_on_world_seed` — v5 native save round-trips bit-identical; double-trip preserves seed (no spurious second re-roll).
  - `test_migrate_v3_save_chains_through_to_v5_with_nonzero_seed` — full chain v3 → v4 → v5 ends with non-zero seed + all intermediate fields present.
  - `test_two_consecutive_v4_migrations_roll_different_world_seeds` — two independent v4 sentinels re-roll to DIFFERENT non-zero seeds (Diablo-shape per-character-variance canary; catches RNG-determinism regression that would silently kill the variance promise).
- **GUT in `tests/test_world_seed_persists_across_save_load.gd`** — 7 existing spike pins lift to v5-canonical:
  - The end-to-end pin `test_world_seed_drives_identical_assemble_across_save_load` lifts cleanly — uses `default_payload()` which already rolls a non-zero seed; the assemble-equality property holds across the round-trip regardless of v4 or v5 chain.
  - `test_v3_migration_backfills_world_seed_to_zero_sentinel` renamed → `test_v3_migration_rerolls_world_seed_via_v5_canonical_promotion` — inverts the contract from "stays at 0" to "re-rolled to non-zero." Same fixture, opposite assertion.
  - `test_v3_migration_preserves_non_default_character_fields` — updated to assert `world_seed != 0` (v5 chain re-rolls).
- **GUT in `tests/test_save_migration.gd`** — 3 updates:
  - `test_save_migrated_v0_then_reload_round_trips` — on-disk envelope assertion bumped from `schema_version=4` → `=5`.
  - `test_v3_migration_chains_through_to_v4` — extended with v3 → v4 → v5 chain step (re-roll assertion + on-disk schema bumped to 5).
  - `test_v0_migration_chains_through_to_v4` → renamed `test_v0_migration_chains_through_to_v5` — extended with v4 → v5 re-roll assertion.
  - `test_v4_migration_is_idempotent` — veteran fixture now includes a non-zero `world_seed` (`0xFEEDFACE`); asserts v4 → v5 step preserves the field (already-rolled immutability).
- **GUT in `tests/test_save_load_smoke.gd`** — Variant 2 (migration) assertion bumped from v4 to v5; adds `world_seed` re-roll assertion to verify warning-clean chain.
- **GUT in `tests/test_first_boss_kill_skip.gd`** — `test_migration_chain_v0_to_v4_idempotent` → renamed `test_migration_chain_v0_to_v5_idempotent`; extended with `world_seed` re-roll + immutability-on-already-v5 assertions.
- **Survey doc footnote (Part D)** — `team/devon-dev/save-schema-v5-tier3-additions.md` survey § header now footnotes that Save.gd HEAD was v4 at survey authorship time, plus what the W2-T4 bump does and does NOT cover (per Drew nit 3 from PR #320 review).

## Non-obvious findings

1. **The `_migrate_v3_to_v4` sentinel back-fill is now dead-code-adjacent for the procgen pipeline.** Any chain that runs v3→v4 also runs v4→v5 in the same `migrate()` call, so callers never observe the `world_seed == 0` state. The back-fill remains because it (a) keeps the v3→v4 step idempotent in isolation (e.g. if a future hand-test calls it directly), and (b) means the v4→v5 logic doesn't need to know which version "introduced" the field. **Future-author hint:** if v6 ever wants to remove the v3→v4 back-fill, the v4→v5 re-roll step still has to remain — it's the load-bearing contract that no character ever loads with `world_seed == 0`.
2. **`test_v4_migration_is_idempotent` semantics broadened.** Previously the fixture had no `world_seed` key (predating the field). Under v5 chain, that absence means v4→v5 treats it as a sentinel and re-rolls — breaking the test's "no-op" framing. Mitigated by adding `world_seed: 0xFEEDFACE` to the veteran fixture so the v4→v5 step has nothing to re-roll. The "no-op" property is now empirically verified on `first_boss_kill_seen=true` AND `world_seed=non-zero` together, rather than only on first_boss_kill_seen alone.
3. **The migration uses `randi()` directly with no test-mode determinism hook.** Mirrors `default_payload()`'s pattern (which also uses raw `randi()`). The `test_two_consecutive_v4_migrations_roll_different_world_seeds` test is the canary for RNG-determinism regression — if Godot 4.3 ever auto-seeds `randi()` deterministically in CI, this test fails first. Acceptable trade-off; if a future ticket wants a deterministic-test-mode seed, that's its own decision-surface.

## Cross-lane integration check

This PR touches the **save lane** only. Adjacent surfaces:

- **Procgen lane (W2-T3)** — `FloorAssembler.derive_zone_seed(world_seed, ...)` consumes `character.world_seed`. The contract here (always non-zero post-load) is the precondition that W2-T3's `assemble_floor` callers depend on. PR #328 already wired the consumption shape; this PR ensures the value is never the boring `0` sentinel.
- **Inventory lane** — `Inventory.restore_from_save` reads `data.equipped` + stash; this PR doesn't touch either, but the v5 chain does run on every load. The chain is warning-clean per `test_save_load_smoke.gd` Variant 2; if any inventory-side surface fires a warning during the v4→v5 step, the universal-warning gate catches it.
- **Combat / hitbox lane** — untouched. No Area2D mutations.
- **Audio lane** — untouched.
- **HTML5 visual surface** — untouched. Save is server-side only.

## Regression guard

If any future refactor:
- **drops `world_seed` from the save schema** — `test_default_payload_rolls_non_zero_world_seed` + `test_world_seed_persists_through_save_load_round_trip` both fail (catches drop via `has("world_seed")` + value assertions).
- **fails to re-roll the v4 sentinel** — `test_migrate_v4_save_with_zero_sentinel_rerolls_world_seed` + `test_migrate_v3_save_chains_through_to_v5_with_nonzero_seed` + the renamed `test_v3_migration_rerolls_world_seed_via_v5_canonical_promotion` all fail (catches missing v4→v5 wiring or guard-condition inversion).
- **re-rolls an already-rolled seed** — `test_migrate_v4_save_with_nonzero_seed_preserves_world_seed` + `test_migrate_v5_save_is_idempotent_on_world_seed` both fail (catches "always re-roll" regression).
- **silently uses a deterministic RNG seed** — `test_two_consecutive_v4_migrations_roll_different_world_seeds` fails (catches the Diablo-shape variance canary).
- **breaks the chain order** — `test_v0_migration_chains_through_to_v5` + `test_migration_v0_to_current_schema_emits_no_warnings` both fail (full-chain stress).

## HTML5 visual-verification

**N/A — save-schema PR.** No tween, no modulate, no Polygon2D, no CPUParticles2D, no Area2D state mutation. Pure JSON read/write + RNG.

Per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate", the gate does not apply to this PR class. Per `html5-visual-gated-author-self-soak` memory, the author-self-soak requirement also does not apply (no UI-visible surface — the only HTML5-observable change is the boot line `[Save] autoload ready (schema v5)` instead of `(schema v4)`).

## Out-of-scope (explicitly)

- Full v5 multi-character lift (`data.character` → `data.characters[]`, equipped lift, shared_stash lift, `active_slot`) — paper-only at W2-T4 time per `save-schema-v5-plan.md`; lands in a separate downstream ticket.
- Quest state save fields (W2-T6).
- World-map UI save fields (W2-T5).
- `FloorAssembler` consumption side — that's W2-T3; this PR is the WRITE side only.

## Cross-references

- `team/devon-dev/save-schema-v5-plan.md` — additive-only doctrine source.
- `team/devon-dev/save-schema-v5-tier3-additions.md` — Part D footnote target + §5.1 sentinel-re-roll recommendation that drives the migration behaviour.
- `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1 (Drew nit routing) + v1.3 §B (W2 ticket-shape verdict).
- PR #328 (`86c9xub9p`) — v4-additive precursor.
- `.claude/docs/procgen-pipeline.md` § "Save-schema binding" — downstream consumer contract.

## Doc updates

`team/devon-dev/save-schema-v5-tier3-additions.md` — Part D survey § header footnote per Drew nit 3 routing. No `.claude/docs/` files updated this PR (architectural docs unchanged; the v5 schema impl details live in `scripts/save/Save.gd` source comments + `team/devon-dev/save-schema-v5-plan.md`).

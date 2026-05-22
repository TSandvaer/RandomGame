# Self-Test Report — PR #312 (zone-schema spike, M3-T3-W1 `86c9xuap4`)

## Verdict

Ready for QA. Pure paper-design + data layer; **no HTML5 surface, no Tween/modulate/Polygon2D/CPUParticles2D/Area2D-state touched** → `html5-visual-verification-gate` does not apply per its scope clause ("no UX-visible surface"). GUT pinning + CI green is the sufficient evidence shape for this PR class.

## What changed (artifact surface)

- **2 new GDScript classes** (Resources, not nodes): `resources/level/ZoneDef.gd`, `resources/level/ZoneAnchor.gd`. Neither is registered as autoload; nothing instantiates them at boot.
- **1 worked-example `.tres`**: `resources/level/zones/s1_z1_outer_cloister.tres`. Not yet referenced by Main.tscn or any scene — pure spike artifact.
- **1 doc extension**: `team/drew-dev/level-chunks.md` — new `## Zone schema` section (6 sub-sections, ~280 lines).
- **1 new test file**: `tests/test_zone_def.gd` (23 tests).

## CI results

- **Headless import + GUT** — pass (1m50s). 1558 tests / 1478 passing / 0 failing / 80 pre-existing risky-or-pending.
- **Export HTML5** — pass (1m12s). Build artifact `embergrave-html5-f51dbbc.zip` exported clean. The new Resource scripts + `.tres` import without errors under the headless build (which is the gate that catches malformed `.tres` files; e.g. a typo in `script_class` would fail import).
- **Playwright E2E** — pending at time of writing this comment; will update if anything surfaces. The Playwright suite exercises HTML5 runtime behavior; this PR adds no runtime code path so I do not expect any deltas.

## New tests added (`tests/test_zone_def.gd`, 23 tests)

All 23 ran + passed in CI. Inventory:

**ZoneAnchor shape (5 tests):**
- `test_anchor_known_kinds_round_trip` — every kind in `ZoneAnchor.KINDS` round-trips; unknown rejected.
- `test_anchor_validate_passes_on_well_formed`
- `test_anchor_validate_catches_empty_room_id`
- `test_anchor_validate_catches_empty_chunk_id`
- `test_anchor_validate_catches_unknown_kind`
- `test_anchor_validate_catches_target_zone_on_non_exit` — `target_zone_id` on (e.g.) `npc_room` is a typo trap; explicit error.

**ZoneDef shape (9 tests):**
- `test_zone_validate_passes_on_well_formed`
- `test_zone_validate_catches_empty_zone_id`
- `test_zone_validate_catches_empty_display_name`
- `test_zone_validate_catches_out_of_range_stratum`
- `test_zone_validate_requires_exactly_one_entry_anchor` — two entries + zero entries both fail
- `test_zone_validate_requires_at_least_one_exit_anchor`
- `test_zone_validate_catches_duplicate_room_id`
- `test_zone_validate_catches_exit_self_loop`
- `test_zone_validate_catches_slot_range_inversion`
- `test_zone_validate_catches_empty_pool_when_max_nonzero`
- `test_zone_validate_accepts_empty_pool_when_max_zero` — all-hand-authored zone is legal

**ZoneDef helpers (3 tests):**
- `test_zone_get_anchors_of_kind_filters`
- `test_zone_get_entry_anchor_returns_first_entry`
- `test_zone_has_anchor_finds_by_room_id`

**Worked-example `s1_z1_outer_cloister.tres` round-trip (6 tests):**
- `test_authored_s1_z1_outer_cloister_loads` — `load(...)` returns non-null cast to `ZoneDef`, fields read.
- `test_authored_s1_z1_outer_cloister_validates` — `validate().is_empty()`.
- `test_authored_s1_z1_outer_cloister_has_five_anchors` — 5 anchors, one of each non-`story_beat` kind.
- `test_authored_s1_z1_outer_cloister_anchor_chunks_resolve` — all 5 anchor `chunk_id`s `load()` to real `LevelChunkDef.tres` under `resources/level_chunks/`. Catches typos in worked example.
- `test_authored_s1_z1_outer_cloister_pool_chunks_resolve` — all 4 `procedural_slot_pool` chunk_ids resolve too.
- `test_authored_s1_z1_outer_cloister_exit_targets_s2` — exit anchor's `target_zone_id` is `&"s2_z1_sunken_entrance"` (cross-zone transition documented).

## Cross-lane integration check

Per the standard cross-lane checklist for combat / level / harness PRs:

- **`[combat-trace]` contract** — N/A; zero combat code touched.
- **Player iframes / damage formula constants** — N/A; not touched.
- **`Mob.pos` staleness contract** — N/A; no mob code touched.
- **RoomGate signal chain** — N/A; no RoomGate / StratumExit / Stratum1BossRoom touched.
- **Existing `tests/test_level_chunk.gd` (28 tests)** — untouched + passes in this CI run.
- **`LevelChunkDef.gd` / `MobSpawnPoint.gd` / `ChunkPort.gd`** — untouched (pure additive PR; no existing Resource shapes modified).
- **Main.tscn** — untouched. The worked-example `.tres` is not yet wired into the scene graph; W2 retrofit ticket lands the Main.tscn re-wire.
- **Save schema** — additive-on-v5 implication documented but no save-write change in this PR. The `world_seed` save-write lands in the sibling procgen spike (`86c9xub9p`) Devon-led ticket.

## Adjacent specs probed

- `test_stratum1_rooms.gd` — untouched, expected pass (existing S1 chunk arrangement is unchanged; worked-example `.tres` is not yet integrated into the room driver).
- `test_stratum_namespace.gd` — untouched, expected pass.
- AC4 boss-clear Playwright spec — untouched, expected pass (gameplay flow unaffected; zone schema is data-only).

## Schema review request (Devon + Priya)

Posted as inline section in PR body. Concrete asks:

- **Devon** — does the field set (`anchors` / `procedural_slot_pool` / `min_/max_slots_between_anchors` / `port_mating_rules`) cover what `assemble_floor(chunks_by_id, zone_def, seed)` needs? Flag rename / restructure now (cheap) vs after the procgen spike consumes them (expensive).
- **Priya** — does the `s{stratum}_z{ordinal}_{slug}` zone_id convention + anchor `room_id` shape work for the quest-content authoring you'll wire in Track 3 W2?

## Non-obvious findings

1. **Two anchors MAY share `chunk_id` if `room_id`s differ.** The worked example demonstrates this: `boss_room` (`room_id = &"s1_z1_bossward"`) and `exit` (`room_id = &"s1_z1_descent"`) both reference `chunk_id = &"s1_room08"`. The schema doesn't forbid it; the assembler places the chunk twice with distinct parent nodes. Save schema + quest binding + map UI all key on `room_id` so the two slots are distinct entities to gameplay. Documented in § "ZoneAnchor kinds enum" of the doc + the `ZoneAnchor.gd` class-doc.

2. **`target_zone_id` on non-exit anchor is an explicit `validate()` error**, not a silent ignore. The schema could have soft-failed (ignore the field when `anchor_kind != &"exit"`), but a typo where someone authors a `quest_target` anchor and pastes a `target_zone_id` would silently lose the routing. Hard-fail catches it at validate-time. Tradeoff: slightly more rigid schema. Mitigation: only one place to set `target_zone_id`, so the typo class is small.

3. **`port_mating_rules: Dictionary` defaults empty.** Chose Dictionary over a typed nested Resource because the rules are sparse per-zone (most zones have zero overrides; only edge cases like a stratum-descent boss-arena exit need them). A typed nested Resource would have forced every zone to either populate or null-ref the field; Dictionary lets the default be cleanly empty. The cost: less editor type-completion when authoring overrides. Acceptable for the W1 spike; revisit when overrides become common.

4. **`procedural_slot_pool` is `Array[StringName]` not `Array[LevelChunkDef]`.** Same rationale as `MobSpawnPoint.mob_id` per the existing § "Why mob spawns reference mob_id, not MobDef" — chunks shouldn't import the chunk-resource graph directly. Pool entries are resolved by the assembler at floor-build time against a `chunks_by_id: Dictionary` parameter, NOT by the `ZoneDef` `.tres` import path. Keeps `.tres` load cheap + decouples zone authoring from chunk-resource changes.

## Doc updates

- `team/drew-dev/level-chunks.md` — new `## Zone schema` section (6 sub-sections, ~280 lines).
- No `.claude/docs/` updates this PR. The schema's design is documented in `level-chunks.md` per the ticket spec (port-mating discipline is reused, not extended; no new convention surfaces).

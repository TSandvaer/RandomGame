# M2 Week-1 Acceptance Plan — Embergrave

**Owner:** Tess (QA) · **Phase:** anticipatory (drafted before M2 implementation begins) · **Drives:** Tess sign-off gate for T1–T11 of `team/priya-pl/m2-week-1-backlog.md` once those tickets land.

This doc is the QA equivalent of Priya's M2 week-1 backlog: it locks the acceptance contract for every ticket in advance, so when Devon/Drew/Uma open PRs, the bar to flip `ready for qa test` → `complete` is already enumerated. **Nothing here ships in M1; nothing here gates M1 sign-off.** This is anticipatory sign-off scaffolding so the M2 dispatch isn't running blind.

Same structural pattern as `team/tess-qa/m1-test-plan.md` — per-ticket acceptance criteria, edge-case probes, integration scenarios, and Sponsor-soak targets — but layered on M2's 11 implementation tickets instead of M1's 7 acceptance criteria.

## TL;DR

1. **Coverage:** 11 M2 week-1 implementation tickets (T1–T11) covered, total **~58 acceptance criteria** + ~28 edge-case probes mapped onto the locked Half-B design docs.
2. **Fixtures:** 6 save fixtures catalogued in `tests/fixtures/m2-week-1-fixtures.md` (4 v3 + 2 v4 — Devon's M2 migration impl authors them when T1 lands).
3. **Paired-test files:** 5 new GUT files indexed in `tests/integration/M2-PAIRED-TEST-FILES.md` — Tess writes each once the corresponding T-ticket lands.
4. **Sponsor-soak targets:** 6 — stash discoverability, EMBER-BAG salience, recovery-pip findability, one-bag-per-stratum feel, S2 "I'm somewhere new" beat, S2 BGM/ambient harmony.
5. **Gating sign-off:** all 51 numbered acceptance rows from the Half-B docs (ST-01..ST-28 + S2-PL-01..S2-PL-15 + INV-1..INV-8) pin via paired GUT tests OR explicit Tess soak verification + zero blocker/major bugs open against M2 week-1 + clean M2 RC HTML5 audit re-run.

---

## Source of truth

This acceptance plan validates implementation against the following Half-B design docs (all merged on `main` at the time of authoring; if any doc is revised post-Sponsor M1 soak, this plan absorbs the diff in a v1.1):

1. **`team/priya-pl/m2-week-1-backlog.md` (PR #97)** — the 12 ticket definitions T1–T12. T12 is this doc.
2. **`team/uma-ux/stash-ui-v1.md` (PR #82)** — ST-01..ST-28 acceptance shape; the player-visible contract for stash UI + ember-bag.
3. **`team/uma-ux/palette-stratum-2.md` (PR #86)** — S2-PL-01..S2-PL-15 acceptance shape; Cinder Vaults palette + biome readability.
4. **`team/devon-dev/save-schema-v4-plan.md` (PR #84)** — INV-1..INV-8 round-trip invariants; six fixture catalog.
5. **`team/drew-dev/level-chunks.md` § "Multi-stratum tooling (M2 scaffold)"** — `Stratum` namespace, `MultiMobRoom` rename, S2 implementer checklist.
6. **`team/tess-qa/m1-test-plan.md`** — structural template for this doc; M1 ACs are the floor (nothing in M2 regresses any M1 AC).
7. **`team/tess-qa/html5-rc-audit-591bcc8.md`** — the W3-A5 audit template that gets re-run on `m2-rc1`.

The M1 acceptance contract (all 7 ACs from `team/priya-pl/mvp-scope.md`) is the floor. Every M2 acceptance row implicitly carries "and M1 AC1–AC7 still pass." Devon's INV-5 (v3 field preservation) is the canonical regression gate for M1-data survival through the v4 bump.

---

## Per-ticket acceptance criteria

For each M2 week-1 ticket the format is: **acceptance criteria** (what the impl PR must satisfy for sign-off) + **edge-case probes** (testing-bar EP-X menu picks) + **integration scenario** (how the ticket gets exercised end-to-end) + **Sponsor-soak target** (what only the human can validate, where applicable).

### T1 — `feat(save): v3→v4 migration impl`

**Acceptance criteria (5):**

- **T1-AC1 — INV-1..INV-8 all pin.** All eight round-trip invariants from `save-schema-v4-plan.md §5` (v3-loads-clean / empty-stash-backfill / empty-bags-backfill / stash-ui-state-backfill / v3-field-preservation / v0→v4-chain / v4-idempotence / v4-envelope-on-disk) assert green in `tests/test_save_migration_v4.gd`.
- **T1-AC2 — `Save.SCHEMA_VERSION` is `4`.** Constant at line ~1 of `Save.gd` reads `const SCHEMA_VERSION: int = 4`. After any `save_game()` call on M2 build, the on-disk envelope `schema_version` field is `4` (INV-8 is the executable form of this).
- **T1-AC3 — `_migrate_v3_to_v4` is `has()`-guarded + idempotent.** Re-running on already-v4 data is a bit-identical no-op (INV-7). Re-running on v3 data with manually-injected `character.stash` is a no-op for stash + still backfills bags + ui-state.
- **T1-AC4 — `DEFAULT_PAYLOAD` updated.** New character keys (`stash: []`, `ember_bags: {}`, `stash_ui_state: { stash_room_seen: false }`) are present in the constant; fresh-character save writes them at v4 envelope.
- **T1-AC5 — M1 contract holds.** All M1 ACs (especially AC3 death-doesn't-lose-level + AC6 quit-relaunch) re-run green on the M2 build. INV-5 + the existing `tests/test_save_roundtrip.gd::test_death_rule_keeps_level_xp_equipped` are the regression gate.

**Edge-case probes (3):**

- **EP-RT (save/load round-trip):** `save_v3_baseline.json` loaded under v4 runtime, mutated, re-saved, re-loaded — every v3 field bit-identical (INV-5 in EP form).
- **EP-OOO (out-of-order):** v3 fixture with `character.stats` present but missing `unspent_stat_points` (the `save_v3_partial_corruption.json` fixture) — migration must not crash, must not introduce v4 fields based on missing v3 fields.
- **EP-DUP (duplicate trigger):** call `Save.migrate(data, 3)` twice on the same dict — second call is a no-op; no double-backfill, no `character.stash` becoming `[[]]` or similar.

**Integration scenario:** Player playing M1 RC `embergrave-html5-ceb6430` (v3 saves on disk) launches M2 build. Continue resumes their character — level + xp + equipped + stats all bit-identical from before. The new `character.stash` / `character.ember_bags` / `character.stash_ui_state` keys are present at default values. They die in S1 R3 — under T7 the bag spawns; under T1 alone (without T7) the schema permits the slot but the game-code consumer hasn't wired in yet (so bag is `null`-equivalent).

**Sponsor-soak target:** None directly — migration is a unit-level surface. SP-quit-relaunch on `m2-rc1` is the indirect probe.

### T2 — `feat(save): SaveSchema.gd autoload`

**Acceptance criteria (4):**

- **T2-AC1 — Autoload registers.** `project.godot` autoload list includes `SaveSchema = "*res://scripts/save/SaveSchema.gd"`. Project loads without errors. `SaveSchema._ready()` print smoke line appears in console (`[SaveSchema] autoload ready (defaults: N keys)`).
- **T2-AC2 — DEFAULTS map round-trip.** `SaveSchema.default_value("character.level")` returns `1`; `default_value("character.stash_ui_state.stash_room_seen")` returns `false`; every key in §4.2 of save-schema-v4-plan.md returns the documented default.
- **T2-AC3 — Unknown-key returns null.** `SaveSchema.default_value("nonsense.path.that.does.not.exist")` returns `null` (not error, not crash). `is_canonical("nonsense.path")` returns `false`.
- **T2-AC4 — No regressions.** Existing `tests/test_save_roundtrip.gd`, `tests/test_save_migration.gd`, `tests/test_autoloads.gd` all pass. New `tests/test_save_schema.gd` is paired with the impl PR.

**Edge-case probes (3):**

- **EP-MEM (memory pressure):** call `default_value` 1000× in a tight loop — no allocation pressure, no GC churn (the constant dict is shared).
- **EP-DUP (duplicate trigger):** call `_ready()` a second time (TI-4 idiom from W3-A5 audit) — observable state unchanged.
- **EP-OOO (out-of-order):** call `default_value` before the first `Save` call in session — autoload-order-independence holds (Save.gd:55 `DEFAULT_PAYLOAD` and SaveSchema.DEFAULTS are independent constants).

**Integration scenario:** SaveSchema lands as an autoload but no consumer in this PR refactors to use it. Fresh M2 dev work in T3 / T7 / T9 reads `SaveSchema.default_value(...)` instead of hand-coding `if not character.has(...): default`. M3 multi-character work has a single source of truth to extend.

**Sponsor-soak target:** None — pure-engine refactor surface.

### T3 — `feat(ui): stash UI implementation (StashPanel + cell rendering)`

**Acceptance criteria (6):**

- **T3-AC1 — Stash grid is exactly 12×6 = 72 cells.** ST-04 from stash-ui-v1.md §6. Single screen, no scrolling. Cells use existing `InventoryCell.tscn` verbatim (tier color border, +pip glyph, tooltip).
- **T3-AC2 — Tab + B coexistence works.** ST-05. Tab opens inventory; B opens stash; both can be open simultaneously. Esc closes most-recently-opened (LIFO close). **Open question 8 in stash-ui-v1.md §7 resolved** — drag-from-stash-to-equipped slot wins drop while inventory grid has keyboard focus (Devon's call documented in PR; Tess validates whichever Devon picks reads correctly).
- **T3-AC3 — `Engine.time_scale == 1.0` throughout stash room.** ST-06. Whether panels are open or closed, in-stash-room time scale is 1.0. Combat-context = `Levels.in_stash_room == false` is the gating predicate. This is a refactor-correctness check; `tests/test_stash_panel.gd::test_time_scale_holds_at_1_in_stash_room` is the paired test.
- **T3-AC4 — LMB swap-pool semantics.** ST-07 + ST-08. LMB on inventory cell with stash open moves to first empty stash cell; LMB on stash cell with inventory open moves to first empty inventory cell. No confirm prompt (reversible).
- **T3-AC5 — Drag-and-drop between grids works.** ST-09 (drag-equip from stash directly skips inventory). Drag-from-stash to inventory cell is the explicit-position path.
- **T3-AC6 — Discard semantics match inventory.** ST-10. T2+ discard prompts inline confirm; T1 discards immediately with undo toast.

**Edge-case probes (4):**

- **EP-RAPID (rapid input):** mash B / Tab / Esc as fast as possible — no double-open, no panel-stack desync, `Engine.time_scale` does not drift.
- **EP-INTR (mid-action interrupt):** start a drag-from-stash, press Esc mid-drag — drag is cancelled cleanly; item stays in stash; no orphaned drag-state.
- **EP-RT (save/load round-trip):** populate stash with 5 items, save, quit, relaunch — stash array survives bit-identical via v4 schema (ST-22).
- **EP-DUP (duplicate trigger):** double-LMB on the same inventory cell when stash is open — first click moves to stash, second click on (now-empty) cell is a no-op (no `character.stash` mutation, no error).

**Integration scenario:** Player enters stash room (T9), presses B, panel opens. Tab also opens inventory panel side-by-side. Drag a T2 sword from inventory to stash. Drag a T3 hauberk from stash to equipped armor slot directly. Press Esc to close stash; press Esc to close inventory. Walk south; descend portal triggers. Run begins; B does nothing (context-sensitive binding deregistered). This is the M2 between-runs UX vertical slice.

**Sponsor-soak target:** **"Where do I put my stuff?"** — stash discoverability per stash-ui-v1.md §6. If Sponsor misses the chest/B affordance for >2 minutes on first stash-room entry, affordance is too quiet (T9 hint-strip is the layered cue).

### T4 — `feat(content): stratum-2 sprite authoring`

**Acceptance criteria (5):**

- **T4-AC1 — All five hard-need sprites land.** Floor tiles (Cinder-Rust burnt-earth + collapsed-mining-stone variants ~6 tiles), wall tiles + ash-glow vein 6 fps 8-frame anim (~5 + animated band), ash-glow node prop, doorway prop, S2 grunt sprite. Each as Aseprite source (`*.aseprite`) + exported PNG, committed to `resources/mobs/s2/...` per Drew's M2 implementer note.
- **T4-AC2 — Hex-code conformance.** S2-PL-02, S2-PL-03, S2-PL-04, S2-PL-05 from palette-stratum-2.md §7 pin via eye-dropper screenshots. Floor base = `#3F1E1A`; wall base = `#2A1410`; vein cycle = `#C25A1F` ↔ `#FF6A2A`; mob aggro eye = `#D24A3C`.
- **T4-AC3 — Anti-list rules hold.** S2-PL-08, S2-PL-09, S2-PL-10. Zero pure-black `#000000` env tiles; zero T4-violet `#8B5BD4` env pixels; zero cool-teal/cyan env pixels.
- **T4-AC4 — Daltonization holds.** S2-PL-13. Uma re-runs §6 daltonization once sprites are at-pixel; if any of the 5 at-risk pairs collapse in deuteranopia / protanopia / tritanopia, Drew swaps before merge.
- **T4-AC5 — Visual constants preserved.** S2-PL-07 (ember accent reused for vein cores AND player flame AND item drops AND T6 mythic — no swap). S2-PL-14 (UI panel BG remains `#1B1A1F` 92% in S2 — cross-stratum constant).

**Edge-case probes (3):**

- **EP-EDGE (geometry/range edge):** sprites at extreme tile boundaries (room corner, doorway transition) — no subpixel jitter at 2×/3×/4× scale per visual-direction.md.
- **EP-MEM (memory pressure):** load all S2 sprites in a single scene + 30 mobs concurrent — no texture-atlas thrash, no draw-call cliff at the 72-cell stash + S2 room composite.
- **EP-BLUR (tab-blur HTML5):** S2 vein-pulse anim during tab-blur — animation pauses cleanly, resumes without frame-skip or color desync on tab-return.

**Integration scenario:** Drew commits sprites to `resources/mobs/s2/`. T5 references them via `*_scene_path` exports on the s2 chunk_def. S2 R1 renders with real Cinder-Rust visuals (not hex-block placeholders). Sponsor walks through S1→S2 descent — S2-PL-15 ("I'm somewhere new" beat) reads at-pixel.

**Sponsor-soak target:** **"S2 reads as descent, not lateral move."** S2-PL-15. If Sponsor walks into S2 R1 and doesn't say "oh, this is different" within 1 second, palette didn't do its job.

### T5 — `feat(level): stratum-2 first room (s2_room01)`

**Acceptance criteria (5):**

- **T5-AC1 — Room loads + assembles.** `resources/level_chunks/s2_room01.tres` exists as `LevelChunkDef` with `chunk_id: "s2_room01"`. `scenes/levels/Stratum2Room01.tscn` instantiates without errors; `LevelAssembler.assemble_single` builds the assembly; mobs spawn inside chunk bounds. Paired test mirrors `test_stratum1_rooms.gd`'s 17-test pattern.
- **T5-AC2 — Decoration beats present.** S2-PL-04 vein anim cycles. Loose scree at floor edges (inert in v1 per palette-stratum-2.md §8 q2). Broken mining-cart silhouettes on background plane. Iron support struts as foreground props. Steam vents inert in v1 (per §8 q3).
- **T5-AC3 — Lighting model implemented per §4.** `CanvasLayer` + `ColorRect` ambient `#FF5A1A` 8% multiply (S2-PL-11). Vignette deepened to `#0A0404` 40% (S2-PL-06). Vein-pulse via sprite anim, NOT Light2D. No realtime shadows. No deferred lighting.
- **T5-AC4 — S2 stratum-namespace conformance.** Folder layout uses `resources/mobs/s2/...` per Drew's M2 implementer note. `MultiMobRoom` (renamed in W3-B2 scaffold) is the room type, not a re-rolled MultiMobRoom1.
- **T5-AC5 — S1→S2 descent works.** Player crosses S1's descent portal and lands in S2 R1 (this is the e2e contract; full integration in T9 stash-room descent + T1 v4 schema). Stub-level pass: paired test stages a player at S1 descent portal, simulates trigger, asserts player ends up inside `Stratum2Room01.tscn` bounds.

**Edge-case probes (3):**

- **EP-EDGE (geometry/range edge):** S2 R1 loaded at non-default scale (3×) — no chunk bounds drift, no off-tile spawn.
- **EP-RT (save/load round-trip):** save mid-S2-R1 with S2 mobs alive; quit; relaunch; Continue resumes inside the same room with mob state restored per `StratumProgression` snapshot contract.
- **EP-INTR (mid-action interrupt):** descend from S1 to S2 mid-sprite-load — assembly does not race; mobs don't spawn outside bounds during the descent fade.

**Integration scenario:** Player clears S1 R8 boss (M1 contract), walks through S1 descent portal, sees the descend animation, lands in S2 R1. Cinder-Rust palette reads. Vein-pulse anim is alive. S2 grunt mobs are present in the bounds, behaving with the existing AI state machine. Player engages, kills, room is cleared. Save tick fires (existing M1 stratum-exit pattern). Quit-relaunch resumes here.

**Sponsor-soak target:** Same as T4 — "I'm somewhere new" within 1 second of S2 visibility.

### T6 — `feat(mobs): stratum-2 mob v1 — Stoker`

**Acceptance criteria (5):**

- **T6-AC1 — Stoker spawns + state machine works.** New TRES at `resources/mobs/s2/stoker.tres`; scene at `scenes/mobs/Stoker.tscn`; script at `scripts/mobs/Stoker.gd`. State machine: idle → aggro → telegraph (1.0 s wind-up) → attack (cone fire breath, 2 s) → cooldown (1.5 s recovery, vulnerable). Paired GUT tests cover all 5 transitions + hit→die path (mirroring `test_grunt.gd` / `test_shooter.gd` patterns).
- **T6-AC2 — Telegraph reads at-screen.** 1.0 s wind-up has visible chest-glow brightening (sprite anim) + audio cue (placeholder OK if T10 hasn't filled). Player has time to dodge; cone-fire-breath cone is geometrically authored (not a screen-wide AOE).
- **T6-AC3 — Damage applies + DoT mechanic works.** Cone fire breath deals contact + DoT damage. DoT ticks on standard interval (matches existing damage-pipeline for Charger/Shooter).
- **T6-AC4 — Drop pipeline works.** Stoker dies → existing LootRoller drops loot via the S2 mob drop tables (T6 sub-deliverable; Drew authors). Drop conforms to T1–T3 tier ramp + AC7 (≥2 distinct affixes findable in M2 if S2 drops feed the same pool).
- **T6-AC5 — MobRegistry vs match-block decision documented.** Either `MultiMobRoom._spawn_mob` match-block grows by one branch for the Stoker, OR the new `MobRegistry` autoload shipped per Drew's M2 implementer note 5. Whichever Devon/Drew chose, the decision is documented in the PR body, and the alternative is filed as a follow-up ticket if punted.

**Edge-case probes (4):**

- **EP-RAPID (rapid input):** player attacks Stoker mid-telegraph — does the wind-up cancel cleanly when the Stoker is hit? (Documented design intent: Drew's call, but tested either way — EITHER it cancels OR it commits, not undefined.)
- **EP-INTR (mid-action interrupt):** Stoker dies mid-cone-fire-breath (player crit-burst) — fire breath particle/anim aborts, no orphan damage hitbox, no console error.
- **EP-EDGE (geometry/range edge):** Stoker telegraph fires while player at extreme cone-edge — damage applies if inside cone, doesn't if outside. Cone math is documented in PR.
- **EP-BLUR (tab-blur HTML5):** Stoker mid-telegraph during tab-blur — telegraph timer holds; on tab-return, either resumes cleanly or fires (not undefined). Same disposition as M1 boss-entry-sequence (SP-1 from W3-A5 audit).

**Integration scenario:** Player in S2 R1 sees a Stoker. Approaches; aggro fires; chest-glow brightens; fire breath telegraphs; player dodges; Stoker enters cooldown; player attacks during cooldown; Stoker dies; loot drops. The first new archetype in M2 — narrative beat is "this stratum has its own threat, not just S1 mobs in red costumes."

**Sponsor-soak target:** **"Does the Stoker feel like a different kind of fight?"** Subjective; M2 RC gates this. If Sponsor reads Stoker as "just a charger with a fire breath" the archetype didn't differentiate enough.

### T7 — `feat(progression): ember-bag pickup-at-death-location impl`

**Acceptance criteria (6):**

- **T7-AC1 — Ember-bag spawn on death.** ST-11. On death with N unequipped inventory items, an EmberBag entity is created with all N items at the player's death tile. `pending_ember_bags[stratum]` populated per save-schema-v4-plan.md §2.4.
- **T7-AC2 — Equipped items NEVER in bag.** ST-12. Equipped weapon/armor persists with character per M1 death rule. Bag carries only unequipped inventory.
- **T7-AC3 — Atomic save fires before run-summary.** save-schema-v4-plan.md §7.3 — `pack_bag_on_death` calls `Save.save_game()` synchronously after updating `character.ember_bags`. Paired test asserts the call order. **Regression gate** — if the save is deferred, a process kill between death and the next save point silently drops the bag.
- **T7-AC4 — Edge cases per stash-ui-v1.md §2.** Six edge-case rows pin via paired tests:
  - room-doesn't-exist next run → fallback to stratum-entry stash room (ST-23).
  - boss-room death → bag at boss-arena entry, not on the arena (ST-24).
  - same-tile second death → second bag replaces first; first bag's items lost (ST-20).
  - inventory full at recovery → overflow to stash (ST-18).
  - stash also full at recovery → bag stays in-world, partial recovery (ST-19).
  - items-reference-deleted-content → drop entry with `push_warning`; bag-state corruption doesn't nuke the character.
- **T7-AC5 — Cross-stratum independence.** ST-21. Dying in S2 while a bag is pending in S1 — both bags exist independently; cap = 8 entries (one per stratum).
- **T7-AC6 — Recovery flow works.** ST-17. Walking over the bag plays recovery audio + ember-rise particle dissolve + 4 s toast `Ember Bag recovered · N items returned`. No confirm prompt (bag is unambiguously yours).

**Edge-case probes (4):**

- **EP-INTR (mid-action interrupt):** die DURING a save-game-tick — save is not corrupted; bag state from atomic-write `.tmp` either committed or not, last-known-good is readable (matches M1 `M1-AC3-T04` pattern).
- **EP-DUP (duplicate trigger):** trigger `pack_bag_on_death` twice on the same death (programming error simulation) — second call is a no-op or replaces atomically; no double-bag in the same stratum.
- **EP-RT (save/load round-trip):** die with bag, quit, relaunch, recover — bag survives via v4 schema (ST-22).
- **EP-OOO (out-of-order):** trigger `recover_bag(stratum)` for a stratum with no pending bag — clean no-op, no error, no drift.

**Integration scenario:** Player at S1 R3 with 5 unequipped inventory items (T2 sword, T1 hauberk, two consumables, a relic). Dies. Run-summary shows EMBER BAG · RECOVERABLE section with 5 ember-tinted item icons. Player descends again. Stratum-entry banner reads `Ember Bag pending — Stratum 1 · Room 3 / 8`. HUD pip pulses. Player walks to S1 R3, walks over bag, recovery whoosh fires, all 5 items return to inventory.

**Sponsor-soak target:** **"Did I lose my [X]?"** EMBER BAG salience on summary screen. If Sponsor doesn't notice the section, ember-orange isn't strong enough vs. KEPT (per stash-ui-v1.md §6 Sponsor probe). **AND** **"Where's my bag?"** — pre-respawn navigation. If banner+pip+minimap-marker stack still doesn't get Sponsor to the bag, we need a fourth cue.

### T8 — `feat(ui): death-recovery flow screens`

**Acceptance criteria (4):**

- **T8-AC1 — Run-summary EMBER BAG section.** ST-13. KEPT → EMBER BAG → LOST WITH THE RUN sectioning per stash-ui-v1.md §3 Beat E mockup. Ember-orange section header. Item cards at full saturation (not greyed). Subtitle `Recoverable in Stratum N · Room x/y`. ST-14: if bag is empty, section is omitted entirely (no empty placeholder).
- **T8-AC2 — Stratum-entry banner.** ST-15. 2 s slide-in from top of HUD when crossing into a stratum with a pending bag. Text `Ember Bag pending — Stratum N · Room x/y`. Ember-orange on dark slate. Dismisses on any input. **Tab-blur edge probe**: banner doesn't lock if tab-blur during slide-in (HTML5 timer correctness).
- **T8-AC3 — HUD pip + minimap marker.** ST-16. 8×8 pip 12 px left of HP bar. Idle 50% opacity. In-stratum pulse 50%↔100% over 1.0 s. In-room pulse `#FFB066` faster (0.5 s cycle). Minimap marker matches pip glyph.
- **T8-AC4 — Visual conformance.** ST-27. Stash UI conforms to palette + cell rendering rules from inventory panel. ST-28. Ember-bag pickup sprite uses `#FF6A2A` ember motes matching player death-dissolve. UI chrome cross-stratum constant (no S2-specific tints in the HUD).

**Edge-case probes (3):**

- **EP-BLUR (tab-blur HTML5):** stratum-entry banner triggered, alt-tab away during slide-in, return — banner state doesn't lock; either completes cleanly or dismisses cleanly.
- **EP-RAPID (rapid input):** mash any-input during banner display — first input dismisses banner; subsequent inputs go through to gameplay.
- **EP-EDGE (geometry/range edge):** HUD pip while at extreme HP states (1 HP, full HP) — rendering position holds 12 px left of HP bar regardless of HP-bar state.

**Integration scenario:** Player dies in S2 R3 → M1 sequence Beat A-D unchanged → Beat E run-summary surfaces EMBER BAG section → Beat F descend-again → respawn at S1 stash room → walks south to descend → enters S1 R1 → no banner (no S1 bag pending) → reaches descent portal → enters S2 R1 → banner slides in (S2 bag pending) → HUD pip lights up → player navigates to R3 → pip pulses faster → walks over bag → recovery flow.

**Sponsor-soak target:** Same as T7 — EMBER BAG salience + bag-find navigation. Plus a copy / microcopy probe — "do the section labels read as ember-themed and not generic?"

### T9 — `feat(level): stash room scene + B-key context binding`

**Acceptance criteria (5):**

- **T9-AC1 — Stash room visible at S1 entry.** ST-01. Player can walk into / out of the stash room freely between runs. Stash chest sprite + idle anim (ember motes) renders. Stratum-1 instance is `Stratum1StashRoom.tscn`.
- **T9-AC2 — Stash room NOT accessible mid-run.** ST-02. No door appears in any in-run room layout. Door behind player locks visually on descent commit (per stash-ui-v1.md §1).
- **T9-AC3 — B-binding context-sensitivity.** ST-03. Pressing B in stash room opens stash panel. Pressing B outside stash room does nothing. `Levels.in_stash_room: bool` drives the `InputManager` register/unregister. `entered_stash_room` / `left_stash_room` signals fire correctly (paired test asserts signal contract).
- **T9-AC4 — Hint-strip first-visit gating.** Per stash-ui-v1.md §3 Beat. Non-modal hint-strip at screen bottom shows `[E] open chest [B] open stash [Tab] inventory [Down] descend`. Fades after 5 s of player movement. Won't re-show in this session unless `stash_ui_state.stash_room_seen=false` (first-ever-visit only).
- **T9-AC5 — `stash_room_seen` persistence.** Flips false→true on first entry. Survives save/load via v4 schema. Save → quit → relaunch → re-enter stash room → no hint-strip (correct).

**Edge-case probes (3):**

- **EP-RT (save/load round-trip):** first-ever stash room entry, save, quit, relaunch — `stash_room_seen=true` persists; hint-strip does not re-show. ST-22 partial (stash + bags + flag all survive).
- **EP-OOO (out-of-order):** press B before entering stash room — does nothing (binding deregistered). Walk into stash room without pressing B — no panel, no errors.
- **EP-DUP (duplicate trigger):** rapid enter/exit stash-room boundary — `entered_stash_room` / `left_stash_room` signals fire each transition cleanly; no signal storm; binding state holds correct.

**Integration scenario:** First-ever run: player respawns at S1 stash room → hint-strip appears → walks around for 5 s → hint fades → presses B → stash panel opens → manages stash → presses Esc → walks south → descent door → run begins → B does nothing in-run → dies → respawn at stash room → no hint-strip (`stash_room_seen=true`).

**Sponsor-soak target:** **"Stash room placement: is the M1 first-room intro retired or kept?"** (Open question 1 in m2-week-1-backlog.md §"Open questions for Sponsor.") Default per Priya's rec is option (b) — stash room is a NEW room *before* the M1 first-room intro. Sponsor M2 soak validates the descent flow.

### T10 — `design(audio)+source: mus-stratum2-bgm + amb-stratum2-room`

**Acceptance criteria (3):**

- **T10-AC1 — S2 entry triggers cues.** Player descends S1→S2. `mus-stratum2-bgm` plays on the music bus. `amb-stratum2-room` plays on the ambient bus. Paired test asserts `AudioStreamPlayer.is_playing()` is true after the descend transition for the expected stream resources.
- **T10-AC2 — 5-bus structure holds.** No new bus added (per audio-direction.md §3). Both cues use existing music + ambient buses. Sidechain duck spec preserved.
- **T10-AC3 — Placeholder vs. final acceptable.** P1 fallback: placeholder dark-folk loops are explicitly acceptable per audio-direction.md §4. Final hand-composed lands as a M2 follow-up. **NOT a quality regression to ship placeholder.** OGG q5/q7 sourcing per audio-direction.md.

**Edge-case probes (2):**

- **EP-RT (save/load round-trip):** descend → save → quit → relaunch → Continue → audio resumes correctly on the right bus, not stuck on S1 BGM.
- **EP-BLUR (tab-blur HTML5):** S2 BGM mid-loop during tab-blur — audio pauses (browser default for hidden tab) and resumes cleanly on tab-return; no decode-restart artifact.

**Integration scenario:** Player descends to S2 R1 — the first thing they hear changes from S1's `mus-stratum1-bgm` to S2's hand-composed (or placeholder) Cinder Vaults BGM. Audio reinforces the visual "I'm somewhere new" beat from T4/T5.

**Sponsor-soak target:** **"Does S2 audio harmonize with the Cinder Vaults visual?"** Subjective; if Sponsor still hears the indicative Sunken Library brief in their head and the audio reads as cool-eerie instead of warm-pressure-depth, the harmonization didn't land.

### T11 — `chore(ci): M2 first-pass RC build artifact pipeline`

**Acceptance criteria (3):**

- **T11-AC1 — `m2-rc1` artifact uploads.** Either copy-renamed `release-github-m2.yml` workflow OR an M2 RC tag pattern in the existing workflow (Devon's call). HTML5 zip + Windows zip uploaded as a GitHub Release on `m2-rc-N` tag or workflow_dispatch.
- **T11-AC2 — SHA footer shows M2 build.** Existing testability hook #1 (build SHA visible in main menu) shows the M2 build SHA, not stale M1 SHA. `BuildInfo.short_sha` resolution chain works (TI-8 from W3-A5 audit holds).
- **T11-AC3 — HTML5 audit re-run.** Tess re-runs `team/tess-qa/html5-rc-audit-591bcc8.md` template on `m2-rc1`; produces `team/tess-qa/html5-rc-audit-m2-rc1.md` (or similarly named). Six new HTML5 surfaces audited (see below).

**Edge-case probes (1):**

- **EP-MEM (memory pressure):** 30-min soak on `m2-rc1` HTML5 build with full M2 surfaces (stash + ember-bag + S2 + Stoker + audio); browser tab memory plateaus per M1-AC5-T06 pattern.

**Integration scenario:** Devon tags `m2-rc-1` on the M2-feature-complete branch. Workflow fires. Artifact uploaded. Tess pulls artifact, reads source at the tagged SHA, runs HTML5 audit pattern, ships a re-audit doc. Sponsor's M2 30-min interactive soak runs against `m2-rc1`.

**Sponsor-soak target:** Same as T1–T10 — `m2-rc1` is the build the Sponsor soaks. None specific to the pipeline; pipeline is invisible to Sponsor when working.

---

## M2 RC build verification

When the first M2 RC artifact (`m2-rc1`) lands per T11, Tess runs the analogue of the M1 RC audit (`team/tess-qa/html5-rc-audit-591bcc8.md`).

**Audit shape per file:**

| File | Concern | Risk class | Severity floor |
|---|---|---|---|
| `scripts/save/Save.gd` (v4 SCHEMA_VERSION + new migration branch) | v4 migration on cold load | TI | low |
| `scripts/save/SaveSchema.gd` (NEW autoload) | DEFAULTS map round-trip + autoload-order independence | TI | low |
| `scripts/inventory/Inventory.gd` (extended with stash methods) | `snapshot_to_save` includes new stash array; JSON-pure round-trip | TI | low |
| `scripts/progression/StratumProgression.gd` (extended with ember_bags) | `pack_bag_on_death` atomic save; restore from save with bags | TI + SP | medium |
| `scripts/levels/Levels.gd` (extended with `in_stash_room` + signals) | signal-listener leaks on scene-reload mid-binding | TI | low |
| `scripts/ui/StashPanel.gd` (NEW) | `Engine.time_scale` semantics in stash room (must stay 1.0) | TI | medium |
| `scenes/objects/EmberBag.tscn` (NEW) | Area2D + audio cue + ParticleMaterial HTML5 round-trip | SP | medium |
| `scenes/levels/Stratum1StashRoom.tscn` (NEW) | scene loads under HTML5 cold-launch within M1-AC2-T01 60 s budget | TI + SP | low |
| `scenes/levels/Stratum2Room01.tscn` (NEW) | S2 R1 cold-loads; CanvasLayer ambient overlay + vignette renders | SP | medium |
| `scenes/mobs/Stoker.tscn` (NEW) | Stoker telegraph + cone fire-breath particle on HTML5 | SP | medium |
| `release-github-m2.yml` (NEW or modified) | M2 RC artifact uploads on tag; SHA footer correct | TI | low |

**New testable invariants (TI-10..TI-15) for `tests/integration/test_html5_invariants.gd` extension:**

- **TI-10:** `Inventory.snapshot_to_save` after stash population round-trips JSON without info loss (extends TI-2 to v4 schema).
- **TI-11:** `StratumProgression.snapshot_to_save_data` after `pack_bag_on_death` round-trips JSON (extends TI-3).
- **TI-12:** `SaveSchema.default_value` returns the correct constant for every documented dot-path; `is_canonical` returns true for all canonical paths.
- **TI-13:** `Save.SCHEMA_VERSION == 4`; v4 envelope on disk after first save (executable form of T1-AC2 + INV-8).
- **TI-14:** `StashPanel._exit_tree` does not corrupt `Engine.time_scale` (defensive — extends TI-6/TI-7 idiom from W3-A5).
- **TI-15:** Fully-populated v4 save serializes to under 100 KB (size-explosion safety upper bound per save-schema-v4-plan.md §7.2).

---

## HTML5 surface re-audit (6 new surfaces)

Per Priya's R3 escalation in `m2-week-1-backlog.md` §"Risks". Each new surface gets an audit-shape entry analogous to W3-A5:

### HTML5-S2-1: v4 save schema with Dictionary-of-Dictionary persistence

- **Concern:** OPFS / IndexedDB roundtrip on `character.ember_bags` (Dictionary keyed by stringified-int).
- **Audit:** read `Save.gd` post-T1, verify `_migrate_v3_to_v4` produces JSON-pure dict; eye-test the JSON wire-format on a fresh save to confirm string-key ergonomics work in Godot's JSON parser.
- **TI:** TI-13 + TI-15.
- **SP:** save → quit → relaunch on Firefox + Chrome; bag dict survives bit-identical.

### HTML5-S2-2: stash UI panel with 12×6 = 72 cells drawcall budget

- **Concern:** browser drawcall budget on a 72-cell grid + tier borders + +pip glyphs + tooltips.
- **Audit:** read `StashPanel.gd` post-T3; confirm cell rendering reuses `InventoryCell.tscn` (no per-cell allocation thrash); verify panel-open frame-time budget under HTML5 (not just native).
- **TI:** TI-14.
- **SP:** open stash panel + inventory panel simultaneously, drag-and-drop between, watch DevTools FPS — no drop below ~50 fps during interaction.

### HTML5-S2-3: ember-bag pickup with sprite anim + audio cue + ParticleMaterial

- **Concern:** ParticleMaterial + AudioStreamPlayer in browser.
- **Audit:** read `EmberBag.tscn` post-T7; confirm sprite anim + audio cue paths are HTML5-tested at the project level (not native-only).
- **TI:** none direct (scene-level surface).
- **SP:** trigger ember-bag pickup recovery 5× in a row in HTML5 — particle dissolve renders cleanly, audio plays without dropout, no decode-restart artifact.

### HTML5-S2-4: stratum-2 entry with ambient tint overlay

- **Concern:** `CanvasLayer` blend-mode-multiply on browser; `ColorRect` ambient `#FF5A1A` 8% modulate alpha.
- **Audit:** read `Stratum2Room01.tscn` post-T5; confirm CanvasLayer setup uses BLEND_MODE_MUL (or CanvasModulate node) per palette-stratum-2.md §4 prescription, NOT a Light2D.
- **TI:** none direct (visual surface; eye-dropper test only).
- **SP:** S2 entry on Firefox + Chrome — ambient tint renders correctly; no blend-mode artifact; vignette + ambient layered correctly.

### HTML5-S2-5: Stoker mob with cone-fire-breath telegraph

- **Concern:** potential particle / shader implication on cone fire-breath; new state machine surface area.
- **Audit:** read `scripts/mobs/Stoker.gd` post-T6; confirm state machine is print-only logging (no shader divergence from M1 Charger/Shooter pattern). If a shader is used (e.g., for cone heat-distortion), audit it for HTML5-compat.
- **TI:** none direct; Stoker state-machine paired tests are under T6.
- **SP:** Stoker fight on HTML5 in S2 R1 + a downstream room — telegraph reads, fire breath geometry holds, no console-error during 5+ Stoker fights.

### HTML5-S2-6: audio sourcing pass (new OGG streams, browser-decode timing)

- **Concern:** `mus-stratum2-bgm` + `amb-stratum2-room` OGG decoding on cold-launch.
- **Audit:** confirm OGG q5/q7 source-of-truth flow in `audio-direction.md` §4 was followed; verify stream resources are valid and don't trip browser-side decode.
- **TI:** none direct (audio is integration-surface, not unit-testable for browser-decode).
- **SP:** SP-5 from W3-A5 — console error watch during 30-min soak; specifically watch for any OGG-decode error path.

---

## Sponsor probe targets (M2 RC soak)

When `m2-rc1` reaches Sponsor's interactive 30-min soak (M2 week-2 at earliest per Priya's backlog §"Pre-conditions"), watch for:

1. **"Where do I put my stuff?"** — stash discoverability (T3 + T9). If Sponsor misses chest/B affordance for >2 minutes on first stash-room entry, affordance is too quiet. Re-prioritize hint-strip / chest-glyph salience.
2. **"Did I lose my [X]?"** — EMBER BAG section salience on summary screen (T7 + T8). If Sponsor doesn't notice ember-orange section header, ember-orange isn't strong enough vs. KEPT — re-tune contrast or add motion / icon emphasis.
3. **"Where's my bag?"** — pre-respawn navigation (T7 + T8). If banner+pip+minimap-marker stack still doesn't get Sponsor to the bag inside a normal run, fourth cue needed (e.g., a directional arrow at room entrances).
4. **"Why does my old gear disappear?"** — one-bag-per-stratum rule (T7). If Sponsor double-dies and feels cheated, may want to soften (allow N bags per stratum per stash-ui-v1.md §7 q2) or signal "recovering a bag now will overwrite" more clearly.
5. **"S2 reads as descent."** S2-PL-15 (T4 + T5). If Sponsor walks through S1→S2 portal and doesn't say "oh, this is different" within 1 second, palette + lighting + ambient didn't combine to land the descent beat.
6. **"S2 BGM harmonizes with Cinder Vaults."** T10 audio direction. If audio reads as cool-eerie (still on the indicative Sunken Library brief) instead of warm-pressure-depth (Cinder Vaults), audio direction needs a v1.2 nudge or hand-compose deferred.

**Top 3 priority for first M2 soak:** #2 (EMBER BAG salience), #3 (bag-find navigation), #5 (S2 descent beat). These three gate the M2 vertical slice. Others are polish.

---

## Test fixture catalog

See `tests/fixtures/m2-week-1-fixtures.md` for the six fixture shapes (4 v3 + 2 v4) Devon's M2 migration impl will author when T1 lands. This doc owns the acceptance contract; that doc owns the fixture shape contract.

## Paired-test file index

See `tests/integration/M2-PAIRED-TEST-FILES.md` for the 5 paired GUT files Tess writes once the corresponding T-tickets land:

- `tests/test_save_migration_v3_to_v4.gd` (T1 + T2)
- `tests/test_stash_panel.gd` (T3)
- `tests/integration/test_stratum_2_room01.gd` (T5)
- `tests/test_stoker_mob.gd` (T6)
- `tests/integration/test_ember_bag_pickup.gd` (T7 + T8)

---

## Test-pass-count projection

M1 baseline (pre-M2): 587 passing / 1 risky-pending / 0 failing (latest STATE.md run-020 numbers post-PR #94 merge).

M2 week-1 target delta (assuming all T1–T11 land green):

- T1 + T2 (save migration + SaveSchema): **+15–20 paired tests** (INV-1..INV-8 pinned + DEFAULTS map + autoload).
- T3 (stash panel): **+12–15 paired tests** (ST-04..ST-10 hooks + interaction model + time-scale).
- T5 (S2 R1): **+10–15 paired tests** (mirror `test_stratum1_rooms.gd`'s 17-test pattern, scaled to first-room surface).
- T6 (Stoker mob): **+15–20 paired tests** (state machine + damage pipeline + drop pipeline).
- T7 (ember bag): **+15–20 paired tests** (six edge cases + recovery flow + atomic save).
- T8 (death-recovery flow): **+8–10 paired tests** (banner timing + HUD pip + summary section).
- T9 (stash room): **+8–10 paired tests** (signals + binding + first-visit gate).
- T11 (M2 RC): **+6 TI extensions** (TI-10..TI-15).

**Projected M2 week-1 total:** **~90–115 new paired tests**, landing M2 build at ~675–700 passing if every ticket ships green.

---

## Hand-off

- **Devon (T1, T2, T3, T7, T8, T9, T11):** every ticket above has acceptance criteria + edge probes + integration scenario locked. PR sign-off = the criteria pin via paired GUT tests + edge probes documented in PR comment per testing-bar §EP rule + Tess flips ClickUp `ready for qa test` → `complete`.
- **Drew (T4, T5, T6):** content + sprite + Stoker tickets — same flow. T4 daltonization re-run is Uma's hand-off; Tess validates eye-dropper checks via screenshots.
- **Uma (T8 + T10):** copy + visual review + audio direction. T8 is co-owned with Devon (Uma authors copy + screenshots; Devon implements). T10 is sourcing latency-permitted P1.
- **Priya:** monitors capacity guardrails (R8 + R9 + R10); resolves open questions (stash size cap, one-bag-per-stratum, etc.) post-Sponsor M2 soak.
- **Sponsor:** the six probe targets above. M2 week-2 soak gates M2 sign-off the way M1's 30-min soak gated M1.

## Caveat — anticipatory plan

This doc is **anticipatory planning**, drafted before any M2 ticket has opened a PR. Revisions land as v1.1 if:

- A T-ticket scope changes post-Sponsor M1 soak (most likely if Sponsor surfaces M1 design pushback that re-scopes T7 / T3 / T8).
- A Half-B doc revises (e.g., Uma's audio-direction.md v1.2 nudge for `mus-stratum2-bgm`).
- An integration surface emerges that wasn't anticipated (e.g., a new HTML5 regression class).

The 11-ticket coverage + 51-acceptance-row pinning + 5-paired-test-file index is the **path of least resistance from M2 dispatch → M2 sign-off.** It is not the only path.

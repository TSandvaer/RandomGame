# M3 Tier 1 Acceptance Plan — Embergrave

**Owner:** Tess (QA) · **Phase:** parallel-acceptance scaffold (drafted at M3 Tier 1 day-1, mirrors M2 W3-T10 Half A idiom) · **Drives:** Tess sign-off gate for M3-T1-1..M3-T1-4 Tier 2 impl PRs once those tickets dispatch.

This is the M3 analogue of `team/tess-qa/m2-acceptance-plan-week-3.md` — per-pillar acceptance criteria, edge probes, and Sponsor-soak targets, layered onto Priya's M3 Tier 1 plan (`team/priya-pl/m3-tier-1-plan.md`, Shape A — content track). **Nothing here ships executable code in this PR**; this is the QA contract Tess flips green when each M3 Tier 2 impl PR reaches `ready for qa test`.

Shape A has **four parallel tracks** (per `m3-design-seeds.md §4 Milestone shape`). This scaffold seeds three of the four with placeholder acceptance rows; the fourth (character-art pass) is **omitted from engineering acceptance** because external-estimate routing makes it Sponsor-soak-visual-verification work, not GUT/Playwright work. Rows are marked `[PENDING-SPEC]` where they depend on a Tier 1 design doc (Devon's v5 spike `86c9uth5h`, Uma's hub-town direction `86c9uth6a`, Drew's slot-picker spec `86c9uth85`) landing; the row text locks when the design doc lands.

## TL;DR

1. **Coverage:** **3 Tier 1 pillars** scaffolded (§1 save-v5 + multi-character + persistent-meta; §2 hub-town; §4 title-screen slot-picker). §3 character-art-pass is intentionally omitted from engineering acceptance — see § "§3 Character-art pass — engineering-acceptance-omitted block" below.
2. **Placeholder rows:** **27 total** (§1: 8 SV5-* rows; §2: 9 HT-* rows; §4: 10 TS-* rows) + 3 QA-SCAFFOLD-* meta-rows for the scaffold doc itself.
3. **Cross-cutting concerns:** **6** — save-schema v4→v5 regression-pin compatibility, AC4 spec regression-pin (M3 changes mustn't break AC4 green), universal-warning gate (every new M3 spec inherits the `test-base.ts` fixture per `.claude/docs/test-conventions.md`), drift-pin HARD RULE (§17 of `team/tess-qa/playwright-harness-design.md`), HTML5 visual-verification gate triggers, retrospective-pause trigger after N=3 consecutive cluster dispatches (AC4 retro Gap 3 baked in).
4. **AC4-retro lessons baked in (4):** (a) Self-Test Report sample-size discipline ≥8 release-build runs for any stochastic Playwright spec; (b) diagnostic-traces-before-hypothesized-fixes is a Tier 2 dispatch precondition for any M3 spec authored against a hypothesis (not against an instrumented baseline); (c) N=3 consecutive-surfacing retrospective-pause trigger applies to M3 pillars; (d) drift-pin GUT pairs are mandatory for every new Playwright spec asserting on a free-form engine-emit string.
5. **Spec authoring is `test.fail()`-pre-emptive** per AC4 spec convention — Tess can scaffold M3 Playwright specs against the design-doc-stated behavior NOW with `test.fail()` annotations; flip to `test()` when each pillar's Tier 2 impl lands.

---

## Source of truth

This acceptance plan validates implementation against:

1. **`team/priya-pl/m3-tier-1-plan.md`** (Priya, 2026-05-17, v1.0 dispatch-ready) — the 5 first-wave Tier 1 ticket definitions + 4-track sub-milestone shape.
2. **`team/priya-pl/m3-design-seeds.md`** (Priya, 2026-05-15, Sponsor-promoted §4 in M2 RC soak) — Shape A's four-track elaboration with 15 Sponsor-input items; the feature-surface contract this scaffold's rows anchor against.
3. **`team/priya-pl/m3-shape-options.md`** — Shape A locked by Sponsor 2026-05-17.
4. **`team/devon-dev/save-schema-v4-plan.md`** (PR #84, v4 source-of-truth) — INV-1..INV-8 invariants; v5 extends + first violates the `§4.1` additive-only rule. v5 spike (`86c9uth5h`) authors the v5 plan analogue when Devon's design doc lands.
5. **`team/tess-qa/m2-acceptance-plan-week-3.md`** — structural template; M2 W3 ACs are the floor (nothing in M3 Tier 1 regresses any M2 AC).
6. **`team/tess-qa/playwright-harness-design.md` §14, §15, §16, §17** — staleness-bounded latestPos convention (§14), harness-workaround-fail-loud rule (§15), `test.fail()` canary semantics (§16), drift-pin HARD RULE for engine-emit strings (§17). All four apply to new M3 specs.
7. **`team/priya-pl/ac4-white-whale-retro.md`** — the four structural gaps (sample-size ≥8, instrument-first, retrospective-pause-at-N=3, spec-string-vs-engine-emit drift) this scaffold bakes in as cross-cutting concerns.
8. **`.claude/docs/test-conventions.md`** — universal warning gate (GUT `NoWarningGuard` + `WarningBus` + Playwright `test-base.ts` fixture). Every new M3 spec MUST import from `test-base` (Phase 2A migration is on main as of PR #244).
9. **`.claude/docs/html5-export.md`** — HTML5 visual-verification gate triggers for any M3 tween / modulate / Polygon2D / CPUParticles2D / Area2D-state PR.

The M1 + M2 W1/W2/W3 acceptance contracts are the floor. Every M3 Tier 1 acceptance row implicitly carries "and prior milestones' ACs still pass." AC4 green (Playwright `ac4-boss-clear.spec.ts` clean release-build run) is the canonical regression gate for the M2 play-loop.

---

## Per-pillar acceptance criteria

For each Tier 1 pillar the format is: **acceptance criteria** (concrete, testable, ID-prefixed) + **verification method** (paired GUT? Playwright spec? Sponsor probe? HTML5 visual gate?) + **edge-case probes** (where applicable) + **integration scenario** + **Sponsor-soak target** (where applicable).

Rows tagged `[PENDING-SPEC]` lock when the corresponding Tier 1 design doc lands. The row text below is the **anticipatory shape** based on Priya's `m3-tier-1-plan.md` ticket scope + `m3-design-seeds.md` defaults; the design doc may revise (slot count, hub-town size, schema shape) and this scaffold absorbs the diff in a v1.1.

---

### §1 — Save-schema v5 + multi-character + persistent-meta (Devon-led)

**Tier 1 dispatch:** §1-T1 (`86c9uth5h`) — Devon authors `team/devon-dev/save-schema-v5-plan.md`. **Tier 2 dispatches:** v5 migration impl + multi-character slot data wiring + shared_stash lift + ember-shards + Paragon points + active_slot semantics + bounty-quest state. All Tier 2 PRs land paired GUT tests against the SV5-* rows below.

**Acceptance criteria (8):**

- **SV5-1 — v4→v5 round-trip preserves character data.** A v4 fixture loaded under v5 runtime wraps `data.character` into `data.characters[0]` with `slot_index: 0`; all v4 character keys (level / xp / stats / equipped / ember_bags / stash_ui_state) survive bit-identical inside the new slot. Verified via paired GUT in `tests/test_save_migration_v5.gd::test_v4_to_v5_wraps_single_character`. **`[PENDING-SPEC]` — gated on `86c9uth5h` v5 plan landing.**
- **SV5-2 — Migration idempotent on double-call.** Calling `_migrate_v4_to_v5(data)` on already-v5 data is a bit-identical no-op (mirrors v4 INV-7). Verified via paired GUT in `tests/test_save_migration_v5.gd::test_v5_migration_idempotent`. **`[PENDING-SPEC]`.**
- **SV5-3 — `shared_stash` items lift correctly from v4 `character.stash`.** Migration lifts `data.character.stash` (the v4 per-character pool) to `data.shared_stash` (the v5 account-scoped pool); item UIDs preserve; subsequent slots (1, 2) start with empty per-slot inventory but read the same shared_stash. Verified via paired GUT in `tests/test_save_migration_v5.gd::test_shared_stash_lift_from_v4` + fixture `tests/fixtures/v5/save_v4_full_stash_72_slots_to_v5.json`. **`[PENDING-SPEC]`.**
- **SV5-4 — `active_slot` defaults to 0 on first v5 load.** A v4-migrated save and a fresh-v5 save both have `data.active_slot = 0` after the first load. Verified via paired GUT in `tests/test_save_migration_v5.gd::test_active_slot_defaults_zero`. **`[PENDING-SPEC]`.**
- **SV5-5 — Pointer-shadow behavior matches Devon's spike decision.** Per `m3-design-seeds.md §1` Devon-call: either keep `data.character` as a compat shadow pointing at `data.characters[0]` for one schema generation (recommended default) OR remove fully at v5. Whatever Devon's spike chooses, the GUT pin asserts the chosen behavior exactly. Verified via paired GUT in `tests/test_save_migration_v5.gd::test_character_pointer_shadow_<keep|remove>`. **`[PENDING-SPEC]` — locks at v5 plan PR-merge time.**
- **SV5-6 — HTML5 OPFS round-trip works for max-3-character nested `characters[]` array.** A v5 fixture with 3 fully-populated character slots (each with 24-slot inventory + full equipped + 8 ember-bags) round-trips through OPFS bit-identical. Verified via paired GUT in `tests/test_save_v5_html5_stress.gd::test_three_character_opfs_roundtrip` + Sponsor-soak HTML5 probe (Firefox + Chrome). **`[PENDING-SPEC]`** — gated on v5 spike + Tier 2 multi-character impl.
- **SV5-7 — Ember-shards persist per-character.** Per `m3-design-seeds.md §3`, each character has its own `ember_shards: int`. Spending shards at the hub-town anvil deducts from the active character's pool; switching slots loads the other character's pool independently. Verified via paired GUT in `tests/test_ember_shards_per_character.gd::test_shards_isolated_per_slot`. **`[PENDING-SPEC]`.**
- **SV5-8 — Paragon points persist per-character.** Per `m3-design-seeds.md §3`, each character has its own `paragon_points: int` + `paragon_spent: Dictionary[String, int]`. NG+ accumulation is character-scoped, not account-scoped. Verified via paired GUT in `tests/test_paragon_per_character.gd::test_paragon_isolated_per_slot`. **`[PENDING-SPEC]`.**

**Verification methods:**

- SV5-1..SV5-5 + SV5-7..SV5-8: paired GUT tests in `tests/test_save_migration_v5.gd` + `tests/test_ember_shards_per_character.gd` + `tests/test_paragon_per_character.gd`.
- SV5-6: paired GUT + Sponsor HTML5 OPFS soak (mirrors W3-T6 OPFS probe pattern — no headless-browser GUT runner means OPFS validation is dual-surface).
- **Universal warning gate (cross-cutting):** every GUT test file must `attach()` a `NoWarningGuard` in `before_each` and `assert_clean(self)` in `after_each`. Save-load + migration is the canonical load-bearing surface for the gate per `.claude/docs/test-conventions.md`. Migration unknown-key warnings, schema-version-newer-than-runtime warnings, and slot-index-out-of-range warnings all route through `WarningBus.warn`.
- **Sponsor probe** (subjective feel-check): "is the slot-switch + shared-stash interaction comprehensible?" — see §"Sponsor probe targets" below.

**Edge-case probes (5):**

- **EP-RT:** v4 fixture → load under v5 → mutate active character HP → save → reload → bit-identical. Round-trip survives migration boundary.
- **EP-OOO:** `active_slot` saved as `2`, then character 2 deleted → next load: does `active_slot` reset to 0 or stay at `2` (referencing deleted slot)? Design intent: reset to lowest non-empty slot. Verify exact behavior matches Devon's spike spec.
- **EP-DUP:** Two characters with identical names — UID-based, not name-based, so both coexist. Pin uniqueness check via slot-index, not name.
- **EP-INTR:** Save mid-migration (simulated mid-`_migrate_v4_to_v5` interrupt) — partial-migration recovery should re-run migration cleanly on next load. Same shape as v4 INV-7 idempotence guarantee.
- **EP-EDGE:** Migrate a v4 fixture with corrupt/unknown item id in `character.stash` — migration lifts to `shared_stash`, drops the corrupted entry, emits `WarningBus.warn` (universal gate flags it on test runs that don't `expect_warning`). Same surface as v4's `from_save_dict` unknown-id path.

**Integration scenario:**

Player on an M2 W3 build (v4 save) updates to M3 build. First boot: `Save.load_game()` reads `schema_version=4`, runs `_migrate_v4_to_v5`. Existing single character wraps into `characters[0]`; `equipped` lifts from root to `characters[0].equipped`; `character.stash` lifts to root `shared_stash`. `active_slot = 0`. Player opens title screen, sees their existing character in slot 0 + 2 empty slots. Picks Continue → loads hub-town (per §2 below). All M2 progress preserved.

**Sponsor probe target:**

**"Does the M2→M3 upgrade path feel seamless?"** Sponsor loads an M2 save on M3 build — does the slot picker show their character at slot 0 with correct level + stratum-deepest? Does the hub-town load with their shared-stash items + ember-shards (if any)? If Sponsor describes the upgrade as "lost nothing" → migration correct. If Sponsor describes "started over" → migration failure; **P0 fix-forward**.

---

### §2 — Hub-town (Uma direction, Drew impl, Devon save-state)

**Tier 1 dispatch:** §2-T1 (`86c9uth6a`) — Uma authors `team/uma-ux/hub-town-direction.md`. **Tier 2 dispatches:** Drew authors `HubTown.tscn` (single-screen Outer Cloister evolution per `m3-design-seeds.md §2`) + 3 NPC scenes + descent-portal + Devon wires `meta.hub_town_seen` save state + scene-routing logic (post-death load HubTown.tscn not StratumNRoom01.tscn per spike S2 in `m3-tier-1-plan.md`).

**Acceptance criteria (9):**

- **HT-1 — `HubTown.tscn` loads cleanly.** Scene instantiates without errors; `Engine.time_scale` stays 1.0; no mobs spawn; no hazards; ambient music at menu-pad volume per `stash-ui-v1.md §1` rule. Verified via paired GUT in `tests/test_hub_town_scene.gd::test_loads_cleanly` + integration test `tests/integration/test_hub_town_traversal.gd`. **`[PENDING-SPEC]` — gated on `86c9uth6a` direction doc.**
- **HT-2 — 3 NPCs spawn at coordinates from Uma's direction doc.** Vendor / Anvil / Bounty-poster spawn at the documented x,y in `HubTown.tscn`. NPC count + identity asserted via `EXPECTED_NPC_TAGS` constant in the paired test (mirrors `test_stratum1_rooms.gd::EXPECTED_MOB_COUNTS` pattern). **`[PENDING-SPEC]`** — coordinate values lock when Uma's direction doc lands.
- **HT-3 — Vendor interaction opens vendor UI.** Player walks to vendor pawn, presses interact key (likely E or F per `m3-design-seeds.md §2` — Uma's direction doc locks the binding); vendor UI panel opens; UI lists ember-shard-priced gear from the vendor's per-run inventory roll. Verified via paired GUT in `tests/test_hub_town_npcs.gd::test_vendor_opens_ui` + Playwright spec `tests/playwright/specs/hub-town-vendor.spec.ts`. **`[PENDING-SPEC]`.**
- **HT-4 — Anvil interaction opens reroll UI.** Player walks to anvil, presses interact key; reroll UI panel opens; UI shows currently-equipped item with affix-reroll options + ember-shard cost. Per `mvp-scope.md §M3` "crafting/reroll bench" is M3 scope. Verified via paired GUT in `tests/test_hub_town_npcs.gd::test_anvil_opens_reroll_ui`. **`[PENDING-SPEC]`.**
- **HT-5 — Bounty-poster interaction opens bounty UI.** Player walks to bounty-poster, presses interact key; bounty UI panel opens; UI shows currently-active bounty + accept/decline. Per `mvp-scope.md §M3` "bounty quest system" is M3 scope. Verified via paired GUT in `tests/test_hub_town_npcs.gd::test_bounty_opens_ui`. **`[PENDING-SPEC]`.**
- **HT-6 — Descent-portal stratum-selection UI lists S1..deepest_stratum.** Per `m3-design-seeds.md §2 Recommend`, the descent-portal at the south edge replaces the M2 "Down to descend" door. Player walks to portal → stratum-picker UI shows S1, S2, ..., `data.meta.deepest_stratum`. Selecting a stratum loads that stratum's R1. Verified via paired GUT in `tests/test_descent_portal.gd::test_lists_strata_up_to_deepest` + Playwright spec `tests/playwright/specs/hub-town-descent.spec.ts`. **`[PENDING-SPEC]`.**
- **HT-7 — `meta.hub_town_seen` first-visit hint-strip shown then cleared.** Per `m3-design-seeds.md §2 Save-schema implications`, the first-visit hint-strip appears once on the player's first hub-town load (`meta.hub_town_seen=false`), then `meta.hub_town_seen=true` is persisted. Subsequent loads suppress the strip. Verified via paired GUT in `tests/test_hub_town_first_visit.gd::test_hint_strip_first_visit_only`. **`[PENDING-SPEC]`.**
- **HT-8 — B-key + Tab + Esc behaviors consistent with stash-room patterns.** Per `stash-ui-v1.md §1` input rules. B opens hub-town stash chamber; Tab opens inventory; Esc closes any open UI. No new keybinding conflicts vs M2 stash-room. Verified via paired GUT in `tests/test_hub_town_input.gd::test_bktab_esc_behaviors`. **`[PENDING-SPEC]`** — Uma's direction doc may shift binding semantics; locks at direction-doc landing.
- **HT-9 — No combat in hub-town.** `Engine.time_scale` stays 1.0; no `Mob` autoload spawns; no `Hitbox` instances; player swing fires but produces no hits; player HP cannot decrease. Per `stash-ui-v1.md §1`. Verified via paired GUT in `tests/test_hub_town_no_combat.gd::test_no_combat_invariant` + integration regression on the M2 stash-room no-combat surface.

**Verification methods:**

- HT-1..HT-9: paired GUT tests across `tests/test_hub_town_scene.gd`, `tests/test_hub_town_npcs.gd`, `tests/test_descent_portal.gd`, `tests/test_hub_town_first_visit.gd`, `tests/test_hub_town_input.gd`, `tests/test_hub_town_no_combat.gd`.
- HT-3 + HT-6: Playwright specs against the release-build artifact (UI interactions through real input events — the surface GUT cannot exercise).
- **HTML5 visual-verification gate (cross-cutting):** `HubTown.tscn` introduces NEW Sprite2D / Polygon2D / modulate-cascade nodes (3 NPC pawns + anvil prop + vendor stall + bounty board + descent portal). Per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate", the §2 Tier 2 impl PR REQUIRES explicit HTML5 release-build screenshots or short screen-recording in the Self-Test Report. Don't accept "primitives are safe" exemption arguments per the PR #160 precedent.
- **Universal warning gate (cross-cutting):** every GUT test file imports `NoWarningGuard`; every Playwright spec imports from `test-base.ts`. NPC dialogue text / bounty descriptions route through resource-load paths — surface those via `WarningBus.warn` on resource-resolution failure.
- **Sponsor probe** (subjective feel-check): "does the hub-town feel like the right between-runs venue?" + "does the Outer Cloister evolution read as populated-with-purpose, not just S1 with NPCs?"

**Edge-case probes (4):**

- **EP-RT:** Save in hub-town with active bounty → quit → reload → hub-town loads at correct NPC positions + bounty state preserved + ember-shard balance correct.
- **EP-OOO:** Player descends from hub-town to S5 → dies in S5 → respawn loads hub-town (per spike S2 in `m3-tier-1-plan.md`). Same shape as M2 stash-room respawn, but persistent across strata.
- **EP-INTR:** Open vendor UI → click descend portal mid-vendor-UI-open → vendor UI closes cleanly; descent confirmation modal opens; no orphaned UI state.
- **EP-EDGE:** Player walks to descent-portal with `data.meta.deepest_stratum = 0` (no strata cleared yet, fresh M3 character) → portal UI lists only S1; selecting S1 descends correctly.

**Integration scenario:**

Player launches M3, picks Continue on character slot 0 (per §4 title-screen), loads into hub-town for the first time. Hint-strip appears: "Welcome to the Outer Cloister. Vendor west, anvil center, bounty east. Descend south." Player walks to vendor (HT-3), buys a T2 weapon for 80 ember-shards. Walks to anvil (HT-4), rerolls one affix for 50 shards. Walks to bounty-poster (HT-5), accepts "Kill 3 Stratum 2 Stokers." Walks to descent portal (HT-6), selects S2, descends. Plays S2, kills 3 Stokers, returns to hub-town via post-death respawn → bounty marked complete, lore-snippet unlocked, `meta.lore_unlocked` array gets new entry.

**Sponsor probe target:**

**"Is the hub-town the right between-runs venue?"** Subjective; M3 Tier 1 vertical-slice gates this. Pass: Sponsor describes hub-town as "the place I go to plan the next run." Fail: "feels like a menu screen disguised as a room" → Uma's direction doc may need v1.1 nudge (more diegetic / less menu-feel).

---

### §3 — Character-art pass — engineering-acceptance-omitted block

**No engineering acceptance rows here.** Per `m3-tier-1-plan.md §3` and `m3-design-seeds.md §4 Cost-and-time bracket`, the character-art pass is **Sponsor-routed, not engineering**. Acceptance is at **Sponsor-soak-visual-verification time** when sprite-swap PRs dispatch in M3 W3+, not at the GUT / Playwright surface.

**Why omitted:**

1. **External-estimate is the gate.** Sponsor commissions 2-3 pixel-art artist quotes (`86c9uth7g`, lead-time ~2-3 weeks). Until estimates land + artist is picked + cost-bracket committed, there is no §3 implementation work to acceptance-test.
2. **Sprite-swap is mechanically lightweight** (~1-2 dev-hours per mob per `m3-design-seeds.md §4 Asset pipeline`). The integration surface is `Sprite.texture` swap; the `_play_hit_flash` modulate-cascade is preserved. **The combat-architecture invariants from `.claude/docs/combat-architecture.md` § "Mob hit-flash" + the existing paired GUT tests (per-mob `test_grunt_hit_flash.gd` / `test_charger_hit_flash.gd` / etc.) ARE the engineering acceptance for the swap** — no new acceptance rows needed; existing rows assert "the hit-flash works against the new sprite."
3. **Visual fidelity IS Sponsor's call.** "Does the new Grunt sprite read as a Grunt?" is a Sponsor subjective judgment, not a GUT assertion. Per `team/TESTING_BAR.md` § "Visual primitives" — Tier 1 (target color ≠ rest color) + Tier 2 (visible-draw node, not parent CharacterBody2D) carry over from M2; **Tier 3 (framebuffer pixel-delta) remains deferred** pending Devon's renderer-painting CI lane.

**When sprite-swap PRs dispatch (M3 W3+):**

- **Existing per-mob hit-flash GUT pins re-run** against the new Sprite. If `test_grunt_hit_flash.gd::test_grunt_modulates_to_white_then_back_to_rest` flips RED on the swap, the modulate-cascade target node moved (most likely the swap put a `Sprite2D` inside the `CharacterBody2D` with the modulate on the wrong node). Existing tests are the load-bearing regression gate.
- **HTML5 visual-verification gate** triggers per `.claude/docs/html5-export.md`. Every sprite-swap PR includes Sponsor-handoff HTML5 screenshots showing the new sprite at-rest + mid-attack + hit-flashed + dying. Sponsor approves visually before merge.
- **Daltonization re-run** per `palette-stratum-2.md §6` — Uma verifies the new sprites don't collapse in deuteranopia / protanopia / tritanopia against the at-risk-pair list.
- **Aseprite source committed** alongside the exported PNG per `team/uma-ux/visual-direction.md` rule.

**Cross-references for the sprite-swap PRs (when they dispatch):**
- `m3-design-seeds.md §4 Asset pipeline`
- `team/drew-dev/sprite-swap-pipeline.md` (spike S3, M3 W3+ timing per `m3-tier-1-plan.md`)
- `.claude/docs/combat-architecture.md` § "Mob hit-flash"
- `.claude/docs/html5-export.md` § "HTML5 visual-verification gate"

---

### §4 — Title-screen slot-picker (Drew direction → Drew impl + Devon save-wiring)

**Tier 1 dispatch:** §4-T1 (`86c9uth85`) — Drew authors `team/drew-dev/title-screen-slot-picker.md`. **Tier 2 dispatches:** Drew authors `TitleScreen.tscn` slot-picker UI + Devon wires v5 `active_slot` semantics + character-name input flow + delete-confirm hold-to-confirm + keyboard nav.

**Acceptance criteria (10):**

- **TS-1 — Title-screen state correct for 0 saves.** Fresh launch, no save file: title-screen shows 3 empty slot rows; "New Game" button focused; "Continue" button disabled (greyed out). Verified via paired GUT in `tests/test_title_screen.gd::test_state_zero_saves`. **`[PENDING-SPEC]` — gated on `86c9uth85` slot-picker spec.**
- **TS-2 — Title-screen state correct for 1 save.** v5 save with `characters` array containing 1 character + 2 empty slots: title-screen shows 1 populated row (name + level + stratum-deepest + last-played-relative-time) + 2 empty rows; "Continue" focused on the populated row; "New Game" button enabled. Verified via paired GUT in `tests/test_title_screen.gd::test_state_one_save`. **`[PENDING-SPEC]`.**
- **TS-3 — Title-screen state correct for 2 saves.** 2 populated rows + 1 empty row; "Continue" focused on `data.active_slot`. Verified via paired GUT in `tests/test_title_screen.gd::test_state_two_saves`. **`[PENDING-SPEC]`.**
- **TS-4 — Title-screen state correct for 3 saves (full).** 3 populated rows + 0 empty; "Continue" focused on `data.active_slot`; "New Game" button disabled with tooltip "All slots full — delete a slot to create a new character." Verified via paired GUT in `tests/test_title_screen.gd::test_state_three_saves_full` + see TS-8 below. **`[PENDING-SPEC]`.**
- **TS-5 — New Game flow → name input → confirm → load into hub-town.** Player clicks "New Game" → empty slot selected → name input modal opens → types name → confirms → `characters[N]` populated with default-payload + name → loads `HubTown.tscn` (per §2 HT-1) + `meta.hub_town_seen=false` (so HT-7 hint-strip fires). Verified via paired GUT in `tests/test_title_screen.gd::test_new_game_flow` + Playwright spec `tests/playwright/specs/title-screen-new-game.spec.ts`. **`[PENDING-SPEC]`.**
- **TS-6 — Continue flow loads correct character + correct scene per `meta.last_scene`.** Player clicks "Continue" → `active_slot` character loads → `meta.last_scene` (hub-town OR mid-stratum scene if mid-run save) loads at correct save-state. Verified via paired GUT in `tests/test_title_screen.gd::test_continue_flow_hub` + `test_continue_flow_mid_run` + Playwright spec. **`[PENDING-SPEC]`.**
- **TS-7 — Delete flow hold-to-confirm 1.5s.** Player clicks Delete on a populated slot → confirmation appears → must hold for 1.5s to confirm (per `m3-design-seeds.md §1` safety pattern); releasing before 1.5s aborts; releasing after 1.5s deletes the slot from `data.characters[]` array. Verified via paired GUT in `tests/test_title_screen.gd::test_delete_hold_to_confirm` + Playwright spec timing assertion (release-build clock-time, not virtual time). **`[PENDING-SPEC]`.**
- **TS-8 — 3-slot-full disables New Game button + shows tooltip.** Cross-references TS-4. New Game button is disabled (not clickable, visually greyed) + hover tooltip explains the disable reason. Verified via paired GUT in `tests/test_title_screen.gd::test_new_game_disabled_when_full`. **`[PENDING-SPEC]`.**
- **TS-9 — Keyboard nav arrow + Enter works.** Arrow keys move focus between slot rows; Enter confirms; Esc on title-screen has no effect (no escape route). Per `m3-design-seeds.md` keyboard-first input rule (carries from `visual-direction.md`). Verified via paired GUT in `tests/test_title_screen.gd::test_keyboard_nav` + Playwright spec for the canonical user-input surface. **`[PENDING-SPEC]`.**
- **TS-10 — Mouse-click works as secondary input.** Per `m3-design-seeds.md` "mouse-click supported but secondary per visual-direction's keyboard-first rule" — click on slot row also selects it; click on button activates. Verified via Playwright spec `tests/playwright/specs/title-screen-mouse.spec.ts`. **`[PENDING-SPEC]`.**

**Verification methods:**

- TS-1..TS-4 + TS-8: paired GUT against `tests/test_title_screen.gd` covering the state-vs-save-count matrix.
- TS-5..TS-7 + TS-9..TS-10: paired GUT + Playwright spec (the UI-interaction surface). Playwright covers real input events the GUT surface cannot drive.
- **Drift-pin HARD RULE (cross-cutting):** Any Playwright spec asserting on `[combat-trace]` or `[title-trace]` lines containing free-form interpolated values (e.g., `slot=N`, `state=new_game_flow`, `flow=continue`) MUST pair with a GUT drift-pin per `team/tess-qa/playwright-harness-design.md §17`. If `TitleScreen.gd` defines `STATE_NEW_GAME_FLOW: StringName = &"new_game_flow"` and a spec asserts `state=new_game_flow`, the drift-pin lives in `tests/test_playwright_trace_string_contract.gd` (or a new title-screen-scoped test file). **Pin-pair gate:** any new title-screen Playwright spec without a paired drift-pin is REQUEST CHANGES in code review.
- **Universal warning gate (cross-cutting):** every GUT test file uses `NoWarningGuard`; every Playwright spec imports from `test-base.ts`.
- **Sponsor probe** (subjective feel-check): "is the title-screen comprehensible?" — first M3 thing Sponsor sees on launch.

**Edge-case probes (5):**

- **EP-RT:** Create character at slot 1, save, quit. Relaunch → title shows correct state with slot 1 populated (not slot 0). `active_slot=1`.
- **EP-OOO:** v4 save loaded under v5 (per SV5-1) → title-screen treats the migrated single character as slot 0, populated row 0. Default behavior; verify it isn't surprising.
- **EP-DUP:** Two slots with identical character names — both rows render with name + slot-index differentiator; not a UI crash. Slot-index is the load-bearing identifier.
- **EP-INTR:** Delete-confirm hold timer started → press Esc mid-hold → hold aborts cleanly, no slot deletion. Same shape for click-and-drag-away from button mid-hold.
- **EP-EDGE:** Click New Game with 3 slots full → button is disabled per TS-8; click is no-op (no error sound, no flash, no broken state). Hover tooltip is the only feedback.

**Integration scenario:**

Player launches M3 fresh. Title-screen shows 3 empty slots + "New Game" focused. Player presses Enter → name input modal → types "Aldric" → confirms → slot 0 populated with default-payload character named Aldric → `HubTown.tscn` loads with hint-strip per HT-7. Player plays for an hour, saves at slot 0. Quits. Relaunches. Title-screen shows Aldric in slot 0 + 2 empty rows. Presses Continue → loads back into hub-town at save-state.

Later: player has 3 characters (Aldric / Brigid / Caelan, slots 0/1/2). New Game button is disabled per TS-8. Hovers → tooltip explains. Player deletes Caelan (TS-7 1.5s hold), New Game button re-enables, creates 4th character at the now-empty slot 2.

**Sponsor probe target:**

**"Is the title-screen comprehensible at first glance?"** Sponsor launches M3 fresh — does the slot-picker shape immediately convey "this is where my characters live"? Pass: Sponsor describes "I get what to do." Fail: "what are these rows for?" → Drew's slot-picker spec needs v1.1 nudge (more diegetic framing, less abstract row UI).

---

## §QA scaffold — meta-acceptance for THIS doc

The scaffold doc itself has acceptance criteria so it can be QA'd at PR-merge time.

**Acceptance criteria (3):**

- **QA-SCAFFOLD-1 — Doc lands on main.** This PR merges, `team/tess-qa/m3-acceptance-plan-tier-1.md` is present on `origin/main` HEAD. Verified by `gh pr merge` completion.
- **QA-SCAFFOLD-2 — All sub-milestone sections present with placeholder rows.** §1 (SV5-1..SV5-8), §2 (HT-1..HT-9), §4 (TS-1..TS-10), §3 (omitted-row block with rationale), §QA (QA-SCAFFOLD-1..QA-SCAFFOLD-3). Verified by grep of the on-disk file.
- **QA-SCAFFOLD-3 — Cross-references intact.** All cited paths (`team/priya-pl/m3-tier-1-plan.md`, `team/priya-pl/m3-design-seeds.md`, `team/tess-qa/m2-acceptance-plan-week-3.md`, `team/tess-qa/playwright-harness-design.md`, `team/priya-pl/ac4-white-whale-retro.md`, `.claude/docs/test-conventions.md`, `.claude/docs/html5-export.md`, `.claude/docs/combat-architecture.md`) resolve to files on `main` at scaffold-merge time. Verified by grep + Tess pre-merge spot-check.

---

## Cross-cutting concerns

Six concerns cut across all three engineering pillars (§1 / §2 / §4). Each is a HARD GATE for any Tier 2 dispatch in that pillar.

### CC-1 — Save-schema v4→v5 regression-pin compatibility

Every Tier 2 PR in any pillar that touches save-state must demonstrate `Save.load_game()` on a v4 fixture (from `tests/fixtures/v4/`) succeeds + the migration runs idempotently. This is the cross-pillar floor — §1 owns it primarily, but §2 (hub-town save state `meta.hub_town_seen` / bounty state) and §4 (`active_slot` semantics + character-name persistence) both intersect.

**Gate:** every Tier 2 save-touching PR's Self-Test Report includes `gut tests/test_save_migration_v5.gd` green output + an INV-7-style idempotence assertion specific to the new fields the PR introduces.

### CC-2 — AC4 spec regression-pin (M3 mustn't break AC4 green)

Playwright `tests/playwright/specs/ac4-boss-clear.spec.ts` is the canonical M2 play-loop regression gate. **No M3 Tier 1 / Tier 2 PR may merge if its release-build artifact run produces a red AC4 spec.** This is the "and prior milestones' ACs still pass" floor codified as a hard gate.

**Gate:** every M3 Tier 2 dispatch brief must include a Regression-guard line citing `ac4-boss-clear.spec.ts` (or a more-specific sub-spec) as the named regression-protection surface, per PR #216's Regression-guard gate. Tess journey-probe at RC boundary verifies AC4 green before Sponsor handoff per `team/TESTING_BAR.md` § "Milestone-gate journey probe."

### CC-3 — Universal warning gate (Phase 2A on main)

Per `.claude/docs/test-conventions.md` and PR #244 (Phase 2A migration of all existing specs to `test-base.ts`):

- **Every new M3 Playwright spec MUST import from `tests/playwright/fixtures/test-base.ts`**, not from `@playwright/test`. The `afterEach` fixture filters for `/USER WARNING:|USER ERROR:/` and fails the test on any match.
- **Every new M3 GUT test MUST attach a `NoWarningGuard` in `before_each` and call `assert_clean(self)` in `after_each`.** Required for any test exercising save-load, content-resolution (NPC dialogue assets, item-id resolution, sprite-resource loading), or mob-registry surfaces.
- **Source-side migration of `push_warning` → `WarningBus.warn` is required for new load-bearing surfaces.** §1 (save-schema v5 migration warnings) + §2 (NPC dialogue resource-resolution warnings) + §4 (slot-data validation warnings) are all candidates. Route through `WarningBus.warn(text, category)` from day one so the guard catches regressions automatically.

**Gate:** any new M3 spec without the test-base import OR any new GUT test without `NoWarningGuard` attach is REQUEST CHANGES in code review.

### CC-4 — Drift-pin HARD RULE for free-form engine-emit strings (§17)

Per `team/tess-qa/playwright-harness-design.md §17` (Tess-authored in PR #252):

> Any Playwright spec assertion whose regex captures a free-form string interpolated from an engine-side `StringName` / `String` constant MUST be paired with a GUT drift-pin asserting the constant's string value.

M3 surfaces the rule on three lanes simultaneously:

- **§1:** `Save.SCHEMA_VERSION` literal values + migration log lines (`[Save] migrating v4→v5`, `[Save] active_slot=N`). Any Playwright spec asserting on these via regex needs a GUT drift-pin in `tests/test_playwright_trace_string_contract.gd` (or a save-scoped test file).
- **§2:** Hub-town NPC interaction trace lines (`[hub-trace] Vendor.interact source=keyboard`, `[hub-trace] Anvil.reroll affix=fire_dmg cost=50`). NPC names + source tags + affix ids are all free-form interpolations.
- **§4:** Title-screen flow trace lines (`[title-trace] TitleScreen.new_game_flow slot=N`, `[title-trace] TitleScreen.continue_flow slot=N target_scene=hub_town`). Flow-state-names + scene-target-names are free-form.

**Gate:** any new Playwright spec asserting on a free-form `<noun>=<value>` regex without a paired `assert_eq(String(<const>), "<literal>", ...)` GUT drift-pin is REQUEST CHANGES, citing `playwright-harness-design.md §17` + the original audit at `team/tess-qa/playwright-drift-audit-2026-05-16.md`.

### CC-5 — HTML5 visual-verification gate triggers

Per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate", any M3 PR touching the following triggers the gate:

- **Tween / modulate / Polygon2D / CPUParticles2D / Area2D-state code paths** — §2 hub-town's NPC pawns + props + descent portal almost certainly hit modulate-cascade; §4 title-screen slot-row hover-affordances may hit modulate.
- **NEW Sprite2D nodes with non-trivial visual identity** — §2 hub-town NPC pawns (3 new sprites) trigger the gate even if they're stand-in placeholders.
- **NEW scene-tree composition** — `HubTown.tscn` (§2) + `TitleScreen.tscn` extension (§4) are net-new scenes that must boot cleanly under `gl_compatibility`.

**Gate:** PRs that trigger require explicit HTML5 release-build screenshots or a short screen-recording in the Self-Test Report. The "primitives are safe" exemption argument is NOT accepted per PR #160 precedent (Tess's review caught it; required HTML5 spot-check before merge).

### CC-6 — Retrospective-pause trigger after N=3 consecutive cluster dispatches (AC4 retro Gap 3)

Per `team/priya-pl/ac4-white-whale-retro.md §3 Gap 3` (now codified as risk-register entry R-AC4):

> After N=3 consecutive AC4-cluster dispatches without spec-closure, **mandatory retrospective pause** before dispatch N+1. Priya owns the pause-trigger. Output: either "spec is correctly-shaped and we keep going" OR "spec needs restructuring; here's a smaller / different probe that would catch the same bug class with less cost."

**M3 application:** the same trigger applies to **any Tier 1 / Tier 2 pillar's spec cluster**. If any pillar (§1 save-v5, §2 hub-town, §4 title-screen) takes 3 consecutive dispatches without closing its acceptance rows, Priya triggers a retrospective pause before dispatch N+1.

**Gate:** orchestrator + Priya monitor the dispatch count per pillar. Tess flags to Priya when any pillar hits the N=3 threshold. The pause is short (one-page audit doc, ~1-2 ticks); it is NOT a milestone-blocker — it's an iteration-cost mitigation.

---

## AC4-retro lessons baked in

Four explicit baked-in lessons from `team/priya-pl/ac4-white-whale-retro.md`:

### Lesson 1 — Self-Test Report sample-size discipline ≥8 release-build runs (Gap 1)

**Pattern from retro:** PR #198 "Room 05 unwinnable" (1 sample), PR #208 "Room 05 3/3 deterministic" (3 samples), PR #241 "Finding 2 Class A" (1 pattern-match against prior PR #232) — all three were empirically refuted by subsequent diagnostic-trace passes with larger samples. **N=1 or N=3 is hypothesis-generation evidence, not acceptance evidence.**

**Baked in:** any M3 Tier 2 dispatch that delivers a stochastic-cost spec (Playwright spec that traverses through combat / RNG / multi-mob rooms) MUST cite ≥8 release-build runs in the Self-Test Report. Specifically applies to:

- **§4 TS-7** (delete-flow hold-timing) — clock-time assertions on Playwright are non-deterministic; ≥8 runs verify the 1.5s threshold isn't flaky.
- **§2 HT-6** (descent-portal stratum-selection) — multi-stratum traversal may interact with the AC4 cluster's bug classes; ≥8 runs validate non-flake.
- Any pillar-specific Playwright spec authored against hypothesis (without prior diagnostic-trace baseline) — ≥8 runs required.

**Tess REQUEST CHANGES bar:** Self-Test Report citing fewer than 8 release-build runs for a stochastic spec is REQUEST CHANGES. Pin to `TESTING_BAR.md` § "Statistical bar for stochastic-cost specs" once Priya codifies it.

### Lesson 2 — Instrument-first dispatches for hypothesis-cluster bugs (Gap 2)

**Pattern from retro:** `diagnostic-traces-before-hypothesized-fixes` memory rule was authored AFTER ~5 misdiagnosis-cost iterations. PR #198, PR #208, PR #212-as-originally-framed all shipped fixes against unverified hypotheses. PR #241 Class A fix was insufficient for Class B because diagnostic instrumentation hadn't preceded the fix dispatch.

**Baked in:** any M3 Tier 2 dispatch brief for a bug-fix or behavior-uncertain ticket MUST include an explicit "instrument plan" line. If a Tier 2 PR ships a fix for a bug whose cause was hypothesized (not trace-confirmed), the PR body must include the instrumentation `[combat-trace]` / `[hub-trace]` / `[title-trace]` evidence + the empirical observation that confirms the hypothesis.

**Tess REQUEST CHANGES bar:** any M3 Tier 2 bug-fix PR without instrumentation evidence in the PR body is REQUEST CHANGES, citing `diagnostic-traces-before-hypothesized-fixes` memory + AC4-retro §3 Gap 2.

### Lesson 3 — N=3 retrospective-pause trigger (Gap 3)

See CC-6 above. **Cross-listed here** because it's a baked-in AC4-retro lesson AND a cross-cutting concern.

### Lesson 4 — Drift-pin GUT pairs for every new Playwright spec (Gap 4)

See CC-4 above. **Cross-listed here** because it's the AC4 retro's most-concerning gap ("Gap 4 is a mitigation against CI itself silently lying") AND a cross-cutting concern. The drift-pin pattern is now Tess-codified in `playwright-harness-design.md §17` and applied unconditionally to every M3 spec.

---

## Test fixture catalog

Tier 2 dispatches under §1 will land save-fixture files under `tests/fixtures/v5/`. Anticipated set (locks at Devon's v5 spike landing):

- `save_v4_full_stash_72_slots_to_v5.json` — v4 fixture from W3-T6, migrated to v5 in-test.
- `save_v5_three_characters_max.json` — 3 fully-populated characters + maximal shared_stash + maximal per-character ember-shards.
- `save_v5_active_slot_pointing_at_empty.json` — edge case: `active_slot=2` but `characters[2]` is null (post-delete).
- `save_v5_html5_opfs_baseline.json` — minimal v5 envelope, OPFS round-trip baseline.
- `save_v5_html5_opfs_max.json` — maximal v5 envelope, OPFS stress test.
- `save_v5_idempotent_double_migration.json` — already-v5 data, double-migration is no-op.
- `save_v5_unknown_keys_passthrough.json` — forward-compat fields preserved through round-trip.

Devon co-authors the fixtures during the v5 Tier 2 impl. Tess co-validates against the SV5-* acceptance rows.

---

## Paired-test file index — M3 NEW (anticipated)

This scaffold doesn't author paired-test stubs (the W3 pattern of `pending()` stubs is heavier than necessary for this scaffold's role). Anticipated files Tess authors when the corresponding Tier 2 PR lands:

| File | Purpose | Pillar |
|---|---|---|
| `tests/test_save_migration_v5.gd` | Pin SV5-1..SV5-5 round-trip + idempotence + shared_stash lift | §1 |
| `tests/test_ember_shards_per_character.gd` | Pin SV5-7 ember-shard per-character isolation | §1 |
| `tests/test_paragon_per_character.gd` | Pin SV5-8 paragon-per-character isolation | §1 |
| `tests/test_save_v5_html5_stress.gd` | Pin SV5-6 + OPFS three-character stress | §1 |
| `tests/test_hub_town_scene.gd` | Pin HT-1 scene load + no-combat | §2 |
| `tests/test_hub_town_npcs.gd` | Pin HT-2..HT-5 NPC spawn + interaction UI | §2 |
| `tests/test_descent_portal.gd` | Pin HT-6 stratum-selection UI | §2 |
| `tests/test_hub_town_first_visit.gd` | Pin HT-7 `meta.hub_town_seen` first-visit gate | §2 |
| `tests/test_hub_town_input.gd` | Pin HT-8 B + Tab + Esc input semantics | §2 |
| `tests/test_hub_town_no_combat.gd` | Pin HT-9 no-combat invariant | §2 |
| `tests/test_title_screen.gd` | Pin TS-1..TS-9 state matrix + flows + nav | §4 |
| `tests/playwright/specs/hub-town-vendor.spec.ts` | Playwright HT-3 vendor UI exercise (with drift-pin pair) | §2 |
| `tests/playwright/specs/hub-town-descent.spec.ts` | Playwright HT-6 descent-portal exercise (with drift-pin pair) | §2 |
| `tests/playwright/specs/title-screen-new-game.spec.ts` | Playwright TS-5 new-game flow (with drift-pin pair) | §4 |
| `tests/playwright/specs/title-screen-mouse.spec.ts` | Playwright TS-10 mouse-click secondary input | §4 |

Specs marked "with drift-pin pair" require an entry in `tests/test_playwright_trace_string_contract.gd` (or a new pillar-scoped contract file) per CC-4. Authoring trigger: when the corresponding Tier 2 PR lands the production code under test.

---

## Sponsor probe targets (M3 Tier 1 vertical slice)

When M3 Tier 1 vertical slice ships (post-Tier-2 §1 + §2 + §4 — likely M3 W3-W4 RC), Sponsor's interactive soak evaluates:

1. **M2→M3 upgrade-path seamlessness** (§1 SV5-1..SV5-3). Sponsor loads an M2 save on M3 build. Pass: "I haven't lost anything." Fail: "I started over" → migration P0 fix-forward.
2. **Hub-town as between-runs venue** (§2 HT-1..HT-9). Sponsor walks the hub-town, interacts with all 3 NPCs, descends to S1, dies, returns to hub-town. Pass: "this is where I plan the next run." Fail: "feels like a menu" → Uma's direction doc v1.1.
3. **Title-screen first-glance comprehension** (§4 TS-1..TS-10). Sponsor launches M3 fresh, creates a character, plays an hour, quits. Relaunches. Pass: "I get what to do." Fail: "what are these rows for?" → Drew's slot-picker spec v1.1.
4. **Multi-character feel** (§1 SV5-4..SV5-5 + §4 TS-5..TS-7). Sponsor creates a 2nd character, switches between slots, verifies shared-stash works across both. Pass: "switching characters feels right." Fail: "stash is confusing across slots" → §1 shared-stash UI v1.1 (extension of stash-ui-v1.md).
5. **Persistent meta progression** (§1 SV5-7..SV5-8). Sponsor accumulates ember-shards across runs + spends at anvil + accumulates Paragon points. Pass: "between-run progress feels real." Fail: "shards / Paragon don't matter" → balance pin (§3 Paragon balance, escalate to Priya for design pin).

**Top 3 priority for first M3 Tier 1 vertical slice soak:** #1 (migration seamlessness — P0 if it fails), #2 (hub-town feel), #3 (title-screen comprehension). #4 + #5 are polish; revisit at Tier 2 close.

---

## HTML5 audit re-run pattern (M3 Tier 1 RC)

When the M3 Tier 1 vertical-slice RC artifact lands (post-Tier-2 §1+§2+§4), it gets the same Playwright + Sponsor-soak audit pattern M2 used. Audit document: `team/tess-qa/html5-rc-audit-<short-sha>.md` (template per `team/tess-qa/html5-rc-audit-591bcc8.md`).

**New testable invariants for M3 (TI-23..TI-30 extension of `tests/integration/test_html5_invariants.gd`):**

- **TI-23:** `Save.SCHEMA_VERSION == 5` constant exists + reads correct (analog of M2 TI-16 pattern).
- **TI-24:** `Save._migrate_v4_to_v5(v4_data)` returns a Dictionary with `data.characters: Array[Dictionary]` of size ≥1.
- **TI-25:** `HubTown.tscn` instantiates without error in headless GUT (smoke).
- **TI-26:** `Engine.time_scale` is 1.0 throughout `HubTown.tscn` lifetime.
- **TI-27:** `TitleScreen.tscn` instantiates without error in headless GUT + renders 3 slot rows (smoke).
- **TI-28:** `data.characters` array allows 0..3 entries; 4th entry attempt is rejected with `WarningBus.warn` (universal gate flags it).
- **TI-29:** OPFS round-trip of `save_v5_three_characters_max.json` survives bit-identical (Sponsor HTML5 soak; documented as probe target if no headless-browser GUT runner).
- **TI-30:** `data.shared_stash` is a single Array (not a Dictionary keyed by slot); item UIDs unique across all loaded saves.

---

## Hand-off

- **Devon:** §1 Tier 2 (v5 migration impl, multi-character slot data, shared_stash lift, ember-shards, Paragon, active_slot semantics). All SV5-* acceptance rows lock at Devon's v5 spike PR-merge time (`86c9uth5h`). Per-PR sign-offs against the SV5-* rows.
- **Drew:** §2 Tier 2 (`HubTown.tscn` authoring + 3 NPC scenes + descent-portal scene) gated on Uma's direction doc landing (`86c9uth6a`). §4 Tier 2 (`TitleScreen.tscn` slot-picker UI) gated on his own §4-T1 spec landing (`86c9uth85`) + Devon's v5 spike landing. Per-PR sign-offs against HT-* and TS-* rows.
- **Uma:** §2 Tier 1 (hub-town direction doc `86c9uth6a`); §3 visual hand-off to artists post-commission. Daltonization re-runs at sprite-swap PR review per `palette-stratum-2.md §6`.
- **Tess:** this scaffold + ongoing fill-in as Tier 1 design docs land + Playwright spec authoring (with drift-pin pairs) at Tier 2 + journey-probe at M3 Tier 1 RC boundary per `team/TESTING_BAR.md` § "Milestone-gate journey probe."
- **Priya:** §QA scaffold review + N=3 retrospective-pause trigger ownership (CC-6) + M3 risk-register refresh as Tier 1 docs land + M3 Tier 1 retro authoring at M3 Tier 1 close.
- **Sponsor:** §3 external-estimate commission (`86c9uth7g` brief landing → Sponsor sends to 2-3 artists, ~2-3 wk lead time) + the 5 probe targets above + final M3 Tier 1 vertical-slice sign-off.

---

## Caveat — parallel scaffold, not Tier 1+ lock

This doc is the M3 Tier 1 parallel-acceptance scaffold (mirrors M2 W3-T10 Half A idiom — drafted at Tier 1 day-1, before Tier 2 impl PRs have opened). Revisions land as v1.1 commits when:

- Devon's v5 spike (`86c9uth5h`) lands and SV5-1..SV5-8 rows lock against the spike's specifics (pointer-shadow decision, migration step order, OPFS implications).
- Uma's hub-town direction (`86c9uth6a`) lands and HT-1..HT-9 rows lock against the direction's NPC coordinates, input bindings, descent-portal positioning.
- Drew's slot-picker spec (`86c9uth85`) lands and TS-1..TS-10 rows lock against the spec's state diagram, flow shapes, keyboard bindings.
- Sponsor redirects a `m3-design-seeds.md` default (slot count, hub-town size, NPC count, etc.) — the relevant rows absorb the diff.
- An integration surface emerges that wasn't anticipated (likely candidates: hub-town↔stratum-routing race on respawn, slot-switch mid-run conflict, shared-stash UID collision across slots).

The 3-pillar coverage + 27 acceptance row pinning + 6 cross-cutting concerns is the **path of least resistance from M3 Tier 1 dispatch → M3 Tier 1 vertical-slice sign-off.** It is not the only path.

---

## Cross-references

- `team/priya-pl/m3-tier-1-plan.md` — Tier 1 sub-milestone shape + 5 first-wave tickets
- `team/priya-pl/m3-design-seeds.md` — Shape A 4-track feature surface + 15 Sponsor-input items
- `team/priya-pl/m3-shape-options.md` — Shape A locked 2026-05-17
- `team/priya-pl/mvp-scope.md §M3` — canonical content-track scope contract
- `team/tess-qa/m2-acceptance-plan-week-3.md` — structural template (M2 W3 acceptance plan; ~67 rows for 12 tickets)
- `team/tess-qa/playwright-harness-design.md §14, §15, §16, §17` — staleness-bounded latestPos, harness-workaround-fail-loud, `test.fail()` canary semantics, drift-pin HARD RULE
- `team/priya-pl/ac4-white-whale-retro.md` — four structural gaps baked in as cross-cutting concerns + lessons
- `team/devon-dev/save-schema-v4-plan.md` — v4 source of truth; v5 extends + first violates `§4.1` additive-only
- `.claude/docs/test-conventions.md` — universal warning gate (GUT + Playwright surfaces)
- `.claude/docs/html5-export.md` — HTML5 visual-verification gate triggers
- `.claude/docs/combat-architecture.md` § "Mob hit-flash" — integration surface §3 sprite-swap must preserve

---

## Non-obvious findings

1. **§3 character-art pass is structurally exempt from engineering-acceptance rows.** Most M-acceptance-plan patterns (M1, M2 W1, M2 W3) had every ticket pin to engineering rows. M3 §3 inverts this — the art-pass is Sponsor-routed estimate work followed by sprite-swap PRs whose engineering invariant is "the existing hit-flash GUT pin still works against the new sprite." This is a **structural shift** in how an M-acceptance-plan covers a milestone-feature; documenting the omission with rationale (rather than silently skipping) is itself the QA contract.
2. **AC4 retro Gap 4 (drift-pin HARD RULE) is the most load-bearing baked-in lesson.** The other three gaps (sample-size, instrument-first, retrospective-pause) are author-discipline mitigations; Gap 4 is a CI-trust mitigation. If M3 ships specs without drift-pin pairs, the AC4 cluster's silent-pass pattern WILL recur in M3 — the team has no other structural defense against engine-emit drift.
3. **The 6 cross-cutting concerns + 4 baked-in lessons partially overlap by design.** CC-3 (universal warning gate) + Lesson 4 (drift-pin) + CC-4 (drift-pin) cross-list intentionally so reviewers can find the gate from either entry point (concern-driven OR retro-lesson-driven). The duplication is the affordance.
4. **N=3 retrospective-pause is the first proactive process-discipline gate in M-acceptance-plan history.** M1 / M2 acceptance plans were reactive (define ACs, await impl, sign off). The N=3 trigger codifies pause-before-N+1 as a forcing function. If M3 ships without invoking N=3 even once, that's a signal that either (a) the pillar-clusters were correctly-shaped from inception (best case) or (b) the trigger threshold should be lowered to N=2 (calibration data).
5. **Tess can author Playwright specs against the design-doc-stated behavior NOW with `test.fail()`** — the AC4 spec convention from M1 (author the spec as `test.fail()` annotated blocker before impl exists; flip to `test()` when impl lands) lifts cleanly to M3. The HT-* and TS-* spec stubs can land in parallel to Devon's v5 spike + Uma's direction doc + Drew's slot-picker spec, providing immediate dispatch-ready specs the Tier 2 PRs run against.

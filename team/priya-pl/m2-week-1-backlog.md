# M2 Week-1 Backlog (DRAFT — anticipatory)

**Owner:** Priya · **Tick:** 2026-05-02 (M1 feature-complete on `main` tip `4425ba4`; Sponsor's interactive soak is the gating activity for sign-off) · **Status:** DRAFT — revisable post-Sponsor M1 sign-off.

This document is **anticipatory planning**. Goal: when Sponsor signs off M1, the team can start M2 immediately without a planning gap. The week-2 retro (`team/priya-pl/week-2-retro-and-week-3-scope.md`) framed Half-B (B1–B4) as the M2-onset design layer; B1, B3, B4 shipped (Uma stash UI v1, Uma stratum-2 palette, Devon save-schema-v4 plan), and B2 (Drew's stratum-2 chunk-lib scaffold) just landed in `main`. **This backlog is the M2 implementation layer that consumes those four design docs.**

The backlog is a draft, not a contract. If Sponsor's soak surfaces M1 bouncing that adjusts M2 scope (e.g., a death-rule tweak, a stash-affordance pushback), this doc gets a v1.1 revision. Drafting now means the team isn't idle in the gap between sign-off and dispatch.

## TL;DR (5 lines)

1. **Target:** **12 tickets** for M2 week-1 (10 P0 + 2 P1 stretch). Same shape as week-3 ceiling (~12 — within the 16+2 / 8+7=15 throughput envelopes).
2. **Expected duration:** ~one M2 week (~10–14 ticks active orchestration, parallels week-3 close-out cadence).
3. **Critical chain:** save-schema v4 impl → SaveSchema autoload → stash UI impl → ember-bag pickup → death-recovery flow. Each link unlocks the next; no parallel shortcut.
4. **Stratum-2 content track is parallel** to the stash/save chain (Drew's sprite + chunk + boss-substitute work doesn't touch save schema).
5. **Sponsor-input items:** zero blocking pre-conditions (M1 sign-off is the gate). Two soft asks (open question 4 from Devon's save-schema-v4-plan, open question 1 from Uma's stash-ui-v1) will surface during M2 implementation, not before — flagged in §7 below.

---

## Source of truth

This backlog consumes the following Half-B M2-onset design docs:

1. **`team/uma-ux/stash-ui-v1.md` (W3-B1, PR #82, merged)** — 12×6 stash grid, B-key context binding in stash room, pickup-at-death-location ember-bag variant, death-recovery flow screens (Beats A–F + Stash Room Entry beat), schema v3→v4 surface, ST-01..ST-28 acceptance shape.
2. **`team/uma-ux/palette-stratum-2.md` (W3-B3, PR #86, merged)** — Cinder Vaults biome, Cinder-Rust palette (12 stratum-specific hex codes), 5 hard-need + 5 soft-retint sprite tasks, lighting model (CanvasModulate + vignette deepen + vein-pulse anim), S2-PL-01..S2-PL-15 acceptance shape.
3. **`team/devon-dev/save-schema-v4-plan.md` (W3-B4, PR #84, merged)** — additive-only v3→v4 (`character.stash` + `character.ember_bags` + `character.stash_ui_state`), `_migrate_v3_to_v4` has()-guarded backfill, INV-1..INV-8 round-trip invariants, six v3 fixtures catalogued for Tess, SaveSchema.gd autoload sketched (forward-compat).
4. **`team/drew-dev/level-chunks.md` § "Multi-stratum tooling (M2 scaffold)" (W3-B2, merged)** — `Stratum` namespace, `MultiMobRoom` rename, M2 implementer checklist (s2 chunks → s2 mob TRES → s2 scenes → s2 boss room → mob_id resolution → stratum descent → save schema → tests), folder layout recommendation (`resources/mobs/s2/...` etc.).

Plus DECISIONS.md M2 commitments:

- **2026-05-02 — M1 death rule** (DECISIONS.md line 187) — "M2 introduces a stash UI + an 'ember-bag' gear-recovery pattern at the death point." This backlog turns that promise into ticket-shape work.
- **2026-05-02 — Save schema v3 → v4 design locked** (DECISIONS.md line 353) — implementation explicitly deferred to M2; this backlog schedules it.
- **2026-05-02 — Stash UI v1 design locked** (DECISIONS.md line 351) — same disposition.
- **2026-05-02 — Stratum-2 biome locked: Cinder Vaults** (DECISIONS.md line 355) — same disposition.

The M1 acceptance contract (`team/priya-pl/mvp-scope.md` v1-frozen) is the floor. **Nothing in this backlog regresses an M1 AC.** Tess's M2 acceptance test plan (T6 below) verifies M1 ACs continue to pass under the v4 runtime as a side-effect of every migration test.

---

## Pre-conditions

What must be true before M2 week-1 dispatch begins. **All gates external to this doc**; this backlog cannot self-start.

1. **Sponsor M1 sign-off is signed.** If Sponsor's interactive 30-min soak on the M1 RC returns blockers/majors, this backlog is **paused** while the team runs the post-soak fix-forward loop (`86c9kxx7h` bug-bash, R6 mitigation in risk register). Resume only when Sponsor explicitly signs the M1 RC.
2. **Bug-bash `86c9kxx7h` complete.** Even after Sponsor sign-off, the bug-bash ticket is the recovery channel for any deferred M1 polish bugs Tess flagged but Sponsor didn't gate on. M2 work doesn't dispatch with bug-bash open — bug-bash drains first, then M2 starts.
3. **Stratum-2 chunk-lib scaffold (Drew W3-B2) on `main`.** Confirmed ✔ — the scaffold landed and the `Stratum` namespace + `MultiMobRoom` rename are baseline infrastructure for T4–T6 below.
4. **Save schema v4 plan on `main`.** Confirmed ✔ (PR #84 merged; SCHEMA_VERSION still at 3 in `Save.gd`, but spec is authoritative for Devon's M2 dispatch).
5. **Stash UI v1 design on `main`.** Confirmed ✔ (PR #82 merged).
6. **Stratum-2 palette authoritative on `main`.** Confirmed ✔ (PR #86 merged; Uma's 2026-05-02 audio-direction v1.1 nudge for `mus-stratum2-bgm` is open as an unrelated PR but doesn't block this backlog).

**Conditional revisions if Sponsor's soak surfaces specific issues:**

- **If Sponsor pushes back on the death rule** (e.g., "lose level on death too" or "don't lose unequipped — auto-return") — T7 (ember-bag pickup) gets re-scoped or paused; the rest of the backlog continues. The death rule lock is in DECISIONS.md, so a change requires an explicit DECISIONS.md amendment + Uma stash-ui-v1.md v1.1.
- **If Sponsor pushes back on stash discoverability or the B-binding** — T3 (stash UI impl) absorbs the affordance change; ticket scope grows but order doesn't shift.
- **If Sponsor surfaces a save-corruption case in the M1 soak** — T1 (save schema migration impl) gets a defensive-guard sweep added to the scope; INV-* invariants stay the same.
- **If Sponsor's HTML5 soak finds an OPFS-specific regression** — T11 (M2 RC build pipeline) surfaces earlier in the order, ahead of T6 (death-recovery UI), so any HTML5 audit is run on a clean build before the bigger UI surfaces land.

---

## Tickets — M2 week-1

12 tickets. Each row: title (ticket-shape), owner, dependencies, size (S/M/L), acceptance criteria, P0/P1 priority.

**Sizing convention:** S = 1–2 ticks (~30 min orchestration), M = 3–5 ticks, L = 6–10 ticks. Total: 4 × S + 5 × M + 3 × L = roughly 50 ticks across the team in parallel — ≈ 1 M2 week of actual throughput at week-2 pace.

### T1 — `feat(save): v3→v4 migration impl (stash + ember-bag fields)`

- **Owner:** Devon
- **Depends on:** `team/devon-dev/save-schema-v4-plan.md` (consume verbatim)
- **Size:** M (3–4 ticks)
- **Priority:** **P0** (gate for T2 / T3 / T7 / T8 / T9)
- **Scope:** Bump `Save.SCHEMA_VERSION` from 3 → 4. Add `_migrate_v3_to_v4(data)` per the pseudo-code in §3 of the plan doc (has()-guarded, idempotent backfill of `character.stash` / `character.ember_bags` / `character.stash_ui_state`). Wire one new branch into `Save.migrate()` chain. Update `DEFAULT_PAYLOAD` with the three new character keys at their default values. Update `team/devon-dev/save-format.md` with the v4 shape table. **No game-code consumers in this PR** — just engine + migration. Stash UI consumers land in T3 / T7.
- **Acceptance:** `tests/test_save_migration.gd` extended with v3→v4 fixtures (six fixtures per §6 of plan doc — Tess co-authors fixtures in T12); INV-1..INV-8 all pin (Tess validates in T12); existing v0→v1→v2→v3 chain still passes (regression gate); SCHEMA_VERSION constant is 4 on disk after first save.
- **Risk note:** R1 (save migration). Sixth schema bump in M1+M2 history (v0→v1→v2→v3 in M1, v3→v4 here). Each prior bump held — pattern is robust — but this is the first bump that adds *Dictionary-of-Dictionary* shapes (ember_bags). Watch for JSON decode edge cases on browser-IndexedDB roundtrip.

### T2 — `feat(save): SaveSchema.gd autoload (default-value source of truth)`

- **Owner:** Devon
- **Depends on:** T1 (v4 migration must land first to seed the DEFAULTS map)
- **Size:** S (1–2 ticks)
- **Priority:** **P0** (deferred consumer until T3 reads the autoload, but spec'd in §4.2 of plan doc as part of the v4 batch — landing it now means T3 + T7 + T9 don't bake in scattered `if x in dict` checks)
- **Scope:** New autoload `scripts/save/SaveSchema.gd` per §4.2 of plan doc — `class_name SaveSchema extends Node`, `const DEFAULTS = {...}` (dot-path → default-value map), `default_value(key_path)` and `is_canonical(key_path)` methods. Register in `project.godot`. **Don't refactor existing consumers in this PR** — the refactor lands as part of T3 and T7 when those touch the relevant fields.
- **Acceptance:** New `tests/test_save_schema.gd` (paired) covers DEFAULTS map round-trip + unknown-key returns null + canonical-key returns true. Autoload registers without project-load errors. No regressions in existing save tests.
- **Risk note:** Trivial scope; ~80 lines of code. Risk is "scope creep into refactoring existing consumers" — explicitly out of scope; ticket closes when autoload exists + paired test passes.

### T3 — `feat(ui): stash UI implementation (StashPanel + cell rendering)`

- **Owner:** Devon (engine + UI scenes), Uma assists on copy / micro-pixel polish
- **Depends on:** T1 (v4 schema must support `character.stash`), T2 (SaveSchema autoload preferred for default reads), W3-A1 inventory panel HUD wiring (already on `main`)
- **Size:** **L** (6–10 ticks — largest single ticket in the backlog)
- **Priority:** **P0**
- **Scope:** Per `stash-ui-v1.md` §1 + §5. New scenes: `scenes/ui/StashPanel.tscn` (12×6 grid, sibling to `InventoryStatsPanel.tscn`, reuses `InventoryCell.tscn`). Extend `Inventory` autoload with `stash: Array[ItemInstance]`, `move_to_stash(item)`, `move_from_stash(item)` per stash-ui-v1.md §5. Slot-index sparse-array convention per save-schema-v4-plan.md §2.3 (Option A). Implement: LMB swap-pool semantics, drag-and-drop between grids, stack semantics for consumables (stack-to-99 for stackables, one-per-cell for gear). Discard-from-stash with T1=immediate-with-undo, T2+=Y/N confirm (matches inventory). Time-scale refactor per stash-ui-v1.md §5 ("panel open AND in-combat-context" — combat-context = `Levels.in_stash_room == false`). **NOT in scope:** stash search/filter/sort (M3 polish per stash-ui-v1.md §5), stash sharing across save slots (M3).
- **Acceptance:** ST-04, ST-05, ST-06, ST-07, ST-08, ST-09, ST-10, ST-22, ST-27 from stash-ui-v1.md §6 all pin via paired GUT tests + Tess sign-off. Tab + B both held opens both panels (ST-05). `Engine.time_scale == 1.0` throughout stash-room session including with panels open (ST-06).
- **Risk note:** **NEW M2 risk R8** (see §5) — largest single ticket; spans engine + UI + autoload + scene authoring. Mitigation: Devon scopes a "stub UI" first PR (panel renders empty stash, B-binding works, no item-move logic) and a follow-up "interactive" PR if size balloons. Pre-pin the cell layout in a screenshot before the PR opens. Tab+B coexistence is the Uma-flagged edge case (open question 8 in stash-ui-v1.md §7).

### T4 — `feat(content): stratum-2 sprite authoring (5 hard-need + tile palette)`

- **Owner:** Drew
- **Depends on:** `palette-stratum-2.md` §2 + §5 (sprite reuse table; consume verbatim)
- **Size:** M (3–5 ticks)
- **Priority:** **P0** (gate for T5; T6 boss substitute can stub on placeholder hex blocks but ships better with real sprites)
- **Scope:** Five hard-need sprites per palette-stratum-2.md §5: floor tiles (Cinder-Rust burnt-earth + collapsed mining stone variants, ~6 variants), wall tiles + ash-glow vein 6 fps 8-frame anim (~5 variants + animated band), ash-glow node prop (replaces brazier), doorway prop (cracked mining-tunnel arch with iron supports), S2 grunt sprite ("heat-blasted miner" silhouette per §2 mob accents — `#7A1F12` cloth + `#7E5A40` skin + `#D24A3C` aggro eye-glow). Tilemap variant per stratum (Aseprite source files + exported PNGs; `s2_tile_palette.tres`). **Soft-retints (Charger, Shooter, Pickup, Ember-bag, Stash chest) deferred to T4-followup ticket in M2 week 2** unless Drew's pace is faster than expected.
- **Acceptance:** S2-PL-02, S2-PL-03, S2-PL-04, S2-PL-05, S2-PL-07, S2-PL-08, S2-PL-09, S2-PL-10, S2-PL-12 from palette-stratum-2.md §7 pin (eye-dropper checks via Tess). Daltonization holds (S2-PL-13 — Uma re-runs §6 daltonization once sprites are at-pixel; if a pair fails, swap-out before merge). Aseprite source files committed alongside exported PNGs.
- **Risk note:** R3 / W1-art-bottleneck. Drew's sprite-authoring throughput is the historical bottleneck for content tickets. Mitigation: §5 soft-retints split out of this ticket; if T4 stalls, T5 ships with placeholder hex blocks (S2-PL-15 Sponsor-soak signal can run on hex blocks for a first pass — palette validation is independent of art polish).

### T5 — `feat(level): stratum-2 first room (s2_room01)`

- **Owner:** Drew
- **Depends on:** Stratum-2 chunk-lib scaffold (W3-B2, on `main`), T4 (sprites; or hex-block fallback), `palette-stratum-2.md` §3 (decoration beats), `palette-stratum-2.md` §4 (lighting model)
- **Size:** M (3–5 ticks)
- **Priority:** **P0**
- **Scope:** First S2 room per Drew's M2 implementer checklist (level-chunks.md § "M2 implementer checklist" steps 1–3): create `resources/level_chunks/s2_room01.tres` (`LevelChunkDef`, chunk_id `s2_room01`); author `scenes/levels/Stratum2Room01.tscn` (use `MultiMobRoom.gd` directly per implementer note 3, point chunk_def at the s2_room01.tres, wire `*_scene_path` exports to S2 grunt + S1-shared Charger/Shooter scenes for now). Use the §3 decoration beats: ash-glow veins on walls (animated), loose scree at floor edges (inert in v1 — slip-zone mechanic deferred per palette-stratum-2.md §8 q2), broken mining-cart silhouettes (background plane), iron support struts (props). Steam vents inert in v1 (hazard mechanic deferred per §8 q3). Implement the S2 lighting model per §4 — `CanvasLayer` + `ColorRect` ambient `#FF5A1A` 8% multiply, vignette deepen to `#0A0404` 40%, vein-pulse as sprite anim (NO Light2D). Place sprites under `resources/mobs/s2/` per level-chunks.md folder layout recommendation.
- **Acceptance:** S2-PL-06, S2-PL-11, S2-PL-14, S2-PL-15 pin. Room loads, instantiates, builds the assembly via `LevelAssembler.assemble_single`, spawns S2 grunts inside bounds (paired test in `tests/test_stratum2_rooms.gd` mirroring `test_stratum1_rooms.gd`'s 17-test pattern). Player crosses S1→S2 via descend portal and lands in S2 R1 (E2E test stub — full integration in T6 / T9 / Tess T12).
- **Risk note:** None new. Standard content-authoring risk (R3 HTML5 if any new texture pixel-spec breaks browser export; mitigation = T11 RC build pipeline runs on every PR).

### T6 — `feat(mobs): stratum-2 mob v1 — Stoker (fire-breathing miner-corpse)`

- **Owner:** Drew
- **Depends on:** T4 sprites (mob silhouette + animations), S2 grunt as the visual baseline (heat-blasted miner reference)
- **Size:** **L** (6–10 ticks)
- **Priority:** **P0** (M2 needs ≥1 NEW archetype to feel like a different stratum — recoloured S1 mobs alone don't justify the descent narrative)
- **Scope:** New mob archetype: **Stoker** — fire-breathing miner-corpse. Theme fits Cinder Vaults (heat-blasted miner with the embergrave seam still glowing in their chest cavity; "this mining accident is still happening"). State machine modelled on the Shooter (M1 PR #33) — idle → aggro → telegraph (1.0 s wind-up; chest glow brightens, audio cue) → attack (cone-shaped fire breath, 2 s duration, deals contact + DoT) → cooldown (1.5 s recovery, vulnerable). 1 archetype only — no charger/shooter blend; the Stoker is the single S2 archetype this week. New TRES at `resources/mobs/s2/stoker.tres`, scene at `scenes/mobs/Stoker.tscn`, script at `scripts/mobs/Stoker.gd`. Wire Stoker into `MultiMobRoom._spawn_mob` match-block per level-chunks.md M2 implementer note 5 — OR (preferred per Drew's note) introduce the `MobRegistry` autoload now to dodge the match-block growth (`MobRegistry` shape sketched in `MobSpawnPoint.gd` doc-comment). **MobRegistry sub-task is a stretch** — defer to follow-up ticket if T6 is already at 8+ ticks.
- **Acceptance:** Stoker spawns, telegraphs visibly (1.0 s wind-up reads at-screen), fire breath does damage, dies, drops loot via existing LootRoller (S2 mob drop tables added — see T6 sub-deliverable). Paired GUT tests cover state transitions (idle→aggro / aggro→telegraph / telegraph→attack / attack→cooldown / hit → die) — same pattern as `test_grunt.gd`. Tab-blur edge probe + console-error round-trip per testing bar.
- **Risk note:** **NEW M2 risk R9** (see §5) — combination of (a) new state machine complexity (W3 carryover), (b) new audio cue authoring (cone-fire-breath has no M1 baseline), (c) telegraph timing tuning may need balance pass. Mitigation: state machine modelled on Shooter (proven M1 pattern); first PR ships Stoker with SFX placeholders (T10 fills audio later); Drew's affix-balance-pin precedent (one-tick fill-then-soak) applies here.

### T7 — `feat(progression): ember-bag pickup-at-death-location impl`

- **Owner:** Devon
- **Depends on:** T1 (v4 schema for `character.ember_bags`), T3 (stash UI for overflow path), T4 sprites (ember-bag pickup sprite — soft-retint OK from S1 cloth bundle per palette-stratum-2.md §5)
- **Size:** M (3–5 ticks)
- **Priority:** **P0**
- **Scope:** Per `stash-ui-v1.md` §2 + §5. New scene `scenes/objects/EmberBag.tscn` (Area2D + Sprite2D + AnimationPlayer, 24×24 internal). Extend `StratumProgression` autoload with `ember_bags: Dictionary[int, EmberBag]`, `pack_bag_on_death(stratum, room_id, pos, items)`, `recover_bag(stratum)` — atomic `Save.save_game()` on bag-pack per save-schema-v4-plan.md §7.3 (frequency change requirement). Implement edge cases per stash-ui-v1.md §2 "Edge cases the bag must handle" table: room-doesn't-exist fallback to stash-room, boss-room death spawns bag at boss-arena entry, same-tile second death replaces first bag (one-bag rule), inventory-full recovery overflows to stash, items-reference-deleted-content drops the entry with `push_warning`, save-corruption-doesn't-nuke-character.
- **Acceptance:** ST-11, ST-12, ST-19, ST-20, ST-21, ST-23, ST-24, ST-25 from stash-ui-v1.md §6 pin. Paired test asserts atomic save fires before run-summary screen displays (regression for the §7.3 frequency change). M1 contract holds verbatim (ST-25): equipped + level + XP persist on death without bag involvement.
- **Risk note:** Edge-case heavy (six edge cases enumerated in stash-ui-v1.md §2); Tess's M2 acceptance scope is tight here. Pre-merge gate: every edge-case row in stash-ui-v1.md §2 has a paired test.

### T8 — `feat(ui): death-recovery flow screens (run-summary + stratum-entry banner + HUD pip)`

- **Owner:** Uma (copy + microcopy + visual treatment), Devon (impl)
- **Depends on:** T1 (v4 schema), T3 (stash room scene reuses panel chrome), T7 (ember-bag entity to surface in summary)
- **Size:** M (3–5 ticks)
- **Priority:** **P0**
- **Scope:** Per `stash-ui-v1.md` §3 — three layered cues. (1) **Run-summary screen evolution**: KEPT → EMBER BAG → LOST WITH THE RUN sectioning per §3 Beat E mockup; ember-orange section header for EMBER BAG; cards at full saturation; subtitle with `Recoverable in Stratum N · Room x/y`; if bag is empty (no items packed) the section is omitted entirely. (2) **Stratum-entry banner**: 2 s slide-in from top of HUD when crossing into a stratum with a pending bag — `Ember Bag pending — Stratum N · Room x/y`, ember-orange on dark slate, dismisses on any input. (3) **HUD pip + minimap marker**: 8×8 pip 12 px left of HP bar, idle 50% opacity, in-stratum pulse 50%↔100% over 1.0 s, in-room pulse `#FFB066` faster (0.5 s cycle); minimap marker matches pip glyph. **Visual conformance:** all colors from palette.md global ramps + stash-ui-v1.md §4 (no S2-specific tints — UI chrome is cross-stratum constant). **Recovery prompt** when player walks over bag: 1.0 s ember-rise whoosh (reuse Beat F sample, +2 semitones), particle dissolve, 4 s toast `Ember Bag recovered · 3 items returned`, no confirm.
- **Acceptance:** ST-13, ST-14, ST-15, ST-16, ST-17, ST-18 from stash-ui-v1.md §6 pin. Tab-blur edge probe (banner doesn't lock if tab-blur during slide-in). Localizable strings (Uma: parchment-color subtitle, ember-orange section header per visual lang).
- **Risk note:** Two-owner ticket (Uma + Devon). Risk is hand-off seam — Uma authors copy + screenshots; Devon implements. Mitigation: Uma posts screenshots in ticket as authoritative reference; Devon's PR includes side-by-side comparison with Uma's specs.

### T9 — `feat(level): stash room scene + B-key context binding`

- **Owner:** Devon (engine + scene), Drew assists on the room layout (level)
- **Depends on:** T1 (v4 schema for `stash_room_seen`), T3 (stash panel for the B-binding to open), T4 sprites (stash chest sprite — soft-retint OK)
- **Size:** M (3–5 ticks)
- **Priority:** **P0**
- **Scope:** Per `stash-ui-v1.md` §1 ("Where the stash lives") + §3 ("New beat — Stash Room Entry"). New scene `scenes/levels/StashRoom.tscn` — small chamber, dim warm light, stash chest center-stage. **Stratum-1 instance** as `Stratum1StashRoom.tscn` (M2 week 1 ships only S1's stash room; S2's stash room is a follow-up M2 week 2 ticket). Stash-room-entry hint-strip per §3 Beat (non-modal hint at screen bottom showing `[E] open chest [B] open stash [Tab] inventory [Down] descend`, fades after 5 s, gates on `stash_ui_state.stash_room_seen` first-visit flag). Extend `Levels` autoload with `in_stash_room: bool` + `entered_stash_room` / `left_stash_room` signals per stash-ui-v1.md §5. `InputManager` (or input-action layer) registers/unregisters the B action while inside the room. Stratum-1 first-room replacement: stratum-1 entry chamber becomes the stash room (per §1 "Stratum rooms are NOT in-run rooms" rule); the M1 first-room intro retires (or moves to "first descent" per Sponsor preference — flag in §7 below).
- **Acceptance:** ST-01, ST-02, ST-03 from stash-ui-v1.md §6 pin. Stash chest sprite + idle anim (ember motes) renders. B-binding context-sensitivity verified (B does nothing outside the stash room; B opens panel inside). `stash_room_seen` flips false→true on first entry and persists through save/load. Paired test covers the autoload signal contract (`entered_stash_room` / `left_stash_room` fire correctly).
- **Risk note:** "Stratum-1 first room becomes the stash room" is a non-trivial M1→M2 behavioral shift. The M1 first-room intro (single grunt encounter at start of stratum 1) is currently in `Stratum1Room01.gd`. Either (a) M2 retires the M1 first-room intro entirely (replaces with the stash room) or (b) the stash room is a *new* room *before* the M1 first-room intro (descent flow becomes: title → stash room → first-room intro → run). **Recommendation: option (b)** — preserves the M1 first-mob beat for narrative pacing, adds the stash room as a between-runs gateway. Flag for Sponsor in §7 — this is a player-facing flow change.

### T10 — `design(audio)+source: mus-stratum2-bgm + amb-stratum2-room sourcing pass`

- **Owner:** Uma (sourcing + direction), Devon (wiring into bus structure)
- **Depends on:** Uma's audio-direction.md v1.1 PR (in flight as `uma/audio-direction-v1.1-cinder-vaults` — landed as part of M2-onset prep) + sourcing decision per Uma's hand-composed M1+M2 plan
- **Size:** S (1–2 ticks for placeholder loops; M (3–5) for hand-composed)
- **Priority:** **P1** — defer to placeholder loop if sourcing latency exceeds 1 tick (M2 RC can ship with placeholder dark-folk loops; final hand-composed lands as a M2 polish ticket)
- **Scope:** Per `audio-direction.md` row 87 (`mus-stratum2-bgm`, ~120 s loop, hand-composed, M2 priority) — Cinder Vaults harmonized direction (pressure-depth, slow frame-drum heartbeat, sustained cello drone, occasional bronze-bell strike, rust-warm). Plus row 97 (`amb-stratum2-room`, 60 s loop, freesound + hand-mix, M2 priority — currently still flagged "water drip + parchment rustle" per Sponsor's run-006 STATE flag; Uma's nudge for ambient direction is deferred to v1.2 of audio-direction.md OR ships in this ticket with steam-hiss + scree-rustle + faint vein-pulse hum direction). Devon wires both into the stratum-2 entry so they auto-loop on stratum entry per existing `mus-stratum1-bgm` pattern. **OGG q5/q7 sourcing per audio-direction.md §4 source-of-truth flow.**
- **Acceptance:** Stratum 2 entry triggers `mus-stratum2-bgm` and `amb-stratum2-room` to play (paired test asserts `AudioStreamPlayer` is playing the expected stream after the descend transition). 5-bus structure holds (no new bus added — both cues use existing music + ambient buses per audio-direction.md §3 mixing rules). Sidechain duck spec preserved.
- **Risk note:** **NEW M2 risk R10** (see §5) — audio sourcing latency. Hand-composed cues have no fixed cycle time; if Uma can't hand-compose in week 1, ship placeholders. Falling back to placeholder is **explicitly P1 fallback** — not a quality regression.

### T11 — `chore(ci): M2 first-pass RC build artifact pipeline`

- **Owner:** Devon
- **Depends on:** existing `release-github.yml` workflow (M1 RC pipeline; copy-pattern only, no scope creep)
- **Size:** S (1–2 ticks)
- **Priority:** **P0** (gate for any Sponsor M2 soak; without an RC build pipeline, Sponsor can't playtest M2 progress)
- **Scope:** Copy-and-rename `release-github.yml` workflow into a M2-tagged pipeline (e.g., `release-github-m2.yml` OR add an M2 RC tag pattern to the existing workflow — Devon's call). M2 RC artifact = M2-build HTML5 + Windows zip uploaded as a GitHub Release on every `main` push that touches M2 paths (or on explicit `m2-rc-N` tag). **No CI hardening or new tests in this PR** — pure copy-pattern. Existing M1 pipeline stays as-is until M1 RC is the official sign-off candidate, then can be retired or re-cycled for M2.
- **Acceptance:** First M2 RC artifact (`m2-rc1`) uploads successfully to GitHub Releases on a manual workflow_dispatch or first-tagged push. SHA footer (existing testability hook #1) shows the M2 build SHA. Tess re-runs HTML5 audit pattern (`team/tess-qa/html5-rc-audit-591bcc8.md` template) on `m2-rc1`.
- **Risk note:** R3 HTML5 export. M2 introduces new audio streams (T10), new sprites (T4), new scenes (T5/T6/T9), new save schema (T1) — each is a new HTML5 edge surface. Mitigation: Tess's W3-A5 HTML5 audit template re-runs on `m2-rc1`. If the audit surfaces a regression, fix-forward in a dedicated M2 hotfix PR; don't gate the rest of the backlog on it (per the M1 R3 escalation playbook).

### T12 — `qa(integration): M2 first-pass test plan + paired GUT tests for ACs`

- **Owner:** Tess
- **Depends on:** **None** — this ticket runs **parallel** to T1–T11 from week-1 day-1. Tess authors fixtures + invariant pinning + acceptance shapes ahead of merges; once T1 / T3 / T7 etc. open PRs, Tess's existing scaffolding turns into sign-off-velocity gain.
- **Size:** M (3–5 ticks)
- **Priority:** **P0** (Tess's M2 acceptance plan is the integration gate for M2 sign-off; without it, the testing bar can't fire)
- **Scope:** (1) M2 acceptance plan doc at `team/tess-qa/m2-acceptance-plan.md` enumerating ST-01..ST-28 (stash-ui-v1.md §6) + S2-PL-01..S2-PL-15 (palette-stratum-2.md §7) + INV-1..INV-8 (save-schema-v4-plan.md §5) — total ~51 acceptance rows mapped to T1–T11 ticket-deliverables. (2) Six v3 fixture files per save-schema-v4-plan.md §6 (`save_v3_baseline.json`, `save_v3_empty_inventory.json`, `save_v3_max_level_capped.json`, `save_v3_full_inventory.json`, `save_v3_partial_corruption.json`, `save_v4_idempotent_baseline.json`). (3) New paired test files: `tests/test_save_migration_v4.gd` (INV-1..INV-8), `tests/test_stash_panel.gd` (ST-04..ST-10 hooks), `tests/test_stash_room.gd` (ST-01..ST-03 + ST-22), `tests/test_ember_bag.gd` (ST-11..ST-25 hooks), `tests/test_stratum2_rooms.gd` (S2-PL-15 + room-load + mob-spawn). (4) Integration scene tests for the M2 ACs (mirroring W3-A3 pattern: speed-to-first-kill in S2, death-keeps-progress through migration, save-survives quit-relaunch with v4 schema). (5) HTML5 audit re-run on `m2-rc1` per T11 (R3 mitigation).
- **Acceptance:** All 51 acceptance rows mapped + paired tests + Tess sign-off process documented (testing bar §Tess). M2 acceptance plan doc on `main`. Six fixtures committed under `tests/fixtures/`. Test pass count delta projected (M1 baseline 565 passing / 1 pending; M2 week-1 target +60–80 passing as T1–T9 paired tests land).
- **Risk note:** R2 (Tess bottleneck) — if all 11 implementation tickets ship in week 1 simultaneously and Tess is the single sign-off, queue depth could spike. Mitigation: Tess's parallel integration scaffold (this ticket) reduces per-PR sign-off cost (fixtures pre-authored, paired-test stubs pre-committed, sign-off becomes "PR's tests pass + no edge-case regression"). Same pattern as W3-A3.

---

## Risks (forward-look)

Re-score of the risk register for M2 onset. Top-3 active risks for M2 week-1:

### R1 (held — second bump in 2 milestones, watch-only)

**Save migration breakage between schema versions.**

- Probability: **med** (held from M1 register).
- Impact: **high** (held).
- M2 context: v3→v4 is the sixth schema bump in M1+M2 history (v0→v1, v1→v2, v2→v3 in M1; v3→v4 here). All five prior bumps held without breakage. **Pattern is robust.** That said: this is the first bump that adds a Dictionary-of-Dictionary shape (`character.ember_bags`); prior bumps were all flat-field additions or simple sub-dict moves. New JSON shape = new edge case potential.
- Mitigation: T1's INV-1..INV-8 round-trip invariants (eight pinned in save-schema-v4-plan.md §5); Tess's six v3 fixtures (T12) including the partial-corruption fixture (defensive-guard sweep); idempotence test pinned (INV-7 — re-run migration on v4 data is a no-op). HTML5 audit on `m2-rc1` (T11+T12) catches OPFS / IndexedDB roundtrip edge cases.
- **Watch signal:** any save-touching PR that ships without a migration test; any Tess soak run where reload doesn't preserve a known field.
- **Owner:** Devon (implements migration), Tess (validates), Priya (enforces gate).

### R3 (escalated — new HTML5 surface, audit v2 mandatory)

**Godot HTML5 export regression mid-M2-build.**

- Probability: **high** (held from M1's mid-w2 escalation).
- Impact: **high** (held).
- M2 context: M2 week-1 introduces SIX new HTML5 surfaces simultaneously: (a) v4 save schema with Dictionary-of-Dictionary persistence (OPFS / IndexedDB roundtrip); (b) stash UI panel with cell-rendering at 12×6 = 72 cells (drawcall budget on browser); (c) ember-bag pickup with sprite anim + audio cue (ParticleMaterial + AudioStreamPlayer in browser); (d) stratum-2 entry with ambient tint overlay (`CanvasLayer` blend-mode-multiply on browser); (e) Stoker mob with cone-fire-breath telegraph (potential particle / shader implication); (f) audio sourcing pass (new OGG streams, browser-decode timing).
- Mitigation: T11 (M2 RC build artifact pipeline) lands first as a P0 gate. Tess's W3-A5 HTML5 audit template (`team/tess-qa/html5-rc-audit-591bcc8.md`) re-runs on `m2-rc1` per T12. Tab-blur edge-probe on EVERY new autoload addition (`SaveSchema` in T2; new signals in `Levels` / `StratumProgression` / `Inventory` in T3 / T7). Console-error round-trip on EVERY new scene (T3, T5, T9).
- **Watch signal:** any HTML5 build that boots on desktop dev but breaks on the itch URL; tab-blur edge probe failures; OPFS / localStorage save mismatch; dropped audio on stratum-entry transition.
- **Owner:** Devon (export presets, CI), Tess (HTML5-specific test cases).

### R8 (NEW — stash UI complexity)

**Stash UI implementation is the largest single ticket; UX surface + engine + scene authoring + autoload extension stacked on one ticket.**

- Probability: **high**.
- Impact: **med-high** (if T3 slips, T7 / T8 / T9 all chain on it; chain-failure cost is multi-day).
- Why: T3 is L-sized (6–10 ticks). Three distinct skill domains (engine extension, UI scene authoring, save-schema integration). Largest M2 week-1 ticket. Single owner (Devon).
- Mitigation: pre-pin the cell layout in a screenshot before the PR opens (Uma assists via T8 hand-off). Devon scopes a "stub UI" first PR (panel renders empty stash, B-binding works, no item-move logic) and a follow-up "interactive" PR if size balloons. Tab+B coexistence (open question 8 in stash-ui-v1.md §7) is the Uma-flagged edge case — Devon's PR includes a manual test for this one regardless of where it lands. T2 (SaveSchema autoload) lands first to remove default-value-sourcing rework.
- **Watch signal:** T3 in flight for >5 ticks without a sign-off; multiple "split into smaller PRs" flips on the ticket; Tess flagging the panel surface as "feels incomplete" without specific failures.
- **Owner:** Devon (implement), Uma (UX hand-off + visual sign-off), Priya (size sentinel).

### R9 (NEW — stratum-2 content authoring triple-stack)

**Sprite + design + balance triple-stack on Drew + Uma in week 1.**

- Probability: **high**.
- Impact: **med**.
- Why: T4 (sprite authoring), T5 (S2 R1 content authoring), T6 (Stoker design + state machine + balance) all stack on Drew. T8 (death-recovery flow) + T10 (audio sourcing pass) stack on Uma. W1 (art bottleneck) was a watch-list item in M1; in M2 week-1 it's elevated.
- Mitigation: T4's soft-retints (Charger / Shooter / Pickup / Ember-bag / Stash chest) explicitly deferred to M2 week 2 if T4 stalls. T5 ships with placeholder hex blocks if T4 sprites slip — palette validation is independent of art polish (S2-PL-15 Sponsor-soak signal can run on hex blocks). T6 ships Stoker with SFX placeholders; T10 fills audio later. Uma's T8 has Devon as the implementer, so Uma's load is copy + visual review, not full impl.
- **Watch signal:** T4 / T5 / T6 all in flight at the same heartbeat tick without a closure on any; Drew's STATE.md run-bump frequency drops; placeholder-vs-final art question raised in PR review.
- **Owner:** Drew (sprite + content authoring), Uma (UX direction + audio sourcing), Priya (capacity guardrail).

### R10 (NEW — audio sourcing latency)

**`mus-stratum2-bgm` + `amb-stratum2-room` are hand-composed cues with no fixed sourcing cycle.**

- Probability: **med**.
- Impact: **low** (placeholder loops are explicitly acceptable per audio-direction.md §4 source-of-truth flow).
- Why: Hand-composed cues have no schedulable timeline. M2 week 1 will likely ship with placeholder dark-folk loops (Uma sources from freesound at q5 OGG). Final hand-composed lands as a M2 polish ticket in week 2 or week 3.
- Mitigation: T10 is **P1**, not P0. Placeholder loops are the explicit fallback; final hand-composed deferred to a follow-up. Audio bus structure (5 buses + sidechain) is unchanged, so swapping the stream later is a one-line `AudioStreamPlayer.stream = ...` change.
- **Watch signal:** T10 in flight for >2 ticks without closure; Uma flagging hand-composing as taking longer than expected.
- **Owner:** Uma (sources or hand-composes), Devon (wires into bus structure).

### Demoted risks (held but not top-3 for M2 week-1)

- **R6 (Sponsor-found-bugs flood):** materially relevant only when Sponsor is actively soaking M2 RC. M2 week-1 starts with Sponsor M1 sign-off in hand; Sponsor's M2 soak is M2 week-2 at earliest. Re-promote when M2 RC drops.
- **R7 (Affix balance hand-tuning sinkhole):** M1-specific risk; resolved by `affix-balance-pin.md`. M2 affix-balance pass would need to be a separate doc when M2 introduces T4+ tiers (deferred to M3 per mvp-scope.md). Not active in M2 week-1.
- **R2 (Tess bottleneck):** mitigated by T12 parallel scaffolding; queue depth shouldn't spike in week 1 since paired tests are co-authored.
- **R4 (scope creep):** M2 scope is enumerated here + DECISIONS.md M2 entries; revisable post-Sponsor sign-off. Drift risk is symmetric to M1 — manageable.
- **R5 (concurrent-agent collisions):** worktree-isolation v3 (W3-A7) live; HEAD-pinning leak fixed. Not a top-3 M2 risk.

---

## Capacity check

**Week-2 throughput: 16 + 2 = 18 tickets shipped.**
**Week-3 throughput: 8 close-out + 7 design = 15 tickets shipped.**

**M2 week-1 ceiling: ~12 tickets.** Within the 14-ticket "comfortable" envelope (week-3's actual was 15 shipped including 7 design which were single-doc-PRs; M2 week-1 has fewer design rows and more implementation rows, so the per-ticket cost is heavier).

**Proposed: 12 tickets (T1–T12).** All P0 except T10 (P1 fallback for audio sourcing latency).

| Bucket | Count | Tickets |
|---|---|---|
| **P0** | 11 | T1, T2, T3, T4, T5, T6, T7, T8, T9, T11, T12 |
| **P1** | 1 | T10 (P1 fallback to placeholder loops if Uma's hand-compose latency is high) |

**Trim to 10 if needed:** drop T10 (audio sourcing) and T11 (M2 RC pipeline) — both are infrastructure / polish. Audio can ship M1 cues in S2 with a `push_warning` log; M2 RC pipeline can run manually for M2 week 1 and automate in week 2. **Don't trim further than 10** — T1 / T3 / T7 / T8 / T9 chain on each other and dropping any one leaves the M2 promise broken (no stash UI = no death-recovery = no M2 vertical-slice progress).

**Trim to 8 if Sponsor's M1 soak surfaces blockers and the bug-bash absorbs more capacity than expected:** drop T10 + T11 + T6 + T8. Ship T1+T2+T3+T7+T9+T4+T5+T12. Outcome: M2 week-1 has stash UI + ember-bag working but no S2 mob (Stoker) and no run-summary screen evolution. Acceptable but feels half-shipped — only do this trim if the bug-bash is genuinely heavy.

**Capacity estimate by owner:**

- **Devon:** T1 + T2 + T3 + T7 + T8 (impl) + T9 + T11 = 7 tickets. **Heaviest load** but all are in his lane (engine + UI + save). Mitigation: T2 / T11 are S-sized; T1 + T7 + T9 are M-sized; T3 is L-sized; T8 is M-sized but co-owned with Uma. Devon's week-2 throughput was 5+ tickets, and T3's "stub PR + interactive PR" split (R8 mitigation) keeps any single PR under 4 ticks.
- **Drew:** T4 + T5 + T6 = 3 tickets. **L+M+M** (heaviest individual ticket = T6 Stoker). Soft-retint deferral (T4 sub-scope) keeps T4 capped at 5 ticks.
- **Uma:** T8 (copy + visual) + T10 (sourcing or placeholder) = 2 tickets. Plus continuing audio-direction.md v1.1 nudge already in flight. Light load — appropriate given W1 art bottleneck risk; Uma's spare capacity is the buffer for T8 polish + T4 daltonization re-run.
- **Tess:** T12 = 1 omnibus ticket (parallel from day-1) + ad-hoc per-PR sign-offs across T1–T11. Same pattern as W3-A3.
- **Priya:** none directly. Priya's M2 week-1 work is (a) this backlog draft, (b) capacity guardrails, (c) M2 retro at week close, (d) any DECISIONS.md amendments triggered by M2 design questions. **Unchanged from M1 PL pattern.**

**Buffer:** 2 free dev ticks reserved for reactive M2 work (per W3-A6 / R6 mitigation pattern). If Sponsor surfaces M1 issues during their soak that bleed into M2, those 2 ticks absorb the fix-forward.

---

## Open questions for Sponsor

Mostly **none** if M1 sign-off is clean. Listed here so the orchestrator can route them when M2 RC reaches Sponsor's interactive soak (M2 week 2+).

1. **Stash room placement: replace M1 first-room intro, or new room before it?** (T9 risk note.) **Recommendation: option (b)** — stash room is a new room *before* the M1 first-room intro (descent flow: title → stash room → first-room intro → run). Preserves the M1 first-mob narrative beat. Sponsor may prefer (a) replace if they feel the first-mob intro is redundant after seeing the stash room. **Owner:** Sponsor — first M2 soak feedback. Default (b) ships unless Sponsor objects.
2. **Death rule pushback (anticipatory).** If Sponsor's M1 soak surfaces "lose level on death" or "auto-return unequipped" pushback, T7 (ember-bag pickup) gets re-scoped or paused. **Default: hold the M1 death rule lock** (DECISIONS.md 2026-05-02) unless Sponsor explicitly objects.
3. **Ember-bag at death tile vs. auto-return** (Uma's stash-ui-v1.md §2 alternative — "lossy auto-return"). M1 death rule + Uma's stash-ui-v1.md §2 both lock pickup-at-death-location; this is the design intent. Sponsor may prefer auto-return for simplicity. **Default: pickup-at-death-location ships** (matches Dark Souls / Hades reference precedent per stash-ui-v1.md §2 "Why pickup-over-lossy"). Re-open only if Sponsor explicitly asks.
4. **One-bag-per-stratum vs. N-bags-per-stratum** (open question 4 in save-schema-v4-plan.md §9; open question 2 in stash-ui-v1.md §7). Schema supports both at additional migration cost (Devon §9). **Default: one-bag-per-stratum ships** (design intent — Dark Souls pattern, replaces-on-second-death). Sponsor playtest decides if it feels too punishing.
5. **`ember_bags` placement: under `character.` (Devon's recommendation) or at root (Uma's stash-ui-v1.md §5).** Both are JSON-pure; structural deviation flagged in Devon's plan §2.5. **Default: under `character.`** per Devon's M3-multi-character rationale. Uma confirms in M2 implementation PR review.

None of these block dispatch. All are revisable post-merge if Sponsor surfaces a clear preference.

---

## Hand-off

When Sponsor signs off M1 + bug-bash drains:

- **Orchestrator:** dispatch T1 (Devon save-schema impl) and T4 (Drew sprite authoring) **in parallel** as the first M2 dispatches. T12 (Tess parallel acceptance scaffold) dispatches on the same heartbeat tick. The other tickets cascade from these three — orchestrator picks up subsequent dispatches as PRs land per the existing M1 pattern.
- **Devon:** picks up T1 first; T2 follows on the same branch or as a sibling PR; T3 / T7 / T8 / T9 sequence after T1 / T2 land.
- **Drew:** picks up T4 first; T5 follows; T6 is independent and can run in parallel with T5 once T4's grunt sprite is shipped.
- **Uma:** continues audio-direction.md v1.1 PR; picks up T8 visual hand-off and T10 sourcing as Devon's PRs surface. Light week-1 load is appropriate (W1 art bottleneck mitigation).
- **Tess:** dispatches on day-1 with T12 omnibus parallel scaffold. Sign-off cadence increases as T1–T11 PRs land.
- **Priya:** monitors capacity guardrails (R8 + R9 + R10 watch signals). M2 week-1 close retro triggers when 10/12 P0 tickets shipped OR end-of-week-1 calendar boundary, whichever fires first.

---

## Caveat — this is a draft, not a contract

This document is **anticipatory planning**. It is revisable in any of these cases:

- **Sponsor's M1 soak surfaces blockers/majors that adjust M2 scope** — most likely revision.
- **Sponsor's M1 soak surfaces specific design pushback** (death rule, stash UI affordance, ember-bag variant) — re-scope T7 / T3 / T8 accordingly.
- **A team member's load capacity shifts** — re-balance Devon's 7-ticket load if needed.
- **An M2 follow-on design question lands** that wasn't anticipated in stash-ui-v1.md / palette-stratum-2.md / save-schema-v4-plan.md / level-chunks.md M2 scaffold — e.g., scree slip-zone mechanic (palette-stratum-2.md §8 q2) gets greenlit, adding a new T-ticket to this list.

Revisions land as a v1.1 of this doc, with the changed sections diff-highlighted and a one-line DECISIONS.md append referencing the change.

**This draft is the path of least resistance from M1 sign-off → M2 vertical slice.** It is not the only path.

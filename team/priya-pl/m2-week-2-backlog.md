# M2 Week-2 Backlog (CLOSED)

**Owner:** Priya · **Original tick:** 2026-05-03 (M1 RC `embergrave-html5-4484196` in active Sponsor soak; combat-fix dispatch in flight) · **Closed:** 2026-05-15 — W2 RC `embergrave-html5-d9cc159` shipped clean (Tess bug-bash `team/tess-qa/soak-2026-05-15.md`: **0 blockers, 0 majors, 2 minors both addressed**).

**Status:** **CLOSED 2026-05-15.** Retro at `team/priya-pl/m2-week-2-retro.md`. **Carry-overs absorbed by `team/priya-pl/m2-week-3-backlog.md`:** W2-T1, W2-T2, W2-T3, W2-T4, W2-T5, W2-T7 (conditional), W2-T8 (conditional), W2-T9, W2-T12. The W2 actual shape was playability close-out + harness completion (22 PRs merged across AC4 progression, inventory bandaid retirement, combat-trace coverage, polish/UX, harness hardening, level/physics-flush family) rather than the stratum-2 content authoring this backlog anticipated.

---

**Original status (preserved below):** DRAFT — revisable post-Sponsor M1 sign-off AND post-week-1 close.

This document is **doubly anticipatory planning**. Goal: when (a) Sponsor signs off M1 and (b) M2 week-1 ships clean, the team can start week-2 immediately without a planning gap. The M2 week-1 backlog (`team/priya-pl/m2-week-1-backlog.md`) is itself anticipatory — week-2 is one step further out, so the gating is doubled.

The backlog is a draft, not a contract. Two sources of revision pressure:

1. **Sponsor M1 soak findings** — the 2026-05-03 risk-register refresh (PR #112, top-3 = R6 firing now / R11 just realized / R12 firing now) shows the M1 close-out itself is a moving target. If Sponsor surfaces additional M1 blockers post-combat-fix, the M2 timeline shifts and this backlog gets a v1.1.
2. **M2 week-1 actual** — week-2 consumes the assumption that week-1 ships its 12 tickets cleanly. If T3 (stash UI) splits into two PRs (R8 mitigation), or T4 sprites slip and force T5 to ship on hex blocks, week-2 absorbs the carry-forward.

Drafting now means the team isn't idle in the gap between M2 week-1 close and M2 week-2 dispatch.

## TL;DR (5 lines)

1. **Target:** **12 tickets** for M2 week-2 (8 P0 + 3 P1 + 1 P2). Same shape as M2 week-1 (12 tickets) — week-1 throughput envelope + post-week-1-soak fix-forward buffer.
2. **Expected duration:** ~one M2 week (~10-14 ticks active orchestration, parallels week-1 cadence).
3. **Critical chain:** soft-retint sprites → s2 rooms 2-3 → s2 boss room first impl. Stash UI iteration (post-week-1-soak feedback) is a parallel chain, not blocking.
4. **MobRegistry refactor lands here** if T6 in week-1 stretched to fold it in; otherwise it's a discrete ticket here. Audio sourcing close-out lands either way (placeholder loops → hand-composed handoff).
5. **Sponsor-input items:** zero blocking pre-conditions (M1 sign-off + week-1 close are the gates). M3 design seeds (multi-character / hub-town / persistent meta) are pure design — Sponsor input *helpful* but not blocking; the seed drafts can ship as `design(m3-seeds)` and Sponsor reviews when convenient.

---

## Source of truth

This backlog consumes the following M2 week-1 deliverables as **assumed shipped**:

1. **`m2-week-1-backlog.md` T1-T12** — 12 tickets shipped clean. Verified by week-1 close retro (will be authored at week-1 boundary). Critical assumption: T1 (v3→v4 migration), T2 (SaveSchema autoload), T3 (stash UI), T7 (ember-bag pickup), T8 (death-recovery flow), T9 (stash room scene + B-key) all on `main`. T4 hard-need sprites + T5 s2_room01 + T6 Stoker mob v1 also shipped (or T6 in flight with MobRegistry stretch deferred — see T7 below in this doc).
2. **`team/priya-pl/m2-week-1-retro.md`** (NEW, drafted at week-1 close) — Priya authors when 10/12 P0 tickets ship; surfaces what slipped, what overshot, and which week-1 risk re-scores apply. **This week-2 backlog is revised in-place against the retro's findings before dispatch.**
3. **`team/uma-ux/stash-ui-v1.md`** — used in week-1 (T3 / T7 / T8 / T9). Week-2 iterates: post-Sponsor-feedback affordance changes, copy/microcopy polish, Sponsor's discoverability call.
4. **`team/uma-ux/palette-stratum-2.md`** — used in week-1 (T4 / T5). Week-2 consumes the §5 soft-retint table (Charger / Shooter / Pickup / Ember-bag / Stash chest) deferred from week-1 T4 sub-scope.
5. **`team/devon-dev/save-schema-v4-plan.md`** — implemented in week-1 (T1 / T2). Week-2 stress-tests under load (HTML5 OPFS round-trip with full stash + multi-stratum bag persistence).
6. **`team/drew-dev/level-chunks.md` § "Multi-stratum tooling (M2 scaffold)"** — week-1 used the scaffold. Week-2 builds on it: s2_room02 + s2_room03 share `MultiMobRoom` directly; MobRegistry refactor (deferred from week-1 T6) lands here.
7. **`team/priya-pl/risk-register.md`** (refreshed 2026-05-03) — top-3 active risks at M2 dispatch entry will be R3-M2 (re-opened from retired — six new HTML5 surfaces), R8 (stash UI complexity, week-1 lived experience feeds week-2), R9 (stratum-2 triple-stack continuing). R6 status depends on Sponsor's week-1 soak.

Plus DECISIONS.md M2 commitments:

- **2026-05-02 — M1 death rule** — week-2 deepens stash + ember-bag flows (post-week-1 lived experience feedback).
- **2026-05-02 — Save schema v3 → v4 design locked** — implementation lands in M2 week-1 T1; week-2 layers stress tests + edge-case fixtures.
- **2026-05-02 — Stash UI v1 design locked** — week-2 absorbs Sponsor's discoverability call (open question 1 in stash-ui-v1.md §7).
- **2026-05-02 — Stratum-2 biome locked: Cinder Vaults** — week-2 fills out S2 rooms 2-3 + boss room first impl.

The M1 acceptance contract (`team/priya-pl/mvp-scope.md` v1-frozen) is the floor. **Nothing in this backlog regresses an M1 AC.** Tess's sign-off discipline (testing-bar §Tess) verifies M1 ACs continue to pass under the v4-with-stress runtime as a side-effect of every migration / integration test.

---

## Pre-conditions

What must be true before M2 week-2 dispatch begins. **All gates external to this doc**; this backlog cannot self-start.

1. **Sponsor M1 sign-off is signed.** Carries from week-1 pre-condition. If Sponsor's combat-fix dispatch (`86c9m36zh` + `86c9m37q9`) doesn't close cleanly + Sponsor doesn't sign by week-2 dispatch time, this backlog is **paused**. M1 sign-off is the universal M2 gate — neither week-1 nor week-2 dispatches if it slips.
2. **M2 week-1 close clean** — 10 of 12 P0 tickets shipped (per `m2-week-1-backlog.md` §"Capacity check" trim guidance). Critical chain (T1 → T3 → T7 → T9) closed; T4 hard-need sprites either landed or the soft-retint deferral pattern surfaces a clear "T4 ships in week-2 with the soft-retints folded in" verdict.
3. **Week-1 retro drafted** — `team/priya-pl/m2-week-1-retro.md` authored by Priya at week-1 close. Lessons from T3 split (if it split), Stoker telegraph tuning (if it overshot), Tess T12 sign-off cadence under M2-load (if R2 fired) all consumed before week-2 dispatch.
4. **Bug-bash drained** — `86c9kxx7h` (M1 post-Sponsor-soak bug-bash) closed AND any week-1-soak bug-bash equivalent closed. M2 week-2 work doesn't dispatch with bug-bash open.
5. **R6 disposition** — if Sponsor's week-1 M2 soak surfaces ≥1 P0 (per the lowered R6 trigger threshold from the 2026-05-03 refresh), week-2 absorbs the fix-forward in the buffer ticks (T11 below) before any new content tickets dispatch.

**Conditional revisions if week-1 surfaces specific issues:**

- **If T3 (stash UI) split into stub-PR + interactive-PR per R8 mitigation, and the interactive-PR didn't land in week-1** — week-2 T1 below absorbs the interactive-PR finish; week-1 T3 effectively bleeds into week-2 critical path.
- **If T6 (Stoker) shipped without MobRegistry refactor (the stretch deferral fired)** — week-2 T7 below promotes from P1 to P0; the refactor is the M2 ramp's debt that week-2 should drain.
- **If T10 (audio sourcing) shipped placeholder only** — week-2 T9 below absorbs the hand-composed pass; promotion from P1 to P0 conditional on Uma's sourcing capacity.
- **If T4 soft-retints didn't ship in week-1 (full deferral)** — week-2 T2 below grows from M to L; T3 / T4 / T5 (rooms + boss) lean on hex-block placeholders for the soft-retint surfaces until T2 closes.
- **If Sponsor's soak surfaced a stash UI affordance change (open question 1 in stash-ui-v1.md §7)** — week-2 T8 below grows from S to M (absorbs the affordance iteration plus copy/microcopy pass).

---

## Tickets — M2 week-2

12 tickets. Each row: title (ticket-shape), owner, dependencies, size (S/M/L), acceptance criteria, P0/P1/P2 priority.

**Sizing convention:** S = 1-2 ticks (~30 min orchestration), M = 3-5 ticks, L = 6-10 ticks. Total: 4 × S + 6 × M + 2 × L = roughly 45 ticks across the team in parallel — ≈ 1 M2 week of actual throughput at week-1 pace.

### W2-T1 — `feat(level): stratum-2 second + third rooms (s2_room02 + s2_room03)`

- **Owner:** Drew
- **Depends on:** M2 week-1 T5 (s2_room01 on `main`), M2 week-1 T4 (S2 grunt + Stoker sprites on `main`, OR hex-block fallback), `palette-stratum-2.md` §3 decoration beats, `level-chunks.md` § "M2 implementer checklist"
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (gate for T2 boss-room first impl which depends on s2_room03 having been authored — boss-room is conventionally the terminal-cluster room, not the second room)
- **Scope:** Two new S2 rooms per Drew's M2 implementer checklist. `s2_room02.tres` (`LevelChunkDef`) + `Stratum2Room02.tscn` — mob mix: 2 Stokers + 1 Charger (recoloured, soft-retint dependency); follows §3 decoration beats with collapsed mining-cart silhouettes + ash-glow vein animation. `s2_room03.tres` + `Stratum2Room03.tscn` — mob mix: 1 Stoker + 1 Charger + 1 Shooter (heat-blasted variants); adds steam-vent props (still inert per palette-stratum-2.md §8 q3 deferral, decorative only). Both rooms 480×270 internal canvas with WEST entry / EAST exit + s2_room03 carries the `&"boss_door"` port tag for boss-room handoff. Wire S1→S2 flow per existing descend pattern (`StratumExit.gd` already supports it; just register the `Stratum2Room01.tscn` entry per existing pattern). `Stratum` namespace lookups continue per week-1 scaffold. **NOT in scope:** s2_room04+ (week-3 if more rooms ship before stratum-2 boss); randomized chunk selection (M3 procedural assembler); per-room state save (deferred per `level-chunks.md` § "Out of scope for M1").
- **Acceptance:** Both rooms load, instantiate, build the assembly via `LevelAssembler.assemble_single`, spawn S2 mobs inside bounds. Paired tests in `tests/test_stratum2_rooms.gd` (extend the file from week-1 T5) — same pattern as `test_stratum1_rooms.gd`'s 17-test layout: load test, assemble test, spawn-count test, port-validation test, mob-mix test per room. Player traverses S2 R1→R2→R3 via existing RoomGate flow. RoomGate cleared-state persists via `StratumProgression` (already shipped in M1 #49).
- **Risk note:** R9 (stratum-2 content triple-stack — week-1 carry). Mitigation: shares `MultiMobRoom.gd` with week-1 T5; per-room TRES is the only authoring surface; no new state-machine. Hex-block fallback if soft-retint sprites slip.

### W2-T2 — `feat(content): stratum-2 sprite soft-retint pass (Charger / Shooter / Pickup / Ember-bag / Stash chest)`

- **Owner:** Drew
- **Depends on:** `palette-stratum-2.md` §5 (sprite reuse table, soft-retint table — consume verbatim), M2 week-1 T4 (S2 grunt + Stoker as visual baseline + tile palette TRES)
- **Size:** M (3-5 ticks; **L if T4 fully deferred from week-1** — soft-retint cost grows with each unauthored sprite)
- **Priority:** **P0** (gate for T1 visual completion + T3 boss-room visual identity)
- **Scope:** Five soft-retint sprites per `palette-stratum-2.md` §5 — Charger (heat-blasted variant: `#7A1F12` cloth + `#7E5A40` skin tones; reuse S1 silhouette + animation rig, change palette only); Shooter (heat-blasted variant — same approach); Pickup glow (Cinder-Rust ember outer flame `#FF8B2A` + bell-tone harmonic stays color-constant); Ember-bag pickup sprite (S2 variant — Cinder-Rust ember-cloth bundle, replaces S1 fabric); Stash chest (S2 variant — iron-bound mining cart? OR same chest cross-stratum constant — Drew's call per stash-ui-v1.md §1 "Stratum rooms" rule, but recommend cross-stratum-constant per §4 "stash UI chrome is cross-stratum constant"). Aseprite source files committed alongside exported PNGs. S2-specific TRES references created (e.g., `resources/mobs/s2/charger_heatblasted.tres` references the new sprite + recoloured affix-balance entries if any). **NOT in scope:** brand-new mob silhouettes (handled in week-3 if S2 ramps further); animation-frame additions (soft-retint == palette swap only, animation count constant); audio-cue retints (stays cross-stratum per audio-direction.md).
- **Acceptance:** S2-PL-04 / S2-PL-05 (sprite mob accents), S2-PL-09 / S2-PL-10 (loot ember accents) from palette-stratum-2.md §7 pin via Tess eye-dropper. Daltonization holds (S2-PL-13 — Uma re-runs §6 daltonization once retints are at-pixel; if a pair fails, swap-out before merge). Aseprite source files committed.
- **Risk note:** R9 (stratum-2 triple-stack carry from week-1) — Drew load-balancing. Mitigation: per-sprite cost is bounded (palette swap + Aseprite re-export only); 5 sprites × ~1 tick each = 5 ticks max. If W1 art bottleneck fires (Drew's pace stalls), fall back to Stash chest cross-stratum-constant + Ember-bag cross-stratum-constant — drops 2 of 5 sprites without breaking the visual contract.

### W2-T3 — `feat(boss): stratum-2 boss room first impl — Vault-Forged Stoker (working title)`

- **Owner:** Drew (state machine + scene); Uma assists on intro/boss-treatment design (W3-B1 boss-intro pattern is a M1 reference, applies here)
- **Depends on:** W2-T1 (s2_room03 authored as boss-door predecessor), W2-T2 (Stoker sprite as design baseline — boss is a "vault-forged" upscaled Stoker), `team/uma-ux/boss-intro.md` (existing M1 boss-intro pattern — reuse beat structure)
- **Size:** **L** (6-10 ticks — single largest week-2 ticket, parallels M1 N6 boss state-machine complexity)
- **Priority:** **P0**
- **Scope:** New stratum-2 boss: **Vault-Forged Stoker** (working name). Theme fits Cinder Vaults (the embergrave seam erupted in this miner's chest cavity and *kept eating*; the Stoker became a vault-forged guardian). 3-phase state machine modelled on M1 boss `Stratum1Boss.gd` (PR #40): dormant → idle → chasing → telegraphing_breath → breathing → telegraphing_slam → slamming → phase_transition → dead. Phase boundaries 66% / 33%. Phase 3 enrage: 1.5× speed, 0.7× recovery, breath-cone widens. Stagger-and-damage-immune during 0.6 s phase-transition window per M1 boss invariant. **First impl** — full state machine + paired tests + scene + TRES + intro sequence + door-trigger Area2D. **Boss-room layout:** mining-shaft cathedral, `s2_boss_room.tres` chunk + `Stratum2BossRoom.tscn`. Boss-room entry sequence: `entry_sequence_started` / `entry_sequence_completed` signals (mirrors `Stratum1BossRoom`); 1.8 s sequence per `boss-intro.md` Beat-1 to Beat-5 timing. Boss loot: T3 weapon + T2/T3 gear (analogous to M1 boss). **NOT in scope:** boss music (stays cross-stratum-similar in M2 — `mus-boss-stratum1` reuses if `mus-boss-stratum2` not sourced; W2-T9 audio sourcing close-out covers this); boss death-screen unique cinematics (uses M1 `Stratum1BossRoom` defeated pattern); phase-aware music stems (M3 per audio-direction.md row 84-86).
- **Acceptance:** All 12 task-spec coverage points from M1 boss N6 (full HP / phase-1 attack / phase-2 transition / phase-2 attacks / phase-3 transition / phase-3 enrage / boss_died / i-frames / loot drop / hit-spam idempotence / damage-during-transition rejection / room-state reset to full HP) — same paired-test pattern as `tests/test_stratum1_boss.gd`. New tests in `tests/test_stratum2_boss.gd` + `tests/test_stratum2_boss_room.gd`. Player completes S1→S2 R1→R2→R3→S2 boss → defeated → "Stratum 3 — Coming in M3" descend stub OR equivalent terminator. Tab-blur edge probe + console-error round-trip per testing bar.
- **Risk note:** Largest week-2 ticket. Risk: boss state-machine complexity + new "breath cone" mechanic on top of M1 boss baseline. Mitigation: state machine modelled on Stratum1Boss directly (proven pattern); breath-cone mechanic reuses Stoker telegraph from week-1 T6 (just larger / wider); intro pattern reuses boss-intro.md beats verbatim. **Stub-then-iterate** — first PR ships boss with M1-boss numbers (HP/dmg copied from Stratum1Boss); soak signals balance pass (W2-T6 below or follow-up).

### W2-T4 — `feat(content): MobRegistry autoload — stratum-aware mob lookup + scaling`

- **Owner:** Devon (engine + autoload); Drew assists on s1/s2 mob_id registration + scaling-multiplier signoff
- **Depends on:** M2 week-1 T6 (Stoker landed; MobRegistry sketch in `MobSpawnPoint.gd` doc-comment per `level-chunks.md` § "Schema decisions" — consume verbatim if T6 stretch deferred). If week-1 T6 folded MobRegistry in, this ticket promotes from P1 to "**already shipped, retire**."
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (week-1 deferred this from T6 stretch; the `MultiMobRoom._spawn_mob` match-block is now growing and will become a maintenance hotspot if every new mob adds a match-arm)
- **Scope:** New autoload `scripts/content/MobRegistry.gd` per the sketch in `level-chunks.md` § "Why mob spawns reference mob_id, not MobDef". Maps `mob_id: StringName → MobDef + MobScene + scaling_multipliers: Dictionary[StringName, float]`. Methods: `get_mob_def(mob_id) -> MobDef`, `get_mob_scene(mob_id) -> PackedScene`, `apply_stratum_scaling(mob_def, stratum_id) -> MobDef` (returns a stratum-scaled clone — does NOT mutate the source). Refactor `MultiMobRoom._spawn_mob` from match-block to `MobRegistry.spawn(mob_id, position, room_node)` — single dispatch point. Backwards-compat: existing direct-scene references in TRES (week-1 T5/T6) still work; MobRegistry is preferred path. Stratum-scaling table per `mvp-scope.md §M2`: S1 baseline 1.0, S2 +20% HP / +15% dmg, S3+ deferred to M3. **Register in `project.godot`.**
- **Acceptance:** New `tests/test_mob_registry.gd` (paired) covers registry round-trip (register → lookup → spawn), stratum-scaling math (S1 baseline → S2 scaled clone), mob_id-not-found graceful return, scaling-doesn't-mutate-source invariant. `MultiMobRoom` refactor doesn't regress any week-1 or M1 mob-spawn test. New autoload registers without project-load errors.
- **Risk note:** Refactor risk — `MultiMobRoom` is exercised by every M1 + M2 room. Mitigation: paired tests stay green throughout; refactor is mechanical (extract match-block dispatch, no behavior change).

### W2-T5 — `feat(save): schema v4 stress test fixtures + HTML5 OPFS round-trip`

- **Owner:** Tess (fixtures + tests); Devon assists on OPFS-specific edge cases
- **Depends on:** M2 week-1 T1 + T2 (v3→v4 migration + SaveSchema autoload on `main`); M2 week-1 T7 (ember-bag pickup writing the new schema fields); `team/devon-dev/save-schema-v4-plan.md` §6 (fixture catalog)
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (R1 mitigation deepening — the v3→v4 sixth schema bump pattern needs stress data, not just the six baseline fixtures from week-1 T12)
- **Scope:** Eight new stress-fixture files under `tests/fixtures/v4/`: `save_v4_full_stash_72_slots.json` (12×6 stash full of T1-T3 gear with rolled affixes), `save_v4_three_stratum_bags.json` (one bag per stratum 1/2/3 — overflow boundary), `save_v4_partial_corruption_recovery.json` (corrupt one bag entry, ensure character + stash persist + corrupt entry drops cleanly), `save_v4_max_level_capped_full_inventory.json` (L5 cap × full inventory × full stash × all stratums-cleared meta), `save_v4_html5_opfs_baseline.json` (smallest valid v4 — IndexedDB minimal-overhead test), `save_v4_html5_opfs_max.json` (largest practical v4 — IndexedDB max-overhead test, ~50KB), `save_v4_idempotent_double_migration.json` (v3 fixture migrated v3→v4 twice; second pass must be no-op per INV-7), `save_v4_unknown_keys_passthrough.json` (v4 + arbitrary new top-level keys; runtime ignores per migration policy `save-format.md`). Paired test `tests/test_save_v4_stress.gd` covers all eight fixtures + full-stash round-trip timing budget (<50ms on desktop, <500ms on HTML5 — coordinates with W2-T11 performance budget). HTML5 OPFS round-trip test runs as an `#if HTML5_BROWSER` integration test if Tess can stand up a headless browser GUT runner; otherwise documented as Sponsor-soak probe target per the W3-A5 audit pattern.
- **Acceptance:** Eight fixtures committed under `tests/fixtures/v4/`. Paired test `tests/test_save_v4_stress.gd` adds ~12-16 new test cases covering INV-1..INV-8 from save-schema-v4-plan.md §5 against the stress fixtures. CI green. HTML5 OPFS round-trip either tested (if headless-browser GUT works) or documented as a Sponsor-soak probe target in `team/tess-qa/m2-acceptance-plan-week-2.md` (NEW doc, see W2-T10 below).
- **Risk note:** R1 (save migration) deepening. Sixth bump in M1+M2 history was clean in week-1; stress fixtures are belt-and-braces for the load-bearing system. Risk is "headless-browser GUT runner doesn't exist yet" — if it doesn't, fall back to Sponsor-probe-target documentation; don't gate the ticket on a new infra build.

### W2-T6 — `feat(content): stratum-2 boss balance pass + soak observations`

- **Owner:** Drew (TRES edits); Priya assists on balance-pin mirror (analogous to M1 affix-balance-pin pattern)
- **Depends on:** W2-T3 (S2 boss landed with M1-boss-mirror numbers as starting baseline)
- **Size:** S (1-2 ticks; **M (3-5)** if Sponsor's soak signals 2× deviation per pin §4 acceptance bands and a second balance-pass tick fires)
- **Priority:** **P1** (deferrable to M2 week-3 if T3 ships with reasonable initial numbers)
- **Scope:** Edit `resources/mobs/s2_boss.tres` to apply S2-scaled numbers per W2-T4 stratum-scaling (S2 +20% HP / +15% dmg as baseline). Run soak observations against W2-T3's first-impl numbers — analogous to M1 affix-balance-pin §4 "Player feel acceptance targets" but for boss-fight specifically. Targets: L5 fully-geared S2 boss kill ≤90s (vs M1 boss ≤60s — S2 is +50% headroom), boss-fight feels distinct from S1 boss (different telegraph cadence, different breath-cone vs M1's slam-attack). New doc `team/priya-pl/s2-boss-balance-pin.md` (or extend `affix-balance-pin.md` with §5 "S2 boss balance"). Drew or Priya adjusts if soak signals deviation. **NOT in scope:** boss-music balance (cross-stratum reuse in week-2; W2-T9 sources unique S2 boss music or defers to M3); arena-layout balance (W2-T3 ships the arena; this ticket is mob-stat-only).
- **Acceptance:** `s2_boss.tres` numbers committed; balance-pin doc references §"S2 boss balance" or new file. Soak observation appended to doc with tick-stamp. If 2× deviation observed, second tick lands a tweak; otherwise ticket closes paper-trivial. Cross-link to M1 affix-balance-pin.md as precedent.
- **Risk note:** W3 (boss state-machine complexity carry from M1 watch-list) + the M1 R7 (affix balance hand-tuning sinkhole) lesson applied. Mitigation: pre-pin numbers per M2-affix-pin precedent; soak-observation framing not pre-merge gates; fix-forward via second tick if needed.

### W2-T7 — `feat(ui): stash UI iteration v1.1 — Sponsor-soak feedback consumption`

- **Owner:** Devon (impl); Uma assists on copy/microcopy + visual sign-off
- **Depends on:** M2 week-1 T3 + T7 + T8 + T9 all on `main`; Sponsor's M2 week-1 soak feedback (filed as `bug(ux):` or `chore(ux-iterate):` tickets with severity + root-cause tags per Tess's bug template)
- **Size:** M (3-5 ticks; **S (1-2)** if Sponsor's soak surfaces no UX-grade pushback)
- **Priority:** **P1** (conditional on Sponsor soak signal — promotes to P0 if Sponsor flags discoverability or affordance)
- **Scope:** Iteration on stash UI based on Sponsor's M2 week-1 soak observations. **Anticipated iteration surfaces** (per `stash-ui-v1.md §7` open questions):
  - **Stash discoverability** (open question 1) — if Sponsor flags "where do I put my stuff?", add a hint-strip Beat refinement on stash-room first-entry (already in §3 Beat — likely just copy/microcopy polish or duration tweak).
  - **Tab+B coexistence** (open question 8) — if Sponsor opens Tab + B together and confuses, refactor input precedence (recommend: Tab opens inventory-only, B opens stash-only, both-held shows side-by-side per §1; iteration if Sponsor wants different).
  - **Stash-discard undo window** (open question 9) — if Sponsor accidentally discards T2+ gear and the Y/N confirm wasn't sufficient, add an undo-toast pattern (8 s window).
  - **One-bag-replacement friction** (open question 4 in save-schema-v4-plan §9) — if Sponsor double-deaths and loses the first bag silently, add a confirm-on-second-death-overwrite flow OR escalate to N-bags-per-stratum (which requires save-schema migration; defer to M3 if so).
- **Acceptance:** Sponsor's filed `bug(ux):` / `chore(ux-iterate):` tickets all closed with code changes. Updated tests cover the iteration. If `stash-ui-v1.md` design assertions changed, doc gets a v1.1 revision (Uma authors). DECISIONS.md amendment if any design lock changed (e.g., one-bag-per-stratum → N-bags would be a DECISIONS.md amendment).
- **Risk note:** R6 carry — Sponsor-found-bugs flood disposition. Mitigation: ticket scope is bounded by Sponsor's actual feedback; if no feedback, ticket closes paper-trivial. Don't pre-implement speculative iterations.

### W2-T8 — `feat(progression): ember-bag tuning v2 — soak observations + edge polish`

- **Owner:** Devon (impl); Tess assists on edge-case re-coverage
- **Depends on:** M2 week-1 T7 (ember-bag pickup on `main`); Sponsor's M2 week-1 soak feedback
- **Size:** S (1-2 ticks)
- **Priority:** **P1** (conditional on Sponsor soak signal; promotes to P0 if Sponsor flags any of the §2 edge cases as bug-grade)
- **Scope:** Tuning + edge-case polish on ember-bag pickup based on Sponsor's M2 week-1 lived experience. **Anticipated tuning surfaces** (per `stash-ui-v1.md §2` edge-case table):
  - **Bag-pickup feedback duration** — if Sponsor's "ember-rise whoosh" ducks too short or the toast clears too fast (currently 4 s per §3), tune duration.
  - **Bag-recovery prompt distance** — if Sponsor walks past bags without seeing them, increase the proximity glow radius (currently 3 tiles, tune to 5-6 if signal).
  - **Stratum-entry banner timing** — if the "pending bag" banner is too punchy or too subtle (currently 2 s slide-in), tune.
  - **One-bag-replacement messaging** — if Sponsor confused about the "replaces previous bag" rule (per stash-ui-v1.md §2 "Bag-on-bag-on-same-tile" note), add an explicit confirm + amend `stash-ui-v1.md` doc if needed.
- **Acceptance:** Sponsor's filed `bug(ember-bag):` / `chore(ember-bag-iterate):` tickets all closed. Edge-case tests updated. `stash-ui-v1.md §2` edge-case table revised if any assertion changes.
- **Risk note:** Same as W2-T7 (R6 carry). Bounded scope, paper-trivial close if no feedback.

### W2-T9 — `design(audio)+source: M2 audio sourcing close-out (mus-stratum2-bgm + mus-boss-stratum2 + amb-stratum2-room)`

- **Owner:** Uma (sourcing + direction); Devon (wiring into bus structure)
- **Depends on:** M2 week-1 T10 (audio sourcing pass — landed placeholder loops OR landed hand-composed full versions); `team/uma-ux/audio-direction.md` rows 87, 97 (if v1.1 nudge merged for ambient direction)
- **Size:** M (3-5 ticks)
- **Priority:** **P1** (placeholder loops from week-1 are acceptable for M2 RC ship — promotes to P0 only if Sponsor flags music as feel-grade-blocker)
- **Scope:** Close out the M2 audio sourcing — three cues to finalize:
  - `mus-stratum2-bgm` — Cinder Vaults harmonized direction (hand-composed final OR curated find that hits the dark-folk chamber direction); replaces week-1 placeholder if applicable.
  - `mus-boss-stratum2` — boss music for W2-T3's Vault-Forged Stoker. **Decision point:** ship with cross-stratum reuse of `mus-boss-stratum1` (M2 RC acceptable) OR source unique S2 boss music. Recommend: cross-stratum reuse for M2 RC; M3 sources unique boss music when content authoring stabilizes. If sourcing capacity allows, ship unique.
  - `amb-stratum2-room` — Cinder Vaults ambient (steam-hiss + scree-rustle + faint vein-pulse hum direction per Uma's deferred v1.2 nudge); replaces week-1 placeholder.
- **Acceptance:** Three cues either landed at q5/q7 OGG per `audio-direction.md §4` source-of-truth flow OR documented as deferred to M3 with rationale (Sponsor-soak signal). 5-bus structure unchanged. `mus-boss-stratum2` decision logged in DECISIONS.md (cross-stratum-reuse OR unique).
- **Risk note:** R10 carry from week-1. Hand-composed cycle time risk same as week-1 — placeholder fallback explicit. M2 RC can ship without unique boss music (M1 set the precedent of cross-stratum-similar music being acceptable).

### W2-T10 — `qa(integration): M2 acceptance plan week-2 + paired GUT tests for week-2 deliverables`

- **Owner:** Tess
- **Depends on:** **None** — runs parallel to W2-T1..T9 from week-2 day-1 (same pattern as M2 week-1 T12 omnibus)
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (Tess's M2 acceptance plan needs to extend coverage to week-2 deliverables; without it, the testing bar can't fire on week-2 PRs)
- **Scope:** (1) `team/tess-qa/m2-acceptance-plan-week-2.md` (NEW doc, OR extend `m2-acceptance-plan-week-1.md` with §"Week 2") enumerating acceptance rows for W2-T1..W2-T9. New rows: ST-29..ST-32 (stash UI iteration acceptance), EM-1..EM-5 (ember-bag tuning acceptance), S2BR-01..S2BR-12 (S2 boss room acceptance, mirrors `tests/test_stratum1_boss.gd` 12-coverage-points), MR-1..MR-5 (MobRegistry acceptance — 4 from W2-T4 §"Acceptance" + 1 cross-suite refactor). (2) Paired test stubs pre-committed: `tests/test_stratum2_rooms_v2.gd` (extends week-1 T12's `test_stratum2_rooms.gd`), `tests/test_stratum2_boss.gd` + `tests/test_stratum2_boss_room.gd`, `tests/test_mob_registry.gd`, `tests/test_save_v4_stress.gd` (overlaps W2-T5 — Tess co-owns). (3) Sponsor probe targets enumerated for week-2 specifically: stash UI affordance probes, ember-bag pickup probes, S2 boss-fight feel probes, audio sourcing acceptance probes. (4) HTML5 audit re-run pattern from W3-A5 / week-1 T11 applied to `m2-rc2` (or whichever week-2 RC tag fires). (5) Test-pass count delta projected (M2 week-1 baseline +60-80 from T12 → M2 week-2 target +40-60 from T1-T9 paired tests).
- **Acceptance:** Acceptance plan doc on `main`. Paired test stubs pre-committed (PENDING-test idiom for stubs that need feature impl first, per Tess's W3-A5 audit precedent). Sponsor probe target list updated. Tess sign-off process documented for week-2 cadence (testing bar §Tess).
- **Risk note:** R2 (Tess bottleneck) — week-2 has a heavier sign-off load than week-1 (12 tickets vs 12, but week-2 includes more iteration tickets which have shorter sign-off cycles). Mitigation: parallel scaffold pattern from W3-A3 / M2 T12 reduces per-PR sign-off cost.

### W2-T11 — `qa(bugbash): M2 week-2 close exploratory pass + Sponsor-soak fix-forward absorber`

- **Owner:** Tess (bug-bash); Devon/Drew (fix-forward)
- **Depends on:** Sponsor's M2 week-1 soak findings (if Sponsor soaks at week-1 close); week-2 RC build (`m2-rc2` per W2-T10)
- **Size:** M (3-5 ticks; **L (6-10)** if Sponsor surfaces ≥3 P0 bugs per the M1 R6 escalation pattern)
- **Priority:** **P0** (R6 mitigation discipline — reserve buffer ticks for Sponsor-soak fix-forward + end-of-week-2 exploratory pass)
- **Scope:** Two halves. **Half A — Sponsor-soak fix-forward absorber:** if Sponsor soaks the M2 week-1 RC and surfaces bugs, this ticket is the budget for Tess triage + Devon/Drew fix-forward. Bug template (M1 pattern) applies; severity calls per Priya. **Half B — End-of-week-2 exploratory bug-bash:** Tess runs an exploratory pass on the week-2 RC against the M2 acceptance plan (T10) — covers stash UI iteration, ember-bag tuning, S2 boss fight, S2 rooms 2-3, audio sourcing close-out. Files everything found per `team/tess-qa/bug-template.md`. **Buffer-pattern from W3-A6** — capacity is reserved up-front; if Sponsor surfaces nothing and Half B finds nothing, ticket closes early and the buffer turns into M2 week-3 capacity.
- **Acceptance:** Half A: all Sponsor-filed M2 week-1 bugs either fix-forwarded or rationale-deferred (with DECISIONS.md amendment if scope change). Half B: end-of-week-2 bug-bash log appended to `team/tess-qa/soak-<date>.md` (or new file); zero blockers + zero majors at week-2 close (or open with severity tags + week-3 disposition).
- **Risk note:** R6 (Sponsor-found-bugs flood, escalated 2026-05-03). Mitigation: bounded buffer up-front; Tess-first triage discipline; pattern of "≥1 P0 in soak = soak-stopper" applied (per refreshed R6 trigger threshold).

### W2-T12 — `design(m3-seeds): M3 framing — multi-character / hub-town / persistent meta-progression`

- **Owner:** Priya (framing); Uma assists on hub-town visual direction; Devon assists on save-schema implications
- **Depends on:** **None** — pure design / scoping work. Consumes (a) `mvp-scope.md §M3` ("Content Complete" paragraph — minimal current shape), (b) `stash-ui-v1.md §7 open questions` (multi-character stash sharing, hub-town generalization), (c) `save-schema-v4-plan.md §2.5` (Devon's M3-multi-character hint), (d) `palette.md` strata 3-8 indicative direction (Uma's S3-S8 refinement landed PR #103).
- **Size:** M (3-5 ticks)
- **Priority:** **P2** (deferrable; M3 is a milestone away. Worth shaping now to inform M2 polish decisions but doesn't gate week-2 throughput.)
- **Scope:** New doc `team/priya-pl/m3-design-seeds.md` — three sections:
  - **§1 Multi-character.** Sponsor open question (per save-schema-v4-plan.md §2.5 Devon hint). Three shapes possible: (a) one save slot, multiple characters under it; (b) multiple save slots, each with one character; (c) one character with respec/class-swap mid-run. Recommend (b) for Diablo II / NG+ Paragon-shape simplicity. Save schema implications: `data` key per slot; current single-slot pattern generalizes naturally. Stash sharing decision (per stash-ui-v1.md §7 open question — shared across characters, or per-character). Recommend shared (Diablo II / Path of Exile precedent).
  - **§2 Hub-town.** Stash-room evolution (per stash-ui-v1.md §7 open question 4). M2 stash-room is per-stratum entry; M3 hub-town is one persistent "between-runs" location with NPCs (lore-keeper, reroll-bench eventually, bounty-board eventually). Sponsor open question. Recommend M3 hub-town as evolution of M2 stash-room (same scene-tree pattern, more chrome).
  - **§3 Persistent meta-progression.** Sponsor open question. Three shapes: (a) Hades-style mirror + boons that persist across runs; (b) Diablo II-style Paragon levels + skill-tree-respec; (c) Crystal-Project-style overworld unlocks. Recommend (a) + (b) hybrid — meta-currency unlocks in hub-town + Paragon levels for endgame. Save schema implications: new `meta_progression` block under root (NOT under `character.` since meta is account-wide not character-wide).
- **Acceptance:** Doc on `main` (PR with 200-400 lines). Three sections each with: shape, recommendation, Sponsor-input items, save-schema implications, dependencies on M2 closures. Cross-references stash-ui-v1.md / save-schema-v4-plan.md / palette.md / mvp-scope.md §M3.
- **Risk note:** None new — pure design scoping. Risk is "design seed gets misread as design lock" — caveat clearly that this is *seeds*, not *locks*, and Sponsor has the final word on M3 shape.

---

## Risks (forward-look)

Re-score of the risk register for M2 week-2 entry. Top-3 active risks for M2 week-2:

### R1 (held — sixth schema bump landed clean in week-1; stress tests in week-2)

**Save migration breakage between schema versions.**

- Probability: **med** (held).
- Impact: **high** (held).
- M2 week-2 context: v3→v4 landed clean in week-1 T1; stress fixtures in week-2 T5 are belt-and-braces. Pattern is robust across six bumps now (v0→v1→v2→v3 in M1; v3→v4 in M2). New JSON shape (Dictionary-of-Dictionary in `ember_bags`) survived first round-trip on `main`; W2-T5 stress fixtures are insurance.
- Mitigation: W2-T5 eight new stress fixtures + HTML5 OPFS round-trip test (or Sponsor probe target if headless GUT not available). Save-touching PR discipline (migration test OR explicit no-schema-change note) continues.
- **Watch signal:** any save-touching PR that ships without a migration test; any Tess soak run where reload doesn't preserve a known field.
- **Owner:** Devon (implements migration), Tess (validates), Priya (enforces gate).

### R8 (held — week-1 lived experience feeds week-2 iteration scope)

**Stash UI complexity (week-1 carry).**

- Probability: **med** (lowered from high — week-1 surfaced complexity in implementation, scope is now better-bounded).
- Impact: **med** (lowered from med-high — week-1 stub-then-interactive split worked; iteration scope is bounded).
- M2 week-2 context: W2-T7 absorbs Sponsor's stash-UI feedback iteration. Bounded scope by Sponsor's actual feedback; speculative iterations not pre-implemented. If Sponsor flags multiple affordance changes, T7 grows from M to L; risk re-promotes accordingly.
- Mitigation: Sponsor-feedback-driven scope (don't iterate ahead of evidence); copy/microcopy iteration is the lightest class; affordance changes are heavier; design-lock changes (e.g., one-bag → N-bags) require DECISIONS.md amendment, not silent edit.
- **Watch signal:** W2-T7 in flight for >5 ticks; ≥3 distinct stash-UI complaints from Sponsor; any Sponsor pushback on B-binding fundamentals (vs. tweaks).
- **Owner:** Devon (implement), Uma (UX hand-off + visual sign-off), Priya (size sentinel).

### R9 (held — stratum-2 content triple-stack continues into week-2)

**Stratum-2 content authoring triple-stack on Drew + Uma.**

- Probability: **high** (held).
- Impact: **med** (held).
- M2 week-2 context: W2-T1 (s2 rooms 2-3), W2-T2 (5 soft-retint sprites), W2-T3 (S2 boss room first impl) all stack on Drew. W2-T9 (audio sourcing close-out) stacks on Uma. Same shape as week-1 R9 — but with the addition of S2 boss room (largest week-2 ticket). Drew's load is heavier in week-2 than week-1 (3 content tickets vs 3 in week-1, but week-2 includes the L-sized boss-room first impl).
- Mitigation: Per-sprite cost bounded for soft-retints (W2-T2 = palette-swap only; not new silhouettes). Hex-block fallback continues for any rooms that ship before sprites land (week-1 pattern). Drew's affix-balance-pin precedent (paper-trivial pre-pin) applies to W2-T6 boss balance pass. **W2-T3 stub-then-iterate** — first impl ships with M1-boss-mirror numbers; soak signals balance pass.
- **Watch signal:** W2-T1 / W2-T2 / W2-T3 all in flight at the same heartbeat tick without a closure; Drew's STATE.md run-bump frequency drops; placeholder-vs-final art question raised in PR review.
- **Owner:** Drew (sprite + content authoring), Uma (UX direction + audio sourcing), Priya (capacity guardrail).

### Demoted risks (held but not top-3 for M2 week-2)

- **R3-M2 (HTML5 export regression, M2-introduced surfaces):** week-1 introduced six new HTML5 surfaces (v4 schema, stash UI, ember-bag, S2 entry, Stoker mob, audio). If week-1 close held without HTML5 audit-grade findings, R3-M2 holds at week-2 entry. W2-T11 absorbs any week-1-soak HTML5 findings. Re-promote if Sponsor's week-1 soak surfaces ≥1 HTML5-specific bug.
- **R6 (Sponsor-found-bugs flood):** materially active when Sponsor soaks. M2 week-2 reckons with Sponsor's week-1 findings via W2-T7 / W2-T8 / W2-T11. Re-promote when M2 week-2 RC reaches Sponsor.
- **R10 (audio sourcing latency):** held; W2-T9 explicit P1 with placeholder-fallback discipline. Same shape as week-1 T10 risk.
- **R11 (integration-stub shipped as feature-complete):** mitigation discipline (`product-vs-component-completeness.md` orchestrator memory, Done-clause "instantiated in play surface" rule, carry-over visibility) continues into M2. Watch signal: any subsystem PR claim that doesn't touch the entry-point scene path. **No active firing in M2 week-1** (assumption; verify at week-1 close).
- **R12 (orchestrator-bottleneck-on-dispatch):** mitigation (`always-parallel-dispatch.md` memory, tightened cron-prompt) continues. Watch signal: user override frequency. **No active firing assumed** at M2 week-2 entry (verify at week-1 close).
- **R2 (Tess bottleneck):** structural risk, currently inverted. T10 parallel scaffold continues per week-1 T12 pattern.
- **R4 (scope creep):** M2 scope enumerated in week-1 + week-2 backlogs + DECISIONS.md M2 entries. Drift risk symmetric to M1. Manageable.

---

## Capacity check

**M2 week-1 throughput target: 12 tickets** (per `m2-week-1-backlog.md` §"Capacity check").
**M2 week-2 ceiling: ~12 tickets** (mirror of week-1; week-1 actual throughput informs week-2 sentinel — if week-1 ships 12 clean, week-2 holds; if week-1 ships 9-10 with carry-overs, week-2 trims to 10).

**Proposed: 12 tickets (W2-T1..W2-T12).** 8 P0 + 3 P1 + 1 P2.

| Bucket | Count | Tickets |
|---|---|---|
| **P0** | 8 | W2-T1, W2-T2, W2-T3, W2-T4, W2-T5, W2-T10, W2-T11, plus W2-T7/T8 if Sponsor signals promote them |
| **P1** | 3 | W2-T6 (S2 boss balance — defer-to-soak), W2-T7 (stash iteration — Sponsor-conditional), W2-T8 (ember-bag tuning — Sponsor-conditional), W2-T9 (audio sourcing close-out — placeholder-fallback acceptable) |
| **P2** | 1 | W2-T12 (M3 design seeds — pure framing, deferable) |

(Note: W2-T7/T8 are listed as P1 by default; if Sponsor's M2 week-1 soak surfaces ≥1 P0 in either, they promote in-place. Same conditional pattern as W2-T9 / W2-T11 Half-A.)

**Trim to 10 if needed:** drop W2-T6 (S2 boss balance — defer to week-3) + W2-T12 (M3 seeds — defer to M2 close retro). Outcome: M2 week-2 ships rooms 2-3 + soft-retints + boss room first impl + MobRegistry + stress fixtures + iteration tickets + acceptance plan + bug-bash. Acceptable shape for M2 RC.

**Trim to 8 if Sponsor's M2 week-1 soak surfaces blockers and W2-T11 absorbs heavier-than-expected capacity:** drop W2-T6 + W2-T9 (audio sourcing — keep placeholders) + W2-T12 + W2-T8 (defer ember-bag tuning to soak observation). Ship W2-T1+T2+T3+T4+T5+T7+T10+T11. Acceptable shape for M2 RC if Sponsor accepts placeholder audio + cross-stratum-reuse boss music.

**Capacity estimate by owner:**

- **Devon:** W2-T4 (MobRegistry refactor), W2-T5 (stress fixtures — co-owned with Tess), W2-T7 (stash iteration impl — conditional), W2-T8 (ember-bag tuning impl — conditional), W2-T9 (audio wiring) = 4-5 tickets. **Lighter than week-1's 7** — appropriate, since week-1 was heavy with first-impl work and week-2 is iteration + scaffolding work.
- **Drew:** W2-T1 (s2 rooms 2-3), W2-T2 (soft-retint sprites), W2-T3 (S2 boss room first impl L), W2-T6 (S2 boss balance pass) = 4 tickets. **Heaviest individual ticket = W2-T3 boss room (L-sized).** Same load shape as week-1's 3 (which was M+M+L). Mitigation: hex-block fallback for sprites; stub-then-iterate for boss; balance-pin precedent for W2-T6.
- **Uma:** W2-T7 (stash iteration UX hand-off — conditional), W2-T9 (audio sourcing close-out), W2-T12 (M3 hub-town visual direction assist) = 2-3 tickets. **Light load** — appropriate; W1 art bottleneck mitigation continues.
- **Tess:** W2-T5 (co-owned), W2-T10 (omnibus parallel scaffold), W2-T11 (bug-bash + Sponsor-soak fix-forward absorber) = 3 tickets + ad-hoc per-PR sign-offs. Same pattern as week-1 T12 + ad-hoc.
- **Priya:** W2-T6 assist (balance pin), W2-T12 (M3 design seeds primary), week-2 close retro (implicit, not in ticket count). **2 tickets + retro** — typical PL load.

**Buffer:** 2-3 free dev ticks reserved for reactive work. **Bigger buffer than week-1** (which had 2) because week-2 absorbs Sponsor-soak fix-forward from week-1 — risk of cascading findings is non-zero.

---

## Open questions for Sponsor

Mostly **none blocking**. Listed here so the orchestrator can route them when they surface in M2 dispatches.

1. **M3 framing — multi-character / hub-town / persistent meta-progression** (W2-T12). Pure design / scoping question, defer to post-M2-RC conversation. Recommendations in W2-T12 doc, but Sponsor has final word. **Default:** Priya's recommendations ship as design-seeds doc; Sponsor confirms or course-corrects when M2 RC reaches him. Doesn't block M2 throughput.
2. **Stash UI iteration scope** (W2-T7). What does Sponsor actually want changed? Speculative iterations not pre-implemented. **Default:** wait for Sponsor's M2 week-1 soak feedback; ticket scope is Sponsor's actual feedback only.
3. **Ember-bag tuning scope** (W2-T8). Same shape as W2-T7. **Default:** wait for soak feedback.
4. **S2 boss music — cross-stratum reuse OR unique?** (W2-T9). Recommendation: cross-stratum reuse for M2 RC; unique sourced in M3. Sponsor may prefer unique. **Default:** cross-stratum reuse ships unless Uma's sourcing capacity allows unique without latency cost.
5. **MobRegistry as a refactor cost** (W2-T4). The decision was deferred from week-1 T6 stretch. Worth doing now (the dispatch table is going to grow with every new mob); risk is the refactor itself touches every existing mob spawn-path. **Default:** ship the refactor in week-2 (no Sponsor input needed; Devon's call within his lane). Alternative: keep the match-block growing and refactor at M3 onset. Recommend ship-now.

None of these block dispatch. All are revisable post-merge if Sponsor surfaces a clear preference.

---

## Hand-off

When M2 week-1 close retro lands + bug-bash drains:

- **Orchestrator:** dispatch W2-T1 (Drew s2 rooms 2-3) and W2-T4 (Devon MobRegistry) **in parallel** as the first M2-week-2 dispatches. W2-T10 (Tess parallel acceptance scaffold) dispatches on the same heartbeat tick. W2-T2 (Drew soft-retint sprites) dispatches in parallel with W2-T1 if sprite work doesn't block room authoring (it shouldn't — hex-block fallback continues). W2-T3 (S2 boss room L) cascades after W2-T1 + W2-T2 land.
- **Devon:** picks up W2-T4 first (MobRegistry refactor — no dependencies); W2-T5 (stress fixtures co-owned with Tess) follows; W2-T9 (audio wiring) is small + can run after Uma's sourcing closes. W2-T7/T8 conditional on Sponsor week-1 soak findings.
- **Drew:** picks up W2-T1 (s2 rooms 2-3) first; W2-T2 (sprites) parallel if Drew can context-switch; W2-T3 (S2 boss room first impl) cascades after rooms + sprites are at-pixel; W2-T6 (boss balance pass) is paper-trivial follow-up to W2-T3.
- **Uma:** continues post-week-1 audio direction nudges (audio-direction.md v1.2 if landed); picks up W2-T9 (M2 audio sourcing close-out) when Devon needs the streams; W2-T7 visual hand-off if Sponsor flags stash UX; W2-T12 (M3 hub-town visual direction assist) is light.
- **Tess:** dispatches on day-1 with W2-T10 omnibus parallel scaffold + W2-T5 stress fixtures co-owned with Devon. W2-T11 (bug-bash + Sponsor-soak absorber) is mid-week-to-end-of-week.
- **Priya:** authors `m2-week-1-retro.md` at week-1 close (pre-condition for this backlog); monitors W2-T3 + W2-T7 capacity guardrails; W2-T12 (M3 design seeds) primary owner; M2 week-2 close retro at week-2 boundary.

---

## Caveat — this is a draft, not a contract

This document is **doubly anticipatory planning**. It is revisable in any of these cases:

- **M2 week-1 close brings carry-overs** — if T3 split, T6 didn't fold MobRegistry, T10 shipped placeholder-only, this backlog absorbs the carry-over. Most likely revision.
- **Sponsor's M2 week-1 soak surfaces blockers/majors that adjust M2 week-2 scope** — second most likely revision.
- **Sponsor's M2 week-1 soak surfaces design pushback on stash UI / ember-bag / death-recovery** — re-scope W2-T7 / W2-T8 accordingly.
- **A team member's load capacity shifts** — re-balance Drew's 4-ticket load if W2-T3 is heavier than expected.
- **An M2-week-2 follow-on design question lands** that wasn't anticipated — e.g., scree slip-zone mechanic gets greenlit (palette-stratum-2.md §8 q2), adding a new ticket.

Revisions land as a v1.1 of this doc, with the changed sections diff-highlighted and a one-line DECISIONS.md append referencing the change.

**This draft is the path of least resistance from M2 week-1 close → M2 vertical slice ready for Sponsor RC.** It is not the only path.

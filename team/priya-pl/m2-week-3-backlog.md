# M2 Week-3 Backlog (v1.0)

**Owner:** Priya · **Tick:** 2026-05-15 (M2 W2 closed CLEAN per `m2-week-2-retro.md`; W2 RC `embergrave-html5-d9cc159` is the next Sponsor-soak target) · **Status:** **v1.0 — dispatch-ready**, revisable when Sponsor's M2 RC soak findings land or when Uma's AC4 Room 05 balance design ships.

W3 absorbs the W2 carry-over queue PLUS the M2 stratum-2 content authoring track that the original W2 backlog framed but did not ship. This backlog is **not anticipatory** — W2 closed clean and the W2 RC is in hand. The pre-conditions are met.

## TL;DR (5 lines)

1. **Target:** **12 tickets** for M2 W3 (8 P0 + 3 P1 + 1 P2). Mirror of the W2 ceiling; capacity-checked against W2's actual throughput of 22 PRs.
2. **Expected duration:** ~one M2 week (~10-14 ticks active orchestration).
3. **Critical chain:** AC4 Room 05 balance pass (Uma design → Drew/Devon impl) → stratum-2 rooms 2-3 (Drew) → S2 soft-retint sprites (Drew) → S2 boss room first impl (Drew, L).
4. **MobRegistry refactor + v4 save stress fixtures land here** as W2 carry-overs. Audio sourcing close-out (W2-T9 carry) also lands here.
5. **Sponsor-input items:** AC4 balance Path A is locked (user authorized 2026-05-15); M3 design seeds carry from W2 with a soft Sponsor input. The W2 RC will soak in parallel — Sponsor findings feed the buffer absorber ticket.

---

## Source of truth — W3 consumes

1. **`m2-week-2-retro.md`** (Priya, 2026-05-15) — W2 closed clean, 22 PRs merged, 0 blockers / 0 majors / 2 minors (both addressed). The retro's "What didn't ship" list is the W3 carry-over queue: stratum-2 content (T1/T2/T3), MobRegistry (T4), v4 stress fixtures (T5), audio sourcing (T9), M3 design seeds (T12).
2. **`team/tess-qa/soak-2026-05-15.md`** — W2 bug-bash; the two filed minors are `86c9u33h1` (shipped as PR #199, no W3 action needed) and `86c9u33hh` (stale AC4 `test.fail()` annotation — superseded by the Room 05 balance pass per user lock).
3. **`team/uma-ux/ac4-room05-balance-design.md`** (Uma, in flight on `uma/ac4-room05-balance-design` — ticket `86c9u3d7j`). The balance design's four levers per the user lock: chaser damage, iron sword damage, player iframes-on-hit, mob attack recovery. **W3 absorbs the implementation** of whatever the design proposes. If Uma's design lands before this backlog is open, see §"Uma design integration" below.
4. **`m2-week-2-backlog.md` §W2-T1..W2-T5 + W2-T9 + W2-T12** — verbatim source-of-truth for the carry-over tickets. W3 inherits their acceptance criteria + risk notes + dependencies.
5. **`team/priya-pl/risk-register.md`** — top-3 active risks at W3 entry: **R6** (Sponsor-found-bugs flood, re-promoted), **R2** (Tess bottleneck, strained), **R1** (save migration, re-armed). See `m2-week-2-retro.md` §"Risk-register update" for the full picture.
6. **`team/uma-ux/palette-stratum-2.md`** — sprite reuse + soft-retint table (W3-T2 consumes verbatim).
7. **`team/drew-dev/level-chunks.md` § "Multi-stratum tooling (M2 scaffold)"** — used in W3-T1 (stratum-2 rooms 2-3).
8. **`team/devon-dev/save-schema-v4-plan.md`** — used in W3-T6 (v4 stress fixtures).

---

## Pre-conditions — all met at W3 entry

1. ✅ **M2 W2 closes clean.** Verified by `m2-week-2-retro.md` + Tess soak `soak-2026-05-15.md` (0 blockers / 0 majors / 2 minors both addressed).
2. ✅ **W2 RC build green and artifact-ready.** `embergrave-html5-d9cc159` is the RC (release-github.yml run 25895056935). Sponsor-soak handoff is the parallel activity.
3. ✅ **AC4 Path A authorized.** User locked Path A (balance, not harness dodge) on 2026-05-15. Uma is dispatched on the design (ticket `86c9u3d7j`). The balance-pass implementation is a W3 deliverable.
4. ⚠️ **Uma's balance design pending.** Uma's `team/uma-ux/ac4-room05-balance-design.md` is in flight. W3-T1 (AC4 balance pass impl) cannot start until the design lands. **Mitigation:** dispatch the stratum-2 content tickets (W3-T2, W3-T3, W3-T4) in parallel — they don't depend on the balance design.
5. ✅ **No active soak-blockers in W2 RC.** Sponsor's first M2 soak hasn't fired yet; once it does, the buffer absorber ticket (W3-T10) catches fix-forward.

---

## Tickets — M2 W3

12 tickets. Each row: title (ticket-shape), owner, dependencies, size (S/M/L), acceptance criteria, P0/P1/P2 priority.

**Sizing convention:** S = 1-2 ticks, M = 3-5 ticks, L = 6-10 ticks. Total: 4 × S + 6 × M + 2 × L = ~45 ticks across the team in parallel — ≈ 1 M2 week at W2 pace.

**P0 (8):** W3-T1, W3-T2, W3-T3, W3-T4, W3-T5, W3-T6, W3-T9, W3-T10
**P1 (3):** W3-T7, W3-T8, W3-T11
**P2 (1):** W3-T12

---

### W3-T1 — `feat(combat|balance): AC4 Room 05 balance pass — chaser damage + iron sword + iframes + recovery (`86c9u3d7j`)`

- **Owner:** Drew (TRES edits for chaser damage + mob attack recovery), Devon (if Uma's design calls for player iframes-on-hit — Player.gd change), with Tess paired on the GUT + Playwright sweep
- **Depends on:** Uma's `team/uma-ux/ac4-room05-balance-design.md` (in flight on `uma/ac4-room05-balance-design`). Cannot start until Uma's design merges.
- **Size:** M (3-5 ticks; **L (6-10)** if Uma's design calls for new player iframes-on-hit mechanic + Damage formula changes, since both are integration-surface touches)
- **Priority:** **P0** (W2 RC AC4 Room 05 has a known balance issue that requires Path A correction; user-locked. The stale `test.fail()` annotation on the AC4 spec is the QA-visible symptom.)
- **Scope:** Implement whatever Uma's balance design proposes. Likely candidates per the user's framing of the lock decision:
  - **Chaser damage** — adjust `resources/mobs/grunt.tres` and/or `charger.tres` damage values for Room 05's three-concurrent-chaser scenario.
  - **Iron sword damage** — adjust `resources/items/weapons/iron_sword.tres` base_stats.damage if Uma's design re-scales the player's lethality.
  - **Player iframes-on-hit** — if Uma's design adds invulnerability frames after a mob hit, this is a `Player.gd` change with paired tests (will require `Damage.compute_damage_to_player` or equivalent to check iframe state). Likely the heaviest implementation surface in this ticket.
  - **Mob attack recovery** — adjust the post-attack recovery duration on Charger / Shooter (and Grunt if applicable). May require `_state_machine` timing constant edits in the mob scripts.
- **Acceptance:** Paired GUT tests covering each lever Uma's design touches (damage-delta tests, iframe-window tests, recovery-duration tests). Playwright `ac4-boss-clear.spec.ts` clears Room 05 deterministically WITHOUT the position-steered harness dodge — the `test.fail()` annotation removed in the same PR. Release-build verification per HTML5 visual gate (iframe-on-hit is a `modulate` flicker → visual-verification required). Self-Test Report comment per Self-Test Report gate.
- **Risk note:** This is the W3 highest-leverage user-facing ticket. R1 (save migration) is re-armed if iframes-on-hit adds player state; Devon's PR body needs a migration note even if no schema bump is technically required. R2 (Tess bottleneck) — this is a coordinated multi-file PR; flag high-blast-radius in the dispatch brief.

### W3-T2 — `feat(level): stratum-2 second + third rooms (s2_room02 + s2_room03)` (W2-T1 carry)

- **Owner:** Drew
- **Depends on:** M2 W1 T5 (s2_room01 on `main`, verify), W2 soft-retint sprites (W3-T3 — hex-block fallback continues), `palette-stratum-2.md` §3 decoration beats, `level-chunks.md` § "M2 implementer checklist"
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (gate for W3-T4 boss-room first impl)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T1 (the W2 ticket that did not ship). Two new S2 rooms — `s2_room02.tres` + `Stratum2Room02.tscn` (mob mix: 2 Stokers + 1 Charger, soft-retint); `s2_room03.tres` + `Stratum2Room03.tscn` (mob mix: 1 Stoker + 1 Charger + 1 Shooter heat-blasted, plus the `&"boss_door"` port tag for boss-room handoff). Both 480×270 internal canvas with WEST entry / EAST exit. Wire S1→S2 flow per existing descend pattern (`StratumExit.gd`).
- **Acceptance:** Both rooms load, instantiate, build the assembly via `LevelAssembler.assemble_single`, spawn S2 mobs inside bounds. Paired tests in `tests/test_stratum2_rooms.gd`. Player traverses S2 R1→R2→R3 via existing RoomGate flow. RoomGate cleared-state persists via `StratumProgression`.
- **Risk note:** R9 (stratum-2 triple-stack) re-promoted to active for W3. Mitigation: shares `MultiMobRoom.gd` with M2 W1 T5; per-room TRES is the only authoring surface; hex-block fallback continues. **Drew's W3 load is heaviest of M2** (T2+T3+T4 stacked) — parallel-dispatch with Devon on T1/T5/T9 to distribute.

### W3-T3 — `feat(content): stratum-2 sprite soft-retint pass (Charger / Shooter / Pickup / Ember-bag / Stash chest)` (W2-T2 carry)

- **Owner:** Drew
- **Depends on:** `palette-stratum-2.md` §5 (sprite reuse + soft-retint table — consume verbatim), M2 W1 T4 (S2 grunt + Stoker baseline)
- **Size:** M (3-5 ticks; **L** if W2 deferred more than expected)
- **Priority:** **P0** (gate for W3-T2 visual completion + W3-T4 boss-room visual identity)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T2. Five soft-retint sprites per `palette-stratum-2.md` §5 — Charger heat-blasted, Shooter heat-blasted, Pickup glow (Cinder-Rust outer flame), Ember-bag (S2 variant), Stash chest (recommend cross-stratum-constant per stash-ui-v1.md §4 — drops sprite count from 5 to 4). Aseprite source files committed alongside exported PNGs.
- **Acceptance:** S2-PL-04 / S2-PL-05 / S2-PL-09 / S2-PL-10 (palette-stratum-2.md §7 pin) verified via Tess eye-dropper. Daltonization holds (S2-PL-13). Aseprite sources committed.
- **Risk note:** R9 carry. Mitigation: per-sprite cost bounded; hex-block fallback continues for any rooms that ship before sprites land.

### W3-T4 — `feat(boss): stratum-2 boss room first impl — Vault-Forged Stoker` (W2-T3 carry)

- **Owner:** Drew (state machine + scene); Uma assists on intro/boss-treatment design (`team/uma-ux/boss-intro.md` reusable beat structure)
- **Depends on:** W3-T2 (s2_room03 authored as boss-door predecessor), W3-T3 (Stoker sprite as design baseline)
- **Size:** **L** (6-10 ticks — single largest W3 ticket, parallels M1 N6 boss state-machine complexity)
- **Priority:** **P0**
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T3. New stratum-2 boss: **Vault-Forged Stoker** (working name). 3-phase state machine modelled on `Stratum1Boss.gd`: dormant → idle → chasing → telegraphing_breath → breathing → telegraphing_slam → slamming → phase_transition → dead. Phase boundaries 66% / 33%. Phase 3 enrage: 1.5× speed, 0.7× recovery, breath-cone widens. `s2_boss_room.tres` + `Stratum2BossRoom.tscn` with mining-shaft cathedral layout. Entry sequence per `boss-intro.md` Beat-1 to Beat-5 (1.8s). T3 weapon + T2/T3 gear loot. **Stub-then-iterate** — first PR ships with M1-boss-mirror numbers; soak signals balance pass (W3-T8 below).
- **Acceptance:** All 12 task-spec coverage points from M1 boss N6 (full HP / phase-1 / phase-2 transition / phase-2 attacks / phase-3 / phase-3 enrage / boss_died / i-frames / loot drop / hit-spam idempotence / damage-during-transition / room-state reset). Paired tests in `tests/test_stratum2_boss.gd` + `tests/test_stratum2_boss_room.gd`. Player completes S1→S2 R1→R2→R3→S2 boss → defeated → terminator screen. Tab-blur edge probe + console-error round-trip.
- **Risk note:** Largest W3 ticket. Risk: boss state-machine complexity + new "breath cone" mechanic. Mitigation: state machine modelled on Stratum1Boss directly; breath-cone reuses Stoker telegraph from M2 W1 T6 (just larger / wider); intro pattern reuses boss-intro.md verbatim.

### W3-T5 — `feat(content): MobRegistry autoload — stratum-aware mob lookup + scaling` (W2-T4 carry)

- **Owner:** Devon (engine + autoload); Drew assists on s1/s2 mob_id registration + scaling-multiplier signoff
- **Depends on:** M2 W1 T6 (Stoker landed; MobRegistry sketch in `MobSpawnPoint.gd` doc-comment per `level-chunks.md`)
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (the `MultiMobRoom._spawn_mob` match-block is now growing with every new mob; refactor before it becomes a maintenance hotspot)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T4. New autoload `scripts/content/MobRegistry.gd`. Maps `mob_id: StringName → MobDef + MobScene + scaling_multipliers: Dictionary[StringName, float]`. Methods: `get_mob_def(mob_id)`, `get_mob_scene(mob_id)`, `apply_stratum_scaling(mob_def, stratum_id) -> MobDef`. Refactor `MultiMobRoom._spawn_mob` from match-block to `MobRegistry.spawn(mob_id, position, room_node)`. Stratum-scaling: S1 baseline 1.0, S2 +20% HP / +15% dmg per `mvp-scope.md §M2`. Register in `project.godot`.
- **Acceptance:** `tests/test_mob_registry.gd` (paired) covers registry round-trip, stratum-scaling math, mob_id-not-found graceful return, scaling-doesn't-mutate-source invariant. `MultiMobRoom` refactor doesn't regress any M1 / M2 mob-spawn test.
- **Risk note:** Refactor risk — touches every M1 + M2 room. Mitigation: paired tests stay green throughout; refactor is mechanical (extract match-block dispatch, no behavior change). **Verify M2 W1 status:** the W2 backlog assumed MobRegistry MAY have been folded into M2 W1 T6 Stoker. **Quick check at dispatch time:** if W1 T6's Stoker PR did fold MobRegistry, this ticket retires; if not, ship as written.

### W3-T6 — `feat(save): schema v4 stress test fixtures + HTML5 OPFS round-trip` (W2-T5 carry)

- **Owner:** Tess (fixtures + tests); Devon assists on OPFS-specific edge cases
- **Depends on:** M2 W1 T1 + T2 (v3→v4 migration + SaveSchema autoload on `main`); `team/devon-dev/save-schema-v4-plan.md` §6 (fixture catalog)
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (R1 mitigation deepening — re-armed in W3 because W3-T1 balance-pass may add player state)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T5. Eight new stress-fixture files under `tests/fixtures/v4/`: `save_v4_full_stash_72_slots.json`, `save_v4_three_stratum_bags.json`, `save_v4_partial_corruption_recovery.json`, `save_v4_max_level_capped_full_inventory.json`, `save_v4_html5_opfs_baseline.json`, `save_v4_html5_opfs_max.json`, `save_v4_idempotent_double_migration.json`, `save_v4_unknown_keys_passthrough.json`. Paired test `tests/test_save_v4_stress.gd`. HTML5 OPFS round-trip runs as `#if HTML5_BROWSER` integration test if Tess can stand up headless-browser GUT; otherwise documented as Sponsor-soak probe target.
- **Acceptance:** Eight fixtures committed. Paired test adds ~12-16 new test cases covering INV-1..INV-8 from save-schema-v4-plan.md §5. CI green. HTML5 OPFS round-trip either tested or documented as probe target in `team/tess-qa/m2-acceptance-plan-week-3.md` (W3-T9).
- **Risk note:** R1 deepening. Risk is "headless-browser GUT runner doesn't exist yet" — fall back to Sponsor-probe-target documentation if so; don't gate on new infra build.

### W3-T7 — `feat(ui): stash UI iteration v1.1 — Sponsor-soak feedback consumption` (W2-T7 carry, conditional)

- **Owner:** Devon (impl); Uma assists on copy/microcopy + visual sign-off
- **Depends on:** Sponsor's W2 RC soak feedback (M2 RC `d9cc159` is the soak target). **Sponsor has NOT yet soaked M2.** If no feedback fires, ticket closes paper-trivial.
- **Size:** M (3-5 ticks; **S (1-2)** if no Sponsor pushback)
- **Priority:** **P1** (Sponsor-conditional; promotes to P0 if Sponsor flags discoverability or affordance)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T7. Iteration on stash UI based on Sponsor's W2 RC soak observations. Anticipated surfaces (per `stash-ui-v1.md §7`): stash discoverability (open question 1), Tab+B coexistence (open question 8), stash-discard undo window (open question 9), one-bag-replacement friction.
- **Acceptance:** Sponsor's filed `bug(ux):` / `chore(ux-iterate):` tickets all closed. Tests updated. `stash-ui-v1.md` v1.1 revision if any design assertions change.
- **Risk note:** R6 carry. Bounded scope by Sponsor's actual feedback.

### W3-T8 — `feat(progression): ember-bag tuning v2 — soak observations + edge polish` (W2-T8 carry, conditional)

- **Owner:** Devon (impl); Tess assists on edge-case re-coverage
- **Depends on:** Sponsor's W2 RC soak feedback
- **Size:** S (1-2 ticks)
- **Priority:** **P1** (Sponsor-conditional)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T8. Tuning + edge-case polish based on Sponsor's lived experience. Anticipated surfaces (per `stash-ui-v1.md §2`): bag-pickup feedback duration, bag-recovery prompt distance, stratum-entry banner timing, one-bag-replacement messaging.
- **Acceptance:** Sponsor's filed tickets closed. Edge-case tests updated.
- **Risk note:** Same as W3-T7 (R6 carry). Bounded scope.

### W3-T9 — `design(audio)+source: M2 audio sourcing close-out (mus-stratum2-bgm + mus-boss-stratum2 + amb-stratum2-room)` (W2-T9 carry)

- **Owner:** Uma (sourcing + direction); Devon (wiring into bus structure)
- **Depends on:** M2 W1 T10 (audio sourcing pass — placeholder loops on `main` OR hand-composed); `audio-direction.md`
- **Size:** M (3-5 ticks)
- **Priority:** **P0** (was P1 in W2; promoted in W3 because the M2 RC will land in W3-W4 and unique S2 audio is the last gap before RC handoff to Sponsor for M2 sign-off)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T9. Three cues: `mus-stratum2-bgm` (Cinder Vaults harmonized direction), `mus-boss-stratum2` (boss music — decision point: cross-stratum reuse OR unique), `amb-stratum2-room` (Cinder Vaults ambient).
- **Acceptance:** Three cues landed at q5/q7 OGG per `audio-direction.md §4` OR documented as deferred to M3. `mus-boss-stratum2` decision logged in DECISIONS.md.
- **Risk note:** R10 carry. Hand-composed cycle time risk. Placeholder fallback explicit.

### W3-T10 — `qa(integration): M2 acceptance plan week-3 + paired GUT tests for week-3 deliverables + Sponsor-soak fix-forward absorber`

- **Owner:** Tess (omnibus); Devon/Drew on fix-forward
- **Depends on:** **None** — runs parallel from W3 day-1 (same pattern as M2 W1 T12 / M2 W2 T10)
- **Size:** M (3-5 ticks; **L (6-10)** if Sponsor surfaces ≥3 P0 bugs in W2-RC soak)
- **Priority:** **P0** (acceptance plan + Sponsor-soak absorber pattern — R6 mitigation)
- **Scope:** Three halves:
  - **Half A — Acceptance plan:** `team/tess-qa/m2-acceptance-plan-week-3.md` (NEW) enumerating acceptance rows for W3-T1..W3-T9. New rows: AC4-BAL-01..AC4-BAL-08 (AC4 Room 05 balance pass acceptance), S2R23-01..S2R23-12 (stratum-2 rooms 2-3 acceptance), S2BR-01..S2BR-12 (S2 boss room acceptance, mirrors `tests/test_stratum1_boss.gd` 12-coverage-points), MR-1..MR-5 (MobRegistry acceptance), SVS-1..SVS-8 (save v4 stress acceptance).
  - **Half B — Sponsor-soak fix-forward absorber:** Sponsor soaks W2 RC (`d9cc159`) in parallel to W3 work. Buffer reserved for triage + fix-forward. Bug template (M1 pattern) applies; severity calls per Priya. **Pattern:** "≥1 P0 in soak = soak-stopper" — fix-forward dispatches at next-tick before W3 new content tickets.
  - **Half C — End-of-W3 exploratory bug-bash:** Tess runs an exploratory pass on the W3 RC (whatever lands by end-of-W3) against the M2 acceptance plan. Files everything found per `team/tess-qa/bug-template.md`. Pattern matches W2 close (`soak-2026-05-15.md`).
- **Acceptance:** Half A: doc on `main`. Half B: all Sponsor-filed bugs fix-forwarded or rationale-deferred. Half C: end-of-W3 bug-bash log appended; zero blockers + zero majors at W3 close.
- **Risk note:** R2 (Tess bottleneck) — W3 has heavier sign-off load than W2 (AC4 balance pass is gameplay-balance review, stratum-2 content is visual-verification heavy). Mitigation: parallel scaffold from day 1.

### W3-T11 — `qa(infra): Playwright artifact-resolve SHA-pin fix` (NEW, surfaced by Tess soak)

- **Owner:** Devon (CI workflow); Tess assists on validation
- **Depends on:** **None**
- **Size:** S (1-2 ticks)
- **Priority:** **P1** (paper-trivial but recurring noise — Tess's W2 soak hit it `playwright-e2e.yml`'s "Resolve artifact run ID" step grabbed a stale pre-#194 artifact when triggered concurrent with a release build; produced a full red Playwright run that was 100% stale-artifact)
- **Scope:** Pin the `playwright-e2e.yml` artifact-resolve step to the matching commit SHA, rather than "latest successful release run on main." Prevents stale-artifact false-positives when Playwright triggers race the release build. Pattern: pass the SHA explicitly to the resolve step; fail loudly if no matching artifact exists rather than fall back to the latest.
- **Acceptance:** Triggering Playwright while a release build is in-flight either waits for the matching artifact or fails fast with a clear "no matching artifact for SHA X" message. Tess's `soak-2026-05-15.md` "Non-obvious findings" §4 verified resolved.
- **Risk note:** None — small CI fix; doesn't gate dispatch.

### W3-T12 — `design(m3-seeds): M3 framing — multi-character / hub-town / persistent meta-progression` (W2-T12 carry)

- **Owner:** Priya (framing); Uma assists on hub-town visual direction; Devon assists on save-schema implications
- **Depends on:** **None** — pure design / scoping work
- **Size:** M (3-5 ticks)
- **Priority:** **P2** (deferrable; M3 is a milestone away)
- **Scope:** Verbatim per `m2-week-2-backlog.md` §W2-T12. New doc `team/priya-pl/m3-design-seeds.md` — three sections: §1 Multi-character (save slot shape, stash sharing), §2 Hub-town (stash-room evolution, NPC patterns), §3 Persistent meta-progression (Hades / Diablo II / Crystal Project hybrid shape, save-schema implications).
- **Acceptance:** Doc on `main` (PR with 200-400 lines). Three sections with shape + recommendation + Sponsor-input items + save-schema implications + dependencies on M2 closures. Cross-references stash-ui-v1.md / save-schema-v4-plan.md / palette.md / mvp-scope.md §M3.
- **Risk note:** None new — pure design scoping. Risk is "design seed gets misread as design lock" — caveat clearly.

---

## Uma design integration

W3-T1 (AC4 Room 05 balance pass impl) depends on Uma's `team/uma-ux/ac4-room05-balance-design.md` (in flight on `uma/ac4-room05-balance-design`, ticket `86c9u3d7j`). At the time this backlog is authored, Uma's design has not yet landed on `main`. **Placeholder handling:**

1. **If Uma's design lands BEFORE this backlog merges:** revise W3-T1's "Scope" §Likely candidates to reference the specific levers Uma proposes (chaser damage value, iron sword damage delta, iframe duration window, mob recovery duration). Treat as a v1.1 of this backlog with a one-line DECISIONS.md append referencing the change.
2. **If Uma's design lands AFTER this backlog merges:** dispatch W3-T1 with Uma's actual levers as the spec; ship a v1.1 amendment of this backlog as a follow-up commit.
3. **If Uma's design proposes a fundamentally different approach** (e.g. NOT one of the four levers in the user lock — maybe a Room 05 spawn-count nerf, or a new "block" mechanic): the user-lock framing ("Path A — balance") still authorizes the fix; the lever choice is Uma's call within her lane. Escalate to user ONLY if Uma's design contradicts the user's stated direction (chaser/sword/iframes/recovery).

---

## Risks (forward-look) — top 3 active at W3 entry

Full re-score in `m2-week-2-retro.md` §"Risk-register update." Top-3 for W3:

1. **R6** (Sponsor-found-bugs flood) — high / high — re-promoted. W2 RC is Sponsor's first M2 soak target; findings are certain. W3-T10 Half B absorbs.
2. **R2** (Tess bottleneck) — med / med — strained in W2 (PR #194 two rounds); W3 has heavier sign-off load (AC4 balance + stratum-2 content). W3-T10 parallel scaffold continues.
3. **R1** (Save migration) — med / high — re-armed if W3-T1 balance pass adds player iframe state. W3-T6 stress fixtures land.

**Re-promoted to top-5 from watch-list:**

- **R9** (Stratum-2 content triple-stack) — high / med — Drew's W3 load is heaviest of M2 (W3-T2 + W3-T3 + W3-T4 + W3-T1 if Drew owns the TRES edits). Mitigation: parallel-dispatch Devon on T1/T5/T9; hex-block fallback continues for sprites.

**Demoted:**

- **R11** (Integration-stub) — held; no active firing in M2 W1+W2; watch-list.
- **R8** (Stash UI complexity) — held; W3-T7 conditional on Sponsor signal.
- **R12** (Orchestrator-bottleneck) — held; auto-status durability shipped in PR #181, no firing in M2 W2.

---

## Capacity check — target vs projected

**W3 target: 12 tickets** (W3-T1..W3-T12). 8 P0 + 3 P1 + 1 P2.

| Bucket | Count | Tickets |
|---|---|---|
| **P0** | 8 | W3-T1, W3-T2, W3-T3, W3-T4, W3-T5, W3-T6, W3-T9, W3-T10 |
| **P1** | 3 | W3-T7 (Sponsor-conditional), W3-T8 (Sponsor-conditional), W3-T11 (CI hardening) |
| **P2** | 1 | W3-T12 (M3 design seeds) |

**Projected throughput:** W2 actual was 22 PRs in ~7 days. W3 should land ~12-14 PRs (more L-sized tickets — boss room + balance pass — so fewer PR count, similar total ticks).

**Trim to 10 if needed:** drop W3-T8 (ember-bag tuning — defer to W4 if no Sponsor signal) + W3-T12 (M3 seeds — defer to M2 close retro). Outcome: AC4 balance pass + stratum-2 content (rooms + sprites + boss) + MobRegistry + stress fixtures + audio + acceptance plan + soak absorber + CI hardening. **Acceptable shape for M2 RC ramp.**

**Trim to 8 if Sponsor's W2-RC soak surfaces blockers:** drop W3-T4 (S2 boss room — defer to W4) + W3-T8 + W3-T11 + W3-T12. Ship W3-T1+T2+T3+T5+T6+T7+T9+T10. **Acceptable shape if Sponsor blocker absorbs heavier-than-expected capacity.**

**Capacity estimate by owner:**

- **Devon:** W3-T1 (if Uma's design calls for iframes), W3-T5 (MobRegistry), W3-T6 (stress fixtures — co-owned with Tess), W3-T7 (stash iteration — conditional), W3-T8 (ember-bag — conditional), W3-T9 (audio wiring), W3-T11 (CI hardening) = **4-7 tickets** depending on Sponsor signal. Heavier than W2 (Devon shipped ~5 PRs).
- **Drew:** W3-T1 (TRES edits), W3-T2 (s2 rooms 2-3), W3-T3 (soft-retint sprites), W3-T4 (S2 boss room L) = **4 tickets**. **Heaviest individual = W3-T4 boss room (L-sized).** Same load shape as W2 backlog's anticipated Drew load. Hex-block fallback + stub-then-iterate patterns hold.
- **Uma:** W3-T1 (balance design — landed pre-W3-T1 impl), W3-T9 (audio sourcing close-out), W3-T12 (M3 hub-town visual direction assist) = **2-3 tickets**. Light load — appropriate.
- **Tess:** W3-T6 (co-owned), W3-T10 (omnibus + absorber), W3-T11 (validation) = **3 tickets + ad-hoc per-PR sign-offs**. Same pattern as W2.
- **Priya:** W3-T12 (M3 design seeds primary), W3 close retro (implicit). **2 tickets + retro.**

**Buffer:** 2-3 free dev ticks reserved for reactive work (Sponsor-soak fix-forward, AC4 balance-pass iteration if first lever doesn't hit).

---

## Open questions for Sponsor

Mostly **none blocking**. Listed for orchestrator routing:

1. **W2 RC soak verdict.** Sponsor's first M2 RC soak. Findings feed W3-T10 Half B + W3-T7/T8 conditional promotion. **Default:** ship W3 work in parallel with soak; absorb findings as they land.
2. **AC4 balance lever choice.** Uma is dispatched on the design (4 levers locked); Sponsor doesn't need to weigh in unless Uma's design proposes something off-spec. **Default:** PL routes Uma's design to user only if it contradicts the user-lock framing.
3. **M3 framing** (W3-T12). Pure design / scoping, deferable to post-M2-RC. **Default:** Priya's recommendations ship as design-seeds doc; Sponsor confirms at M2 RC handoff.
4. **S2 boss music — cross-stratum reuse OR unique?** (W3-T9). Recommendation: cross-stratum reuse for M2 RC. **Default:** cross-stratum unless Uma's sourcing capacity allows unique.

---

## Hand-off

When this backlog merges + Uma's design lands:

- **Orchestrator:** dispatch **W3-T2 (Drew s2 rooms 2-3) + W3-T5 (Devon MobRegistry) + W3-T10 (Tess acceptance plan + absorber)** in parallel as W3 day-1 dispatches. W3-T3 (sprites) parallel to T2 if Drew context-switches. W3-T1 (AC4 balance impl) gates on Uma's design landing.
- **Devon:** picks up W3-T5 (MobRegistry — no dependencies); W3-T6 (co-owned with Tess) follows; W3-T9 (audio wiring) after Uma sourcing closes; W3-T11 (CI hardening) is small and can run any time. W3-T7/T8 conditional.
- **Drew:** picks up W3-T2 (s2 rooms 2-3) first; W3-T3 (sprites) parallel; W3-T4 (S2 boss L) cascades after rooms + sprites land; W3-T1 (AC4 balance TRES) parallel-dispatched when Uma's design lands.
- **Uma:** completes AC4 Room 05 balance design (in flight); then W3-T9 (audio sourcing close-out); W3-T7 visual hand-off if Sponsor flags stash UX; W3-T12 (M3 hub-town visual direction assist).
- **Tess:** dispatches on day-1 with W3-T10 omnibus + W3-T6 stress fixtures co-owned. W3-T10 Half B absorbs Sponsor findings as they land; Half C end-of-W3 bug-bash.
- **Priya:** authors W3-T12 (M3 design seeds primary); monitors W3-T1 + W3-T4 capacity guardrails; M2 W3 close retro at week-3 boundary; **flags AC4 balance design escalation to user only if Uma proposes off-spec direction.**

---

## Caveat — v1.0 dispatch-ready, revisable

This backlog is **v1.0 dispatch-ready** at 2026-05-15. Revision triggers:

- **Uma's AC4 balance design lands** — revise W3-T1 §Scope to reference specific levers (v1.1 amendment).
- **Sponsor's W2 RC soak surfaces blockers/majors** — re-scope W3-T7 / W3-T8 (promote from conditional); promote W3-T10 from M to L if ≥3 P0s.
- **Stratum-2 sprite slippage** — if W3-T3 deferrs more than expected, hex-block fallback ships with W3-T2 / W3-T4.
- **A new M2 design question lands** that wasn't anticipated — e.g. scree slip-zone mechanic gets greenlit (palette-stratum-2.md §8 q2), adding a new ticket.

Revisions land as a v1.x of this doc with the changed sections diff-highlighted and a one-line DECISIONS.md append.

**This v1.0 is the path of least resistance from M2 W2 close → M2 RC ready for Sponsor M2 sign-off.** It is not the only path.

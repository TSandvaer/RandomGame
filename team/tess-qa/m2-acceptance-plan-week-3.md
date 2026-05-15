# M2 Week-3 Acceptance Plan — Embergrave

**Owner:** Tess (QA) · **Phase:** parallel-acceptance scaffold (drafted at W3 day-1, mirrors W2-T10 / W1-T12 idiom) · **Drives:** Tess sign-off gate for W3-T1..W3-T12 of `team/priya-pl/m2-week-3-backlog.md` once those tickets land.

This is the W3 analogue of `team/tess-qa/m2-acceptance-plan-week-1.md` — per-ticket acceptance criteria, edge probes, integration scenarios, and Sponsor-soak targets, layered onto Priya's W3 12-ticket backlog (8 P0 + 3 P1 + 1 P2). **Nothing here ships executable code in this PR**; this is the QA contract Tess flips green when each W3 ticket reaches `ready for qa test`.

The W3 backlog absorbs both the AC4 Room 05 balance pass (Uma's ac4-room05-balance-design impl) AND the W2 carry-over queue (stratum-2 content rooms 2-3 + soft-retint sprites + S2 boss room first impl + MobRegistry + v4 stress fixtures + audio sourcing close-out). The acceptance contract here mirrors that structure.

## TL;DR

1. **Coverage:** **12 W3 tickets** (W3-T1..W3-T12) covered, total **~67 acceptance criteria** + ~30 edge-case probes mapped onto Uma's `ac4-room05-balance-design.md` + the W2 carry-over source-of-truth docs.
2. **Paired-test files:** **5 new GUT files** scaffolded in this PR (see Part 2 — paired test stubs). Each compiles via the GUT `pending()` idiom; Tess fills them in once the corresponding W3 PR lands.
3. **Sponsor probe targets:** **6** — AC4 post-balance feel (Room 05 winnable + satisfying), S2 rooms 2-3 visual identity, S2 boss-fight feel (phase transitions + breath-cone vs M1 slam), audio coherence (S2 BGM + ambient as a different stratum), MobRegistry refactor invisibility, ember-bag tuning v2 (W3-T8 conditional).
4. **HTML5 audit re-run pattern:** the W3 RC (`m2-rc3` or whatever tag fires when W3-T11 closes the artifact pipeline race) gets the same Playwright + Sponsor-soak audit pattern W2 used (`html5-rc-audit-d9cc159` template if Tess re-spins the audit doc; otherwise inherits the W1 audit shape).
5. **AC4 acceptance bands** (from Uma `#86c9u3d7j`): L1 no-dodge melee with starter iron sword clears Room 05 in **12-25s with ≥30% HP remaining** (harness canary band); skilled-dodge play clears in **8-18s with 60-90% HP** (skill-floor band). Rooms 02-04 within ±20% of pre-balance times. Boss times unchanged. Verification: ≥8 release-build runs of the AC4 spec post-balance-pass.

---

## Source of truth

This acceptance plan validates implementation against:

1. **`team/priya-pl/m2-week-3-backlog.md`** (Priya, 2026-05-15, v1.0 dispatch-ready) — the 12 W3 ticket definitions.
2. **`team/uma-ux/ac4-room05-balance-design.md`** (Uma, ticket `86c9u3d7j`, in flight on `uma/ac4-room05-balance-design`) — the AC4 Room 05 balance design (chaser damage trim + player iframes-on-hit). Drives W3-T1.
3. **`team/uma-ux/palette-stratum-2.md` §5 + §6 + §7** — sprite reuse + soft-retint table + daltonization at-risk pairs + hex-code conformance pins. Drives W3-T2 / W3-T3 / W3-T4.
4. **`team/devon-dev/save-schema-v4-plan.md` §5 + §6** — INV-1..INV-8 round-trip invariants + 8-fixture catalog. Drives W3-T6.
5. **`team/uma-ux/audio-direction.md` §3 + §4** — 5-bus structure + OGG q5/q7 sourcing convention. Drives W3-T9.
6. **`team/drew-dev/level-chunks.md` § "Multi-stratum tooling (M2 scaffold)"** — `MobRegistry` sketch + `MultiMobRoom._spawn_mob` refactor surface. Drives W3-T5.
7. **`team/tess-qa/m2-acceptance-plan-week-1.md`** — structural template; M1 + W1 ACs are the floor (nothing in W3 regresses any prior AC). Re-uses the EP-X menu rubric (EP-RT, EP-OOO, EP-DUP, EP-INTR, EP-EDGE, EP-BLUR, EP-MEM, EP-RAPID).
8. **`tests/test_stratum1_boss.gd`** — the 12-coverage-points pattern Tess mirrors in `tests/test_stratum2_boss.gd` for W3-T4.

The M1 + W1 + W2 acceptance contracts are the floor. Every W3 acceptance row implicitly carries "and prior ACs still pass."

---

## Per-ticket acceptance criteria

For each W3 ticket the format is: **acceptance criteria** (concrete, testable) + **verification method** (paired GUT? Playwright spec? Sponsor probe? release-build re-run?) + **pass/fail signal** (what counts as "shipped") + **edge-case probes** (where applicable) + **integration scenario** + **Sponsor-soak target** (where applicable).

### W3-T1 — `feat(combat|balance): AC4 Room 05 balance pass — chaser damage trim + player iframes-on-hit (#86c9u3d7j)`

Drives Uma's `ac4-room05-balance-design.md` to impl. Two TRES integer edits (Drew owns) + one Player.gd block addition for iframes-on-hit (Devon owns).

**Acceptance criteria (8):**

- **W3-T1-AC1 — Grunt damage_base = 2.** `resources/mobs/grunt.tres` line `damage_base = 3` → `damage_base = 2`. Verified via paired test: `tests/test_grunt.gd::test_damage_base_is_two_post_ac4_balance` (or extend existing damage test to assert the 2 value).
- **W3-T1-AC2 — Charger damage_base = 4.** `resources/mobs/charger.tres` line `damage_base = 5` → `damage_base = 4`. Verified via paired test: `tests/test_charger.gd::test_damage_base_is_four_post_ac4_balance` extension.
- **W3-T1-AC3 — Shooter damage_base UNCHANGED.** `resources/mobs/shooter.tres` `damage_base = 5` held (Uma §3.A: "Shooter held at `damage_base = 5`"). Negative-assertion: existing Shooter damage test still passes with the same 5 value.
- **W3-T1-AC4 — Stratum1Boss damage UNCHANGED.** Boss is single-target, not a damage cluster. Verified via existing `test_stratum1_boss.gd` damage tests still pass with the same numbers (regression gate).
- **W3-T1-AC5 — `HIT_IFRAMES_SECS = 0.25` constant added.** New constant in `scripts/player/Player.gd` near `DODGE_DURATION`. Verified via paired test: `tests/test_player_iframes_on_hit.gd::test_hit_iframes_secs_constant_is_quarter_second` (asserts the constant value).
- **W3-T1-AC6 — Player.take_damage grants iframes after damage applies, before _die check.** Per Uma §3.B spec — `_enter_iframes()` + `SceneTreeTimer(HIT_IFRAMES_SECS).timeout.connect(_exit_iframes_if_not_dodging, CONNECT_ONE_SHOT)`. Verified via paired test: `tests/test_player_iframes_on_hit.gd::test_take_damage_enters_iframes_after_damage_applies` + `test_fatal_hit_skips_iframes_path` (the early `return` after `_die()`).
- **W3-T1-AC7 — `_exit_iframes_if_not_dodging` honors active dodge state.** Per Uma §3.B — when dodge began mid-hit-iframe, the dodge's own `_exit_iframes` call wins; the timer's call is no-op. Verified: `tests/test_player_iframes_on_hit.gd::test_exit_iframes_helper_no_op_during_active_dodge`.
- **W3-T1-AC8 — Playwright AC4 spec clears Room 05 deterministically.** `tests/playwright/specs/ac4-boss-clear.spec.ts` clears Room 05 without the harness-side dodge / position-steered crutch. Stale `test.fail()` annotation removed in the same PR. ≥8 release-build runs green (per HTML5 visual gate + acceptance band rigour).

**Verification methods:**

- W3-T1-AC1..AC4: paired GUT damage assertions.
- W3-T1-AC5..AC7: paired GUT iframe-window unit tests in new `tests/test_player_iframes_on_hit.gd`.
- W3-T1-AC8: Playwright `ac4-boss-clear.spec.ts` harness re-run on release-build artifact (the AC4 spec is the canonical AC4 sign-off gate).
- **Sponsor probe** (subjective feel-check): Room 05 winnable AND satisfying — see §"Sponsor probe targets" below.

**Pass/fail signal:**

- All 8 paired tests green in CI.
- AC4 spec passes 8/8 release-build runs (deterministic clear, no flake).
- Sponsor 30-min soak verdict: "Room 05 reads as a hard fight, not a coin-flip."
- Acceptance band hit: L1 no-dodge clears Room 05 in **12-25s** with **≥30% HP remaining** (harness canary band per Uma §4); skilled-dodge clears in **8-18s** with **60-90% HP** (skill-floor band).

**Edge-case probes (4):**

- **EP-RAPID:** mash LMB + RMB + dodge in Room 05 — iframe windows from take_damage do NOT stack indefinitely; second hit during iframe window doesn't double-grant (`_enter_iframes` is idempotent — verify).
- **EP-INTR:** take damage AND start dodge on the same frame — dodge's iframe lifecycle wins; `_exit_iframes_if_not_dodging` correctly no-ops at timer fire.
- **EP-DUP:** trigger `take_damage(0, ...)` (zero damage) — does iframes-on-hit fire? Design intent: NO (iframes guard against damage clusters; zero-damage hit is a pure event, not a damage event). Per Uma §3.B spec — iframes fire AFTER damage applies; if `damage_amount == 0` the take_damage method may early-return before the iframes block. Verify the Player.gd impl matches one of: (a) skip iframes on zero-damage, OR (b) grant iframes anyway. Document the choice in the PR and pin via test.
- **EP-EDGE:** take damage at exactly `hp_current = 1` with damage = 1 — does iframes-on-hit fire BEFORE the `_die()` check or AFTER? Per Uma §3.B: `if hp_current == 0: _die(); return` — death path skips iframes. Verify the early-return order matches the spec literally.

**Integration scenario:**

Player at L1 enters Room 05 with starter iron_sword equipped. Three chasers (2 Grunts + 1 Charger) aggro and close. Player swings continuously (no dodge, no reposition). Player takes ~8 damage from a Grunt, immediately enters 0.25s of iframes. The Charger contact-frame that would normally land on the same frame is dodged by the iframe window. Player kills 3 chasers in 12-25s, exits with ≥30% HP. Walks east, gate unlocks, gate_traversed fires, Room 06 loads.

**Sponsor probe target:**

**"Is Room 05 winnable AND satisfying?"** Subjective; M2 RC gates this. If Sponsor says "trivial" → balance over-corrected (consider partial reversion: Grunt 2→2.5 staged through M3); if Sponsor says "still feels punishing" → consider Lever 5 (mob aggro spacing, deferred to M3 in Uma's design); if Sponsor says "feels like a tense win" → balance landed correctly.

### W3-T2 — `feat(level): stratum-2 second + third rooms (s2_room02 + s2_room03)`

W2-T1 carry. Two new S2 rooms — `s2_room02.tres` + `Stratum2Room02.tscn` (mob mix: 2 Stokers + 1 Charger heat-blasted) and `s2_room03.tres` + `Stratum2Room03.tscn` (mob mix: 1 Stoker + 1 Charger heat-blasted + 1 Shooter heat-blasted, plus `&"boss_door"` port tag for boss-room handoff).

**Acceptance criteria (7):**

- **W3-T2-AC1 — Both rooms load + assemble.** `s2_room02.tres` and `s2_room03.tres` exist as `LevelChunkDef`. `Stratum2Room02.tscn` and `Stratum2Room03.tscn` instantiate without errors. `LevelAssembler.assemble_single` builds both assemblies cleanly.
- **W3-T2-AC2 — Mob mix per spec.** Room 02: 2× Stoker + 1× Charger heat-blasted. Room 03: 1× Stoker + 1× Charger heat-blasted + 1× Shooter heat-blasted. Counts asserted via `EXPECTED_MOB_COUNTS` constant in the paired test (mirrors `test_stratum1_rooms.gd` pattern).
- **W3-T2-AC3 — Mobs spawn inside chunk bounds.** Both rooms — every spawned mob's position is inside the room rect at spawn-tick (mirrors `test_stratum1_rooms.gd::test_*_grunt_spawn_inside_room`).
- **W3-T2-AC4 — `&"boss_door"` port tag on R3.** `s2_room03.tres` has a port with `port_tag = &"boss_door"` indicating boss-room handoff. Verified via `LevelChunkDef.ports.find()` assertion.
- **W3-T2-AC5 — S1→S2→R2→R3 traversal works.** Player descends S1, lands in S2 R1, walks east through gate to R2, kills mobs, walks to R3, kills mobs. Existing RoomGate flow + `StratumProgression` carry-state. Smoke-tested via paired integration test (mirrors `tests/integration/test_stage_2b_tutorial_traversal.gd` pattern).
- **W3-T2-AC6 — RoomGate cleared-state persists.** After clearing R2 + R3, save game, quit, relaunch — `StratumProgression` restores cleared-state. Existing M1 mechanism; W3-T2 is the regression gate, not a new behavior.
- **W3-T2-AC7 — 480×270 internal canvas + WEST entry / EAST exit.** Both rooms conform to the s1_room0N pattern. Verified via paired test on `room_rect.size` + port positions.

**Verification methods:**

- W3-T2-AC1..AC4 + AC7: paired GUT in `tests/test_stratum2_rooms_v2.gd` (extends or replaces existing W2 `test_stratum2_rooms.gd` if Drew authored one in T5; else fresh file).
- W3-T2-AC5: paired integration test in `tests/integration/test_s2_r1_r2_r3_traversal.gd` (NEW).
- W3-T2-AC6: existing `test_stratum_progression.gd` regression coverage; W3-T2 PR re-runs the suite.
- **Sponsor probe** (subjective feel-check): S2 rooms feel like Cinder Vaults (per palette-stratum-2.md §3 decoration beats).

**Pass/fail signal:**

- All paired tests green.
- S1→S2→R2→R3 traversal smoke completes without console error.
- Sponsor: "yes, this reads as Cinder Vaults — burnt mining-cathedral, not Sunken Library."

**Edge-case probes (3):**

- **EP-EDGE:** R3 boss_door port at extreme position — `LevelAssembler.assemble_single` correctly stitches with `s2_boss_room.tres` (W3-T4 dependency); test marks `pending` if T4 hasn't landed yet.
- **EP-RT:** save mid-R2 (1 mob alive), quit, relaunch — `Continue` resumes inside R2 with mob state restored.
- **EP-INTR:** descend S1→S2 mid-sprite-load — assembly does not race; mobs don't spawn outside bounds.

**Integration scenario:**

Player clears S1 R8 boss, walks through S1 descent portal, lands in S2 R1 (M2 W1 T5 — assumed on main). Walks east, RoomGate engages, kills 1 Stoker + S2 mobs, walks to gate, exits east into R2. Cinder-Rust palette continues; mob mix shifts to chaser-heavy (2 Stokers + 1 Charger). Kills R2, exits east into R3. R3 has 3-mob mix (1 Stoker + 1 Charger + 1 Shooter heat-blasted) plus a `boss_door` port east. Walks to boss_door port → loads `s2_boss_room.tscn` (W3-T4).

**Sponsor probe target:**

**"Do S2 R2 + R3 read as Cinder Vaults?"** Subjective; if Sponsor says "feels like S1 with red filter" the soft-retint sprites (W3-T3) didn't land; if Sponsor says "different mob rhythm" the mob mix landed.

### W3-T3 — `feat(content): stratum-2 sprite soft-retint pass (Charger / Shooter / Pickup / Ember-bag / Stash chest)`

W2-T2 carry. Five soft-retint sprites per `palette-stratum-2.md §5` — Charger heat-blasted, Shooter heat-blasted, Pickup glow (Cinder-Rust outer flame), Ember-bag (S2 variant), Stash chest cross-stratum-constant (recommendation: drop from 5 to 4 sprites).

**Acceptance criteria (5):**

- **W3-T3-AC1 — All 4-5 sprites land.** Aseprite source files (`*.aseprite`) committed alongside exported PNGs under `resources/mobs/s2/` (or `resources/sprites/s2/` per Drew's authoring layout). Stash chest decision documented in PR (cross-stratum-constant = 4 sprites; per-stratum = 5).
- **W3-T3-AC2 — Hex-code conformance.** S2-PL-04 / S2-PL-05 / S2-PL-09 / S2-PL-10 from palette-stratum-2.md §7 pin via Tess eye-dropper screenshots. Heat-blasted Charger uses `#C25A1F` (vein cycle) for accent. Heat-blasted Shooter uses `#FF6A2A` for projectile glow. Pickup outer flame uses `#FF6A2A` to match player death-dissolve.
- **W3-T3-AC3 — Daltonization holds (S2-PL-13).** Uma re-runs §6 daltonization on the new sprites; if any of the 5 at-risk pairs collapse in deuteranopia / protanopia / tritanopia, Drew swaps before merge. Verified via Tess + Uma joint sign-off.
- **W3-T3-AC4 — Anti-list rules hold (S2-PL-08, S2-PL-09, S2-PL-10).** Zero pure-black `#000000` mob pixels; zero T4-violet `#8B5BD4` mob pixels; zero cool-teal/cyan mob pixels.
- **W3-T3-AC5 — Aseprite sources committed.** All 4-5 sprites ship with `*.aseprite` source files alongside exported PNGs (per `team/uma-ux/visual-direction.md` rule).

**Verification methods:**

- W3-T3-AC1: PR file inventory check.
- W3-T3-AC2 + AC4: Tess eye-dropper screenshot review against palette-stratum-2.md §7 hex codes.
- W3-T3-AC3: Tess + Uma joint daltonization re-run on sprite mockups.
- **Sponsor probe** (subjective feel-check): "do the heat-blasted mobs look like their S1 counterparts cooked in fire?"

**Pass/fail signal:**

- Sprites visible on PR comment screenshots; eye-dropper hex codes within ±5 of palette-stratum-2.md §7 pins.
- Daltonization re-run produces zero new at-risk pairs.
- Sponsor: "yes, these read as Cinder Vaults variants."

### W3-T4 — `feat(boss): stratum-2 boss room first impl — Vault-Forged Stoker`

W2-T3 carry. Single largest W3 ticket. New stratum-2 boss with 3-phase state machine modelled on `Stratum1Boss.gd`.

**Acceptance criteria (12 — mirrors M1 boss N6 task spec):**

- **W3-T4-AC1 — Boss spawns with full HP, health-bar reflects.** New `s2_boss.tres` MobDef + `Stratum2Boss.gd` script + `Stratum2Boss.tscn` scene. `apply_mob_def(def)` seeds full HP. Health-bar UI populates correctly on entry.
- **W3-T4-AC2 — Phase-1 attack telegraphs + lands damage.** Default attack pattern (chase + telegraph + breath cone). Telegraph reads at-screen ≥0.5s. Damage applies on player contact with breath cone hit-region.
- **W3-T4-AC3 — Phase transition at 66% HP fires `phase_changed(2)` signal.** Mirror of M1 boss phase-1→phase-2 boundary.
- **W3-T4-AC4 — Phase 2 has access to phase 1 + phase 2 attacks.** Adds slam attack to the breath-cone repertoire (mirrors M1 boss adding new attack at phase 2).
- **W3-T4-AC5 — Phase transition at 33% HP fires `phase_changed(3)`.** Mirror of M1 boss phase-2→phase-3 boundary.
- **W3-T4-AC6 — Phase 3 enrage state (1.5× speed, 0.7× recovery, breath-cone widens).** Per Priya's §W3-T4 scope. Verified via paired test asserting state transitions + tunable multipliers.
- **W3-T4-AC7 — Boss death emits `boss_died` signal.** Mirror of M1 boss `boss_died.emit(...)`.
- **W3-T4-AC8 — Boss respects player i-frames (no damage during dodge).** Mirror of M1 boss; new W3-T1 iframes-on-hit must ALSO be respected — boss damage during the 0.25s post-hit iframe window is rejected.
- **W3-T4-AC9 — Boss death triggers loot drop from `boss_drops` table.** T3 weapon + T2/T3 gear loot per Priya's §W3-T4 scope. Verified via paired test asserting `boss_drops` is non-empty + LootRoller triggers.
- **W3-T4-AC10 — EDGE: rapid hit spam doesn't double-trigger phase transitions.** Mirror of M1 boss test 10. `phase_changed` emits exactly once per phase boundary even under hit spam.
- **W3-T4-AC11 — EDGE: boss takes damage during phase-transition slow-mo (should NOT — stagger immune during transition).** Mirror of M1 boss test 11.
- **W3-T4-AC12 — EDGE: player dies mid-boss-fight, room state resets, boss respawns at full HP.** Mirror of M1 boss test 12.

**Verification methods:**

- All AC1..AC12: paired GUT in `tests/test_stratum2_boss.gd` (mirrors `test_stratum1_boss.gd` 12-coverage-points structure).
- Boss-room scene assembly: paired GUT in `tests/test_stratum2_boss_room.gd` (mirrors `test_stratum1_boss_room.gd` pattern).
- Integration: full S1→S2→R1→R2→R3→Boss room flow in `tests/integration/test_s2_boss_room_traversal.gd` (NEW; gated on W3-T2 + W3-T4 both landing).
- Playwright: extension to `ac4-boss-clear.spec.ts` (or new `ac5-boss-clear.spec.ts`) once boss room is on `main`.
- **Sponsor probe** (subjective feel-check): does Vault-Forged Stoker feel like a different boss from Stratum1Boss? Phase transitions, telegraphs, breath-cone vs slam.

**Pass/fail signal:**

- All 12 paired tests green in CI.
- Integration traversal completes without console error.
- Sponsor: "yes, this is a Cinder Vaults boss — not the M1 boss in red costume."

**Edge-case probes (4):**

- **EP-RAPID:** mash LMB during boss intro — boss intro Beat-1..Beat-5 still fires correctly (per `boss-intro.md` reusable beat structure); damage during DORMANT state is rejected (mirrors M1 boss `IGNORED dormant`).
- **EP-INTR:** boss dies mid-breath-cone (player crit-burst) — breath cone particle/anim aborts cleanly; no orphan damage hitbox; no console error.
- **EP-EDGE:** boss telegraphs breath-cone while player at extreme cone-edge — damage applies if inside cone, doesn't if outside.
- **EP-BLUR:** boss mid-phase-transition during tab-blur — transition timer holds; on tab-return, transition completes cleanly OR fires (not undefined).

### W3-T5 — `feat(content): MobRegistry autoload — stratum-aware mob lookup + scaling`

W2-T4 carry. New autoload mapping `mob_id: StringName → MobDef + MobScene + scaling_multipliers`.

**Acceptance criteria (5):**

- **W3-T5-AC1 — Autoload registers.** `project.godot` autoload list includes `MobRegistry = "*res://scripts/content/MobRegistry.gd"`. Project loads without errors.
- **W3-T5-AC2 — Round-trip: register + retrieve.** Register all M1 + M2 mobs at autoload boot. `MobRegistry.get_mob_def(&"grunt")` returns the Grunt MobDef. `get_mob_scene(&"grunt")` returns the Grunt PackedScene. `get_mob_def(&"unknown_mob")` returns `null` gracefully (no crash).
- **W3-T5-AC3 — Stratum-scaling math correct.** S1 baseline 1.0; S2 +20% HP / +15% dmg per `mvp-scope.md §M2`. `MobRegistry.apply_stratum_scaling(grunt_def, &"s1")` returns def with HP × 1.0 / dmg × 1.0; `apply_stratum_scaling(grunt_def, &"s2")` returns def with HP × 1.2 / dmg × 1.15.
- **W3-T5-AC4 — Scaling-doesn't-mutate-source invariant.** Calling `apply_stratum_scaling(grunt_def, &"s2")` returns a NEW MobDef instance; the source `grunt_def` is unchanged.
- **W3-T5-AC5 — `MultiMobRoom._spawn_mob` refactor doesn't regress.** All M1 + M2 mob-spawn integration tests pass with the refactored dispatch (Registry-driven instead of match-block-driven). Existing `tests/test_stratum1_rooms.gd` + `tests/test_stratum2_rooms.gd` paired tests stay green.

**Verification methods:**

- W3-T5-AC1..AC4: paired GUT in `tests/test_mob_registry.gd` (NEW).
- W3-T5-AC5: regression — re-run `test_stratum1_rooms.gd` + `test_stratum2_rooms.gd` + `test_grunt.gd` + `test_charger.gd` + `test_shooter.gd` + boss tests.
- **Sponsor probe** (subjective feel-check): NONE direct (refactor invisibility is the goal).

**Pass/fail signal:**

- All paired tests green.
- Zero regressions in M1 + M2 mob-spawn coverage.
- Sponsor: NONE — refactor is invisible at-runtime.

**Edge-case probes (2):**

- **EP-OOO:** call `get_mob_def` before autoload `_ready` — autoload-order-independence holds (constants are module-scope).
- **EP-DUP:** call `apply_stratum_scaling(def, &"s2")` twice on the same def — second call returns a new def with the SAME values (does NOT compound: 1.2 × 1.2 = 1.44 would be a bug).

### W3-T6 — `feat(save): schema v4 stress test fixtures + HTML5 OPFS round-trip`

W2-T5 carry. Eight stress-fixture files under `tests/fixtures/v4/` covering INV-1..INV-8.

**Acceptance criteria (8):**

- **W3-T6-AC1 — `save_v4_full_stash_72_slots.json` fixture committed.** A v4 envelope with `character.stash` populated to 72 slots (max stash capacity per stash-ui-v1.md §6). Loads cleanly under v4 runtime.
- **W3-T6-AC2 — `save_v4_three_stratum_bags.json` fixture committed.** A v4 envelope with `character.ember_bags` populated for stratum 1, 2, 3 simultaneously (cross-stratum independence per ST-21).
- **W3-T6-AC3 — `save_v4_partial_corruption_recovery.json` fixture committed.** A v4 envelope with one corrupted item entry (unknown id) — load surfaces `push_warning` + drops the entry; rest of save loads clean.
- **W3-T6-AC4 — `save_v4_max_level_capped_full_inventory.json` fixture committed.** A v4 envelope at max level + full inventory (24 slots) + full stash (72 slots) + 8 ember bags. Round-trip survives bit-identical (TI-15 size budget hit).
- **W3-T6-AC5 — `save_v4_html5_opfs_baseline.json` fixture committed.** A minimal v4 envelope used as the OPFS round-trip baseline.
- **W3-T6-AC6 — `save_v4_html5_opfs_max.json` fixture committed.** A maximal v4 envelope (same shape as AC4) for OPFS stress testing.
- **W3-T6-AC7 — `save_v4_idempotent_double_migration.json` fixture committed.** A v4 envelope deliberately double-migrated (in-test) — second migration is bit-identical no-op (INV-7).
- **W3-T6-AC8 — `save_v4_unknown_keys_passthrough.json` fixture committed.** A v4 envelope with extra unknown keys (forward-compat) — load preserves them through round-trip (not silently dropped).

**Verification methods:**

- All AC1..AC8: paired GUT in `tests/test_save_v4_stress.gd` (NEW; co-owned with Devon for OPFS-specific edge cases).
- HTML5 OPFS round-trip: integration test if Tess can stand up headless-browser GUT; otherwise documented as Sponsor-soak probe target (AC4 fallback per Priya §W3-T6 risk note).
- **Sponsor probe** (HTML5 OPFS validation if integration test isn't viable): save → quit → relaunch on Firefox + Chrome; bag dict + stash + inventory survive bit-identical.

**Pass/fail signal:**

- 8 fixtures committed under `tests/fixtures/v4/`.
- Paired test adds ~12-16 new test cases.
- CI green.
- HTML5 OPFS round-trip either tested or documented as probe target in §"Sponsor probe targets" (W3-T9 below).

**Edge-case probes (3):**

- **EP-RT:** load each fixture; mutate; re-save; re-load — bit-identical.
- **EP-OOO:** load fixture before `Save` autoload `_ready` — fixture data not consumed prematurely.
- **EP-DUP:** load same fixture twice — second load is idempotent.

### W3-T7 — `feat(ui): stash UI iteration v1.1 — Sponsor-soak feedback consumption` (CONDITIONAL)

W2-T7 carry, **conditional on Sponsor's W2 RC soak feedback**. If Sponsor doesn't flag stash discoverability or affordance issues, this ticket closes paper-trivial.

**Acceptance criteria (variable, capped at 4):**

- **W3-T7-AC1 — Sponsor's filed `bug(ux):` / `chore(ux-iterate):` tickets all closed.**
- **W3-T7-AC2 — Tests updated for any behavior changes** (e.g., if Tab+B coexistence semantics shift, `test_stash_panel.gd` updates).
- **W3-T7-AC3 — `stash-ui-v1.md v1.1` revision if any design assertions change** (Uma owns).
- **W3-T7-AC4 — No regressions** in M2 W1 stash UI coverage (`test_stash_panel.gd` regression gate).

**Verification methods:**

- Paired test updates per Sponsor-filed tickets.
- Sponsor sign-off on iteration build.

**Pass/fail signal:**

- All Sponsor-filed tickets closed or rationale-deferred.
- Tess regression sweep green.

### W3-T8 — `feat(progression): ember-bag tuning v2 — soak observations + edge polish` (CONDITIONAL)

W2-T8 carry, **conditional on Sponsor's W2 RC soak feedback**. Same conditional pattern as W3-T7.

**Acceptance criteria (variable, capped at 3):**

- **W3-T8-AC1 — Sponsor's filed tickets closed.**
- **W3-T8-AC2 — Edge-case tests updated** for any behavior changes (`tests/integration/test_ember_bag_pickup.gd` if it exists; else added).
- **W3-T8-AC3 — Sponsor sign-off** on tuning build.

### W3-T9 — `design(audio)+source: M2 audio sourcing close-out (mus-stratum2-bgm + mus-boss-stratum2 + amb-stratum2-room)`

W2-T9 carry. Three cues at q5/q7 OGG per `audio-direction.md §4`.

**Acceptance criteria (5):**

- **W3-T9-AC1 — `mus-stratum2-bgm` lands.** OGG file at q5/q7 quality. Plays on the music bus on S2 entry.
- **W3-T9-AC2 — `amb-stratum2-room` lands.** OGG file at q5/q7 quality. Plays on the ambient bus on S2 entry.
- **W3-T9-AC3 — `mus-boss-stratum2` lands OR cross-stratum reuse documented.** Per Priya §W3-T9: decision point (cross-stratum reuse OR unique). Decision logged in `team/decisions/DECISIONS.md`.
- **W3-T9-AC4 — 5-bus structure unchanged.** No new bus added. Both cues use existing music + ambient buses. Sidechain duck spec preserved per `audio-direction.md §3`.
- **W3-T9-AC5 — Tab-blur HTML5 round-trip.** S2 BGM mid-loop during tab-blur — audio pauses (browser default for hidden tab) and resumes cleanly on tab-return; no decode-restart artifact.

**Verification methods:**

- W3-T9-AC1..AC4: paired GUT in `tests/test_audio_s2_cues.gd` (NEW; smoke-test that streams resolve + buses are correct).
- W3-T9-AC5: HTML5 release-build smoke + Sponsor soak.
- **Sponsor probe** (subjective feel-check): does S2 BGM + ambient feel like a different stratum?

**Pass/fail signal:**

- 3 cues land at q5/q7 (or 2 cues + cross-stratum-reuse decision logged).
- Sponsor: "yes, S2 audio is warm-pressure-depth, not cool-eerie."

### W3-T10 — `qa(integration): M2 W3 acceptance plan + paired GUT scaffolds (#86c9u4mm2)`

**This ticket.** Three halves per Priya's §W3-T10 scope:

- **Half A** — `team/tess-qa/m2-acceptance-plan-week-3.md` (this doc).
- **Half B** — Sponsor-soak fix-forward absorber (Sponsor soaks W2 RC `d9cc159` in parallel; W3-T10 buffer triages + dispatches fix-forward).
- **Half C** — End-of-W3 exploratory bug-bash (Tess runs against the W3 RC; files everything per `team/tess-qa/bug-template.md`).

**Acceptance criteria (3):**

- **W3-T10-AC1 — Half A doc on `main`.** This PR.
- **W3-T10-AC2 — Half B Sponsor-filed bugs fix-forwarded or rationale-deferred.** Tracked via inline links in §"Sponsor-soak fix-forward log" of THIS doc, appended as Sponsor findings land.
- **W3-T10-AC3 — Half C end-of-W3 bug-bash log.** New file `team/tess-qa/soak-2026-05-2N.md` (date stamp = end of W3) appending all findings; zero blockers + zero majors at W3 close.

### W3-T11 — `qa(infra): Playwright artifact-resolve SHA-pin fix`

NEW ticket surfaced by Tess W2 soak (Tess's `soak-2026-05-15.md` non-obvious finding §4).

**Acceptance criteria (2):**

- **W3-T11-AC1 — `playwright-e2e.yml` artifact-resolve step pinned to matching commit SHA.** Workflow either waits for matching artifact or fails fast with clear "no matching artifact for SHA X" message.
- **W3-T11-AC2 — Tess validation: trigger Playwright while a release build is in-flight; observe correct behavior (wait OR fail-fast, not silent stale-artifact false-positive).**

### W3-T12 — `design(m3-seeds): M3 framing — multi-character / hub-town / persistent meta-progression`

W2-T12 carry. Pure design doc; Priya owns. Acceptance is doc-on-main only.

**Acceptance criteria (1):**

- **W3-T12-AC1 — `team/priya-pl/m3-design-seeds.md` on `main`.** 200-400 lines covering §1 Multi-character, §2 Hub-town, §3 Persistent meta-progression. Cross-references stash-ui-v1.md / save-schema-v4-plan.md / palette.md / mvp-scope.md §M3.

---

## AC4 acceptance bands (W3-T1 deep dive)

Per Uma `ac4-room05-balance-design.md §4 + §5`:

| Run profile | Clear time band | HP remaining band | Verification |
|---|---|---|---|
| **L1 no-dodge melee, starter iron sword (harness canary)** | 12-25s | ≥30% (30-70% expected median) | Playwright AC4 spec, ≥8 release-build runs, deterministic |
| **L1 skilled-dodge play (Sponsor median)** | 8-18s | 60-90% | Sponsor soak, qualitative |
| **Rooms 02-04 (regression)** | within ±20% of pre-balance times | within ±15% of pre-balance HP | Playwright AC4 spec, regression run |
| **Boss times** | unchanged from pre-balance | unchanged | Boss spec re-run + Sponsor confirm |

**Bug-bounce rule** (per Uma §4): bug-bounce only on 2× deviation from a band edge. Single-run flakes inside the band are NOT bugs; single-run drifts to 25.5s when the band is 12-25s are NOT bugs (within tolerance).

**Verification cadence:**

- ≥8 release-build runs of `ac4-boss-clear.spec.ts` post-balance-pass before declaring W3-T1 shipped.
- Median + p95 across 8 runs reported in W3-T1 PR's Self-Test Report comment.
- Sponsor 30-min soak post-W3-T1-merge for the qualitative feel-check.

---

## Sponsor probe targets (M2 W3 RC soak)

When the W3 RC artifact lands (post-W3-T11, expected `m2-rc3` or similar tag), Sponsor's interactive 30-min soak evaluates:

1. **AC4 post-balance feel — is Room 05 winnable AND satisfying?** (W3-T1) The single-most-important W3 probe. Pass criteria: Sponsor describes Room 05 as "tense win" or "hard but fair." Fail signals: "trivial" (over-correction; consider partial reversion) or "still feels punishing" (under-correction; consider Lever 5 — mob aggro spacing — for M3).
2. **S2 rooms 2-3 feel — do they look/play like Cinder Vaults?** (W3-T2 + W3-T3) Pass: Sponsor says "this feels like a different stratum from S1." Fail: "feels like S1 with a red tint" → soft-retint sprites didn't land OR mob mix doesn't differentiate enough.
3. **S2 boss-fight feel — phase transitions, telegraphs, breath-cone vs M1 slam.** (W3-T4) Pass: Sponsor reads Vault-Forged Stoker as a Cinder-Vaults boss, not "M1 boss in red costume." Fail: "same fight different sprite" → phase mechanics need differentiation.
4. **Audio coherence — does S2 BGM + ambient feel like a different stratum?** (W3-T9) Pass: warm-pressure-depth (Cinder Vaults). Fail: cool-eerie (still on the indicative Sunken Library brief) → audio direction needs v1.2 nudge or hand-compose deferred.
5. **MobRegistry refactor invisibility.** (W3-T5) Pass: Sponsor notices NOTHING (refactor is at-runtime invisible). Fail: any new bug surfaces via the refactor → Devon iterates immediately.
6. **Ember-bag tuning v2 — soak observations + edge polish (W3-T8 conditional).** Pass: Sponsor's W2 ember-bag observations addressed; no new ember-bag complaints. Fail: same complaints recur or new ones surface.

**Top 3 priority for first W3 soak:** #1 (AC4 balance feel), #2 (S2 rooms 2-3 visual identity), #3 (S2 boss-fight feel). These three gate the W3 RC sign-off. #4 + #5 + #6 are polish.

---

## HTML5 audit re-run pattern (W3 RC)

The W3 RC (`m2-rc3` or whatever tag fires when W3-T11 closes the artifact pipeline race) gets the same Playwright + Sponsor-soak audit pattern W2 used.

**Audit document:** `team/tess-qa/html5-rc-audit-<short-sha>.md` (template per `team/tess-qa/html5-rc-audit-591bcc8.md`). Tess re-spins the audit doc against the W3 RC artifact.

**Audit shape per file:** mirrors the W1 acceptance plan §"M2 RC build verification" table format. New files in W3 to audit:

| File | Concern | Risk class | Severity floor |
|---|---|---|---|
| `scripts/player/Player.gd` (extended with HIT_IFRAMES_SECS + iframes-on-hit block) | iframe state mutation timing in physics-flush window | TI + SP | medium (combat) |
| `resources/mobs/grunt.tres` (damage_base 3→2) | damage-formula regression vs M1 expectations | TI | low |
| `resources/mobs/charger.tres` (damage_base 5→4) | damage-formula regression vs M1 expectations | TI | low |
| `resources/level_chunks/s2_room02.tres` (NEW) | chunk graph stitch with R1 + R3 | TI | low |
| `resources/level_chunks/s2_room03.tres` (NEW) | chunk graph stitch with R2 + boss room | TI | low |
| `scenes/levels/Stratum2Room02.tscn` (NEW) | room scene cold-loads under HTML5 | TI + SP | low |
| `scenes/levels/Stratum2Room03.tscn` (NEW) | room scene cold-loads under HTML5 | TI + SP | low |
| `scenes/levels/Stratum2BossRoom.tscn` (NEW) | boss-room scene cold-loads + entry sequence + breath-cone particle on HTML5 | SP | medium (boss) |
| `scripts/mobs/Stratum2Boss.gd` (NEW) | state machine + phase transitions on HTML5 | SP | medium |
| `scripts/content/MobRegistry.gd` (NEW autoload) | autoload-order independence + scaling math | TI | low |
| `tests/fixtures/v4/*.json` (8 NEW) | fixture JSON validity + round-trip on HTML5 OPFS | TI + SP | low |
| `audio/mus-stratum2-bgm.ogg` + `amb-stratum2-room.ogg` (NEW) | OGG decoding on cold-launch + tab-blur recovery | SP | medium |

**New testable invariants (TI-16..TI-22) for `tests/integration/test_html5_invariants.gd` extension:**

- **TI-16:** `Player.HIT_IFRAMES_SECS == 0.25` constant exists + reads correct.
- **TI-17:** `Player.take_damage(1, ...)` enters iframes + the `_exit_iframes_if_not_dodging` timer is queued.
- **TI-18:** `MobRegistry.apply_stratum_scaling(grunt_def, &"s2")` returns def with HP × 1.2 (Dictionary check, no mutation of source).
- **TI-19:** `s2_room02.tres` + `s2_room03.tres` LevelChunkDef instances load without error.
- **TI-20:** `Stratum2BossRoom.tscn` instantiates without error in headless GUT (smoke).
- **TI-21:** OPFS round-trip of `save_v4_full_stash_72_slots.json` survives bit-identical (only meaningful via Sponsor HTML5 soak; documented as probe target if no headless-browser GUT runner).
- **TI-22:** Tab-blur during S2 BGM playback does not corrupt the audio bus state (Sponsor soak + console-error watch).

---

## Sponsor-soak fix-forward absorber (W3-T10 Half B)

**Sponsor soaks W2 RC `embergrave-html5-d9cc159` in parallel to W3 work.** The W2-RC handoff happens via direct artifact link per `team/uma-ux/sponsor-soak-checklist-v2.md`. Tess W3-T10 buffer absorbs Sponsor findings as they land.

**Triage pattern (mirrors M1 RC pattern):**

1. **P0 (soak-stopper)** — fix-forward dispatches at next-tick before W3 new content tickets. Severity gate per `team/tess-qa/bug-template.md`.
2. **P1 (major)** — fix-forward in W3 if dev capacity allows; defer to W4 if W3 P0 backlog full.
3. **P2 (minor)** — fix-forward in W3 if paper-trivial; defer to W4 otherwise.
4. **P3 (cosmetic / deferral)** — log in `team/log/process-incidents.md` if it surfaces a broader process gap; otherwise ticket-and-defer.

**Sponsor-soak findings log (appended as findings land):**

- _(no findings yet; Sponsor's W2 RC soak hasn't fired at W3 day-1)_

---

## End-of-W3 exploratory bug-bash (W3-T10 Half C)

Tess runs an exploratory pass on the W3 RC (whatever lands by end-of-W3) against this acceptance plan. Pattern matches W2 close (`soak-2026-05-15.md`).

**Output file:** `team/tess-qa/soak-2026-05-2N.md` (date stamp = end of W3).

**Bar:** zero blockers + zero majors at W3 close. Minors filed and triaged into W4 backlog.

---

## Test fixture catalog

8 new fixtures land under `tests/fixtures/v4/` per W3-T6:

- `save_v4_full_stash_72_slots.json`
- `save_v4_three_stratum_bags.json`
- `save_v4_partial_corruption_recovery.json`
- `save_v4_max_level_capped_full_inventory.json`
- `save_v4_html5_opfs_baseline.json`
- `save_v4_html5_opfs_max.json`
- `save_v4_idempotent_double_migration.json`
- `save_v4_unknown_keys_passthrough.json`

Each fixture's shape is documented in `team/devon-dev/save-schema-v4-plan.md §6` (the catalog Devon authored). Tess + Devon co-author the actual JSON via the W3-T6 ticket.

---

## Paired-test file index — W3 NEW

This PR scaffolds 5 new GUT files under `tests/`. Each is committed with `pending()` stubs that compile (so CI's GUT step doesn't trip on parse errors) and are tightened into real assertions when the corresponding W3 PR lands.

| File | Purpose | W3 ticket |
|---|---|---|
| `tests/test_stratum2_rooms_v2.gd` | Pin S2 R2 + R3 chunk-load + assemble + mob-mix + RoomGate traversal. Mirrors `test_stratum1_rooms.gd` 17-test pattern. | W3-T2 |
| `tests/test_stratum2_boss.gd` | Pin Vault-Forged Stoker 12-coverage-points (mirror of `test_stratum1_boss.gd`). | W3-T4 |
| `tests/test_stratum2_boss_room.gd` | Pin S2 boss-room scene assembly + entry sequence + door-trigger. Mirrors `test_stratum1_boss_room.gd`. | W3-T4 |
| `tests/test_mob_registry.gd` | Pin MobRegistry round-trip + stratum-scaling math + scaling-doesn't-mutate-source invariant. | W3-T5 |
| `tests/test_save_v4_stress.gd` | Pin INV-1..INV-8 against the 8 stress fixtures (co-owned with Devon). | W3-T6 |

**Authoring trigger:** when the corresponding W3 PR lands the production code under test, Tess replaces `pending()` stubs with real assertions. The stub files are scaffolding, NOT functional tests.

---

## Test-pass-count projection

W2 close baseline (post-PR #200 merge): per `team/STATE.md` (~700 passing target, exact number to be verified).

W3 target delta (assuming all W3-T1..W3-T9 land green):

- W3-T1 (AC4 balance + iframes): **+10-12 paired tests** (damage assertions + iframe-window unit tests + Playwright harness re-run).
- W3-T2 (S2 rooms 2-3): **+12-15 paired tests** (mirror `test_stratum1_rooms.gd` pattern, scaled to 2 rooms).
- W3-T3 (sprites): **+0 paired tests** (visual review only; daltonization doc-update, not test).
- W3-T4 (S2 boss room): **+15-20 paired tests** (full 12-coverage + extras + boss-room scene).
- W3-T5 (MobRegistry): **+8-10 paired tests** (round-trip + scaling + refactor regression coverage).
- W3-T6 (v4 stress fixtures): **+12-16 paired tests** (8 fixtures × 1-2 tests each).
- W3-T9 (audio): **+3-5 paired tests** (cue smoke + bus assertions).

**Projected W3 total:** **~60-78 new paired tests**, landing W3 build at ~760-780 passing if every ticket ships green.

---

## Hand-off

- **Devon:** W3-T1 (Player iframes-on-hit code), W3-T5 (MobRegistry), W3-T6 (OPFS edge cases co-owned with Tess), W3-T7/T8 (Sponsor-conditional), W3-T9 (audio wiring), W3-T11 (CI hardening). Acceptance bar above flips ClickUp status `ready for qa test` → `complete` after Tess sign-off.
- **Drew:** W3-T1 (TRES edits), W3-T2 (s2 rooms 2-3), W3-T3 (soft-retint sprites), W3-T4 (S2 boss room L). Same flow.
- **Uma:** W3-T1 (design landed pre-impl), W3-T9 (audio sourcing close-out), W3-T7 visual hand-off if Sponsor flags stash UX, W3-T12 (M3 hub-town visual direction assist).
- **Tess:** W3-T6 (co-owned), W3-T10 (this acceptance plan + Sponsor-soak absorber + end-of-W3 bug-bash), W3-T11 (validation). Per-PR sign-offs against the per-ticket ACs above.
- **Priya:** W3-T12 (M3 design seeds), W3 close retro at week-3 boundary; flags AC4 balance design escalation only if Uma proposes off-spec direction.
- **Sponsor:** the 6 probe targets above. W3 RC interactive 30-min soak gates W3 sign-off the way W1/W2 RC soak gated those weeks.

---

## Caveat — parallel scaffold

This doc is the W3 parallel-acceptance scaffold (mirrors the W2-T10 / W1-T12 idiom — drafted at W3 day-1, before any W3 ticket has opened a PR except W3-T10 itself). Revisions land as a v1.1 commit if:

- A W3 ticket scope changes post-Sponsor W2 RC soak (most likely if Sponsor surfaces a regression that re-scopes one of W3-T1..W3-T9).
- Uma's `ac4-room05-balance-design.md` revises post-Drew/Devon implementation surface review (e.g. iframe duration band shifts).
- An integration surface emerges that wasn't anticipated (e.g., a new HTML5 regression class around iframes-on-hit or breath-cone particle).

The 12-ticket coverage + ~67 acceptance row pinning + 5 paired-test-file scaffolds is the **path of least resistance from W3 dispatch → W3 sign-off.** It is not the only path.

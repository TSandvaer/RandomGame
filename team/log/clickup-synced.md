# ClickUp pending queue

Operations that failed against the ClickUp MCP and need replay on the next dispatch.
Format per `team/CLICKUP_FALLBACK.md`. Move synced entries to `clickup-synced.md`.

---

## ENTRY 2026-05-01-001

- op: update_task
- list_id: 901523123922
- payload:
    task_id: 86c9kwhtt
    status: ready for qa test
- reason: feat(player) 8-direction movement + dodge-roll with i-frames landed in commits 2fc7340 + ee1f991. Implementation + 9 paired GUT tests. Tess to verify per testing bar; she signs off the final transition to `complete`.
- created_at: 2026-05-01T10:10
- attempts: 1 (MCP returned "ClickUp is not connected")
- tess-note 2026-05-01: acknowledged in queue. Tess's run-001 was paper-only (test plan deliverables). Will pick this up on her next dispatched tick: run paired GUT tests, run edge-case probes EP-RAPID/EP-INTR/EP-RT against movement+dodge, then flip via this same queue. Not flipping in run-001 because Tess hasn't verified the build firsthand.

## ENTRY 2026-05-01-002

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "[Tess] W1 · M1 acceptance test plan — written cases for all 7 criteria"
    status: complete
- reason: M1 acceptance test plan committed at `team/tess-qa/m1-test-plan.md` in commit 0f41828. 35 manual cases across 7 ACs + regression sweep + edge-case probe matrix + Tess-only sign-off flow + soak policy. Pure docs task (exempt from Tess sign-off per TESTING_BAR.md `## Definition of Done` exemption). Self-flipped to `complete`.
- created_at: 2026-05-01T (mid-run)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-01-003

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "test(smoke): automated smoke test — game boots, title screen, no errors"
    status: in progress
- reason: Paper inventory at `team/tess-qa/automated-smoke-plan.md` covers the full M1 GUT plan (30 unit + 10 integration). Actual `.gd` files not yet written — Tess writes Phase A next tick now that Devon's scaffold + GUT canary CI have landed. Status `in progress`, not `complete`.
- created_at: 2026-05-01T (mid-run)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-01-004

- op: create_task
- list_id: 901523123922
- payload:
    name: "chore(test-hooks): expose 5 testability hooks for M1 acceptance plan"
    priority: high
    tags: [week-1, qa, engine]
    status: to do
    description: |
      Per Tess's M1 test plan and `team/DECISIONS.md` 2026-05-01 entry. Devon implements; Tess uses.

      Five hooks the M1 build must expose so the acceptance test plan stays in time-budget:
      1. Build SHA visible in main menu (small "build: abcdef1" footer, sourced from CI stamp).
      2. Debug-only "fast-XP" toggle gated behind a hidden key combo, never shipped to Sponsor — lets Tess reach level 4-5 in <2 min for AC4/AC7.
      3. Save file location documented in a one-liner README inside the user data dir (or printed to console on first save).
      4. Stable mob spawn seed in test mode (debug flag fixes the seed) so AC4 setup is reproducible.
      5. HTML5 console error surfacing — verify Godot's default GDScript-error-to-browser-console pipeline is not stripped from release builds.

      Acceptance: each hook demoable to Tess on the dev's machine, then merged. Tess signs off this task.
- created_at: 2026-05-01T (mid-run)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-01-006

- op: update_task
- list_id: 901523123922
- payload:
    task_id: 86c9kwhu7
    status: ready for qa test
- reason: feat(player) light + heavy attack hitboxes landed in commit d5852f9. Hitbox.gd + Player.gd attack methods + 17 paired GUT tests across test_hitbox.gd (7) and test_player_attack.gd (10). Layer separation per DECISIONS 2026-05-01. Tess to verify per testing bar with edge-case probes (rapid-fire double-press, dodge mid-attack, attack with no targets, multi-overlap collapse).
- created_at: 2026-05-01T10:14
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-01-007

- op: update_task
- list_id: 901523123922
- payload:
    task_id: 86c9kwhuq
    status: ready for qa test
- reason: feat(save) JSON save/load skeleton landed in commit ddad8af. Save.gd autoload (no longer stub) with envelope + schema_version + atomic_write + v0->v1 migration. team/devon-dev/save-format.md documents the contract. 14 paired GUT tests in tests/test_save.gd covering round-trip, deep-nest persistence, migration, future-schema pass-through, corrupt JSON, atomic write semantics. Forward-compat test that the bar singled out as required is included (test_migrate_v0_save_to_v1_adds_meta_block).
- created_at: 2026-05-01T10:18
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-01-005

- op: create_task
- list_id: 901523123922
- payload:
    name: "test(qa): expanded role per testing bar"
    priority: normal
    tags: [week-1, qa]
    status: complete
- reason: Tracking artifact for the role expansion mid-run-001 per TESTING_BAR.md. Five docs landed (m1-test-plan, bug-template, automated-smoke-plan, test-environments, soak-template). Acknowledging the new bar so it's visible in ClickUp; the work is already done in commit 0f41828.
- created_at: 2026-05-01T (mid-run)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-006

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "[Uma] W1 · Player journey map — title to first kill to first death"
    status: complete
- reason: `team/uma-ux/player-journey.md` landed in commit 366744a. 12 beats from cold-launch to first death with 32-row tester checklist. Pure design task — exempt from #2/#4/#5 of testing bar's DoD per `TESTING_BAR.md`. Self-flipped to `complete`.
- created_at: 2026-05-02T (uma-run-001)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-007

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "design(ui): inventory & stats panel mockup (M1 surfaces)"
    status: complete
- reason: `team/uma-ux/inventory-stats-panel.md` landed in commit 366744a. M1 weapon+armor active; off-hand/trinket/relic stubbed visible-but-disabled; 8x3 grid; full keymap; tooltip spec; time-slow-on-open; 24-row tester checklist. Pure design task. Self-flipped to `complete`.
- created_at: 2026-05-02T (uma-run-001)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-008

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "design(ui): HUD mockup — HP, XP bar, level, gold, equipped relic"
    status: complete
- reason: `team/uma-ux/hud.md` landed in commit 366744a. Four-corner layout (vitals top-left, context top-right, cooldowns bottom-center, badges bottom-right), exact hex codes per element, mob/boss nameplate spec, 22-row tester checklist. Note: ClickUp title says "equipped relic" but M1 has no relic slot — the HUD doc explicitly stubs that for M2. Pure design task. Self-flipped to `complete`.
- created_at: 2026-05-02T (uma-run-001)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-009

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "design(art): visual direction one-pager + palette + reference board"
    status: complete
- reason: `team/uma-ux/visual-direction.md` + `team/uma-ux/palette.md` landed in commit 9a1e772. Visual call: pixel-art at 96 px/tile, 480x270 internal canvas, integer scaling only, nearest-neighbour filter project-wide. Palette is stratum-1 authoritative + strata 2-8 indicative + color-blind notes. 15-row + 12-row tester checklists. Reference board is text-only (game/film/illustrator names) per GIT_PROTOCOL "no large binaries". Pure design task. Self-flipped to `complete`.
- created_at: 2026-05-02T (uma-run-001)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-011

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "feat(mobs): grunt mob archetype — pathing, melee swing, death"
    status: ready for qa test
- reason: Drew run-002 task #8. PR #6 opened on `drew/grunt-mob`. Lands `scripts/mobs/Grunt.gd` + `scenes/mobs/Grunt.tscn` + the TRES schema implementation paired in per Priya's run-001 split (`scripts/content/*.gd`, ContentFactory, 7 authored seed TRES). 18 paired GUT tests in `tests/test_grunt.gd` covering full state machine + 3 required edge cases (rapid hit spam, death-mid-telegraph, death-while-pathing) + 14 schema/factory smoke tests in `tests/test_content_factory.gd`. Tess merges after sign-off.
- created_at: 2026-05-02T (drew-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-010

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "design(ux): death & restart-run flow — what feels fair"
    status: complete
- reason: `team/uma-ux/death-restart-flow.md` landed in commit 9a1e772. Death = comma not full stop. Sequence: lethal hit → embers gather → dissolve + bell → "You fell." card → run summary leading with KEPT (level, XP, stash) and de-emphasizing LOST WITH THE RUN. Default focus on "Descend Again". 25-row tester checklist. Includes failure-mode test cases (death during inventory open, quit during death sequence, etc.). Pure design task. Self-flipped to `complete`.
- created_at: 2026-05-02T (uma-run-001)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-011

- op: update_task
- list_id: 901523123922
- payload:
    task_id: 86c9kwhtt
    status: complete
- reason: Tess sign-off — Devon W1#4 (player movement + dodge-roll). 9 paired GUT tests in tests/test_player_move.gd verified via CI green (PR #5 + PR #7 runs). Edge-case probes run: EP-RAPID (rapid double-press → second rejected, dir not overwritten), EP-INTR (collision layer cleared during i-frames + restored after = mid-action interrupt safe), EP-EDGE (8-direction normalisation invariant). Run-002 retro sign-off after CI fix unblocked verification.
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-012

- op: update_task
- list_id: 901523123922
- payload:
    task_id: 86c9kwhu7
    status: complete
- reason: Tess sign-off — Devon W1#5 (player attacks). 17 paired GUT tests across tests/test_hitbox.gd (7) and tests/test_player_attack.gd (10), CI green. Edge-case probes: EP-DUP (single-hit-per-target collapses multi-overlaps + self-hit filtered), EP-RAPID (recovery blocks immediate re-attack), EP-INTR (attack blocked during dodge; dodge cancels recovery). Run-002 retro sign-off.
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-013

- op: update_task
- list_id: 901523123922
- payload:
    task_id: 86c9kwhuq
    status: complete
- reason: Tess sign-off — Devon W1#6 (JSON save/load skeleton). 14 paired GUT tests in tests/test_save.gd including the v0→v1 forward-compat test the testing bar singled out. CI green. Edge-case probes: EP-RT (round-trip default + modified payloads), EP-INTR (atomic write tmp→rename + .tmp cleanup), EP-OOO (corrupt JSON → empty dict, root-not-dict → empty dict). Phase A test_save_roundtrip.gd adds AC3-shaped death-rule pair (DECISIONS.md 2026-05-02 — equipped persists, level kept). Run-002 retro sign-off.
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-014

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "[Devon] W1 · #2 GitHub Actions CI workflow + GUT canary smoke test"
    status: complete
- reason: Tess sign-off — Devon W1#2 (CI + smoke canary). After Tess's run-002 PR #5 fixed the shell-bash and GUT-clone-path issues that were keeping CI red since first push, CI now executes the full pipeline. tests/test_smoke.gd (5 canary tests: engine version, Save autoload contract, Main scene loadability, input map, physics layer naming) green. Run-002 retro sign-off.
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-015

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "test(smoke): automated smoke test — game boots, title screen, no errors"
    status: complete
- reason: Tess sign-off — W1#17 (automated smoke). Phase A merged in PR #7 (commit 8b801f9): tests/test_boot.gd (4 tests), tests/test_autoloads.gd (4 tests, GameState placeholder marked `pending` until autoload registers), tests/test_save_roundtrip.gd (9 tests including death-rule pair), tests/test_quit_relaunch_save.gd (4 integration tests for AC6). 22 new tests, CI green. Phase A inventory in automated-smoke-plan.md updated to `landed`. Run-002.
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-016

- op: create_task
- list_id: 901523123922
- payload:
    name: "bug(mobs): Grunt._apply_layers does not handle CharacterBody2D default 1"
    priority: high
    tags: [bug, mobs, week-1]
    status: to do
    description: |
      ## Severity: major

      ## Build
      - Source: PR #6 (drew/grunt-mob), tip 0b79003
      - Discovered via CI run 25250844944 (red since first push of this PR).

      ## Repro
      Run GUT against the PR head: `tests/test_grunt.gd::test_collision_layer_is_enemy` fails — got 1, expected 8 (LAYER_ENEMY). Mask: got 1, expected 3 (world+player).

      ## Root cause
      `Grunt._apply_layers()` guards with `if collision_layer == 0`, but `CharacterBody2D` defaults to `collision_layer = 1` when constructed via `GruntScript.new()` (no .tscn). The default never fires, layer stays at 1.

      Production .tscn-loaded grunts are unaffected (the .tscn pre-sets layer to 8). This bug only fires for code paths that construct via `GruntScript.new()` — which is exactly what `tests/test_grunt.gd::_make_grunt()` does, plus any future spawner that might do the same.

      ## Fix
      Drop the `if collision_layer == 0` guard and unconditionally assign `LAYER_ENEMY` / mask in `_apply_layers()`. Simpler invariant: "Grunt is always on the enemy layer."

      ## Workaround
      `gh pr checkout 6` and run the failing test against a Grunt spawned from `Grunt.tscn` instead of `GruntScript.new()` — the layer is correct in that path.

      ## Owner
      Drew (PR #6 author). Bounce review at https://github.com/TSandvaer/RandomGame/pull/6#issuecomment-4363696819.
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-017

- op: create_task
- list_id: 901523123922
- payload:
    name: "bug(test): four content-factory tests flagged Risky — Did not assert"
    priority: normal
    tags: [bug, test, week-1]
    status: to do
    description: |
      ## Severity: minor

      ## Build
      - Source: PR #6 (drew/grunt-mob), tip 0b79003.
      - Test file: `tests/test_content_factory.gd`.

      ## Repro
      Run GUT against the PR head. The following four tests are reported by GUT as Risky (`Did not assert`) despite containing `assert_eq` calls:
        - `test_make_affix_def_defaults`
        - `test_make_affix_def_overrides`
        - `test_make_item_def_defaults`
        - `test_make_loot_table_default_independent_mode`

      Sibling test `test_make_affix_value_range_defaults` passes normally. Pattern: the four risky tests all begin with a typed local assignment from a `make_*` factory (e.g. `var a: AffixDef = ContentFactory.make_affix_def()`), where `make_affix_value_range` (which works) returns into a typed `AffixValueRange` — same pattern, different class.

      ## Suspected cause
      Typed-variable assignment from `_<Class>.new()` errors silently for AffixDef / ItemDef / LootTableDef but not AffixValueRange. Possibly a `class_name` registration order issue at parse time, or a typing mismatch in the factory's return signature when the schema script declares non-trivial state.

      ## Debug step
      Drop the type annotation in one risky test (`var a = ContentFactory.make_affix_def()`); if asserts then fire, the cast is the issue and the factory's return type is the load-bearing fix.

      ## Why this matters
      Per `team/TESTING_BAR.md` `## Maintenance discipline`: a no-assert test is a flaky-shaped test — same fix-or-quarantine rule. Cannot ship M1 with silent-pass tests in the inventory.

      ## Owner
      Drew (PR #6 author).
- created_at: 2026-05-02T (tess-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")

## ENTRY 2026-05-02-018

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "feat(loot): gear drop on mob death — T1 weapon, T1 armor stub"
    status: ready for qa test
- reason: Drew run-002 task #10 — LootRoller flagship coverage. PR opened on `drew/loot-roller` (stacked atop `drew/grunt-mob`). Lands `scripts/loot/{LootRoller,AffixRoll,ItemInstance,Pickup,MobLootSpawner}.gd` + `scenes/loot/Pickup.tscn`. LootRoller covers both `roll_count: -1` independent and `roll_count: N` weighted-pick modes; deterministic seeding via `seed_rng(int)`; tier modifier clamping; affix pick-without-replacement via Fisher-Yates; ADD/MUL apply_mode on AffixRoll. Tests: `tests/test_loot_roller.gd` (24 tests) covering all 10 edge cases from the schema doc + weight distribution sanity (4000-roll chi-square-ish 75%/25% band) + ADD/MUL math + tier-respect distinctive-range catch + same-seed determinism + different-seed divergence + T1/T2/T3 affix counts + duplicate-free affix picks + clamp_tier + authored-grunt-drops-table integration. `tests/test_mob_loot_spawner.gd` (4 tests) wires Grunt.mob_died -> spawner -> Pickup integration. Tess merges after sign-off; depends on PR #6 merging first.
- created_at: 2026-05-02T (drew-run-002)
- attempts: 1 (MCP returned "ClickUp is not connected")
- note: PR #6 typed-array bug Tess flagged (entry 017) is fixed in commit 0693476 on drew/grunt-mob — CI now green.

---

## 2026-05-02 22:30 — second-batch flush (entries 018-026)

ClickUp MCP reconnected; orchestrator drained the 9-entry queue accumulated since the first flush.

**Resolutions:**

- **ENTRY 018** (`86c9kxx8a` → `in progress`) — applied. Devon run-008 transitional status for `chore(ci): hardening pass`.
- **ENTRY 019** — skipped. Superseded by ENTRY 021's terminal `complete` status (Devon's run-008 self-merge under wide reading of `chore(ci)` exemption was overridden by Tess sign-off via PR #78 in run-009 + run-017).
- **ENTRY 020** — skipped. Superseded by ENTRY 021.
- **ENTRY 021** (`86c9kxx8a` → `complete`) — applied. Tess run-017 sign-off + merge of PR #78 covering the three uncovered gaps on top of Devon run-008's PR #76. Process slip filed in `team/log/process-incidents.md`.
- **ENTRY 022** (create `bug(html5): InventoryPanel + StatAllocationPanel _exit_tree...`) — applied; created task **`86c9kzmf7`**. Tags: `bug`, `week-3` (`html5` was not a recognized space tag).
- **ENTRY 023** (create `chore(progression): drop dead null-check in StratumProgression.restore_from_save_data`) — applied; created task **`86c9kzmfe`**. Default status; Devon currently in flight on `devon/cr-3-stratum-progression-cleanup`. Tags: `chore`, `week-3`.
- **ENTRY 024** — skipped. Superseded by ENTRY 025.
- **ENTRY 025** (`86c9kzmf7` → `complete`) — applied. Tess run-019 sign-off + merge of Devon's PR #87 (`fix(ui): _exit_tree restores Engine.time_scale on InventoryPanel + StatAllocationPanel`) at squash commit `98a344e`. Tess's TI-6 + TI-7 in `tests/integration/test_html5_invariants.gd` flipped pending → live in same PR.
- **ENTRY 026** (create `fix(mobs): charger orphan-velocity race in death-mid-charge path` with terminal `complete` status on create) — applied; created task **`86c9kzmfm`**. Tags: `bug` (`mobs`/`charger`/`ci-flake` were not recognized space tags). Drew run-007 fix at `7697ca5` via PR #94, Tess run-020 sign-off. ClickUp DID accept create-with-terminal-status `complete` on this list — the fallback note's contingency was unnecessary.

**Operational note for future flushes:** the recognized space-level tags are limited to `bug`, `chore`, `week-3` (others observed: `feat`, `qa`, `design`, but not the per-system tags). Tag-creation requires Sponsor or workspace-level permission; for now, tag with what's recognized and rely on the ticket name's `<scope>:` prefix for system-level filtering.

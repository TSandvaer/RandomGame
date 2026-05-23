# ClickUp pending queue

Operations that failed against the ClickUp MCP and need replay on the next dispatch.
Format per `team/CLICKUP_FALLBACK.md`. Move synced entries to `clickup-synced.md`.

---

(empty — second batch of 9 entries (018-026) flushed 2026-05-02 22:30 by orchestrator after MCP reconnected. First batch of 17 entries was flushed earlier the same day. See `clickup-synced.md` for full history.

New ClickUp task IDs created during the 22:30 flush:
- `86c9kzmf7` — `bug(html5): InventoryPanel + StatAllocationPanel _exit_tree does not restore Engine.time_scale` — status `complete` (fixed by Devon PR #87, signed off by Tess run-019).
- `86c9kzmfe` — `chore(progression): drop dead null-check in StratumProgression.restore_from_save_data` — default status (Devon currently in flight on `devon/cr-3-stratum-progression-cleanup`).
- `86c9kzmfm` — `fix(mobs): charger orphan-velocity race in death-mid-charge path` — status `complete` (fixed by Drew PR #94, signed off by Tess run-020).

Entry mapping (queue → action taken):
- ENTRY 018 (`86c9kxx8a` → in progress) — applied
- ENTRY 019 (skipped — superseded by 021's terminal status)
- ENTRY 020 (skipped — superseded by 021's terminal status)
- ENTRY 021 (`86c9kxx8a` → complete) — applied
- ENTRY 022 (create bug(html5) CR-1+CR-2) — applied; created `86c9kzmf7`
- ENTRY 023 (create chore(progression) CR-3) — applied; created `86c9kzmfe`
- ENTRY 024 (skipped — superseded by 025)
- ENTRY 025 (`86c9kzmf7` → complete) — applied
- ENTRY 026 (create fix(mobs) charger flake with status complete) — applied; created `86c9kzmfm` with terminal status accepted on create.

Tags noted: `mobs`, `charger`, `ci-flake`, `html5`, `progression` are NOT existing tags in the ClickUp space — only `bug`, `chore`, `week-3` are recognized. The created tasks have only the recognized tags applied. If those tag categories are needed long-term, Sponsor or Priya can add them at the space level.)

---

## ENTRY 2026-05-03-027

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "86c9m3b3x"
    status: "ready for qa test"
    note: |
      Uma run-010 — PR #121 opened (`design(ux): Sponsor-soak prep checklist + probe-target enumeration`).
      Closes T-EXP-7 (P1) from `team/priya-pl/backlog-expansion-2026-05-02.md`.
      NEW doc `team/uma-ux/sponsor-soak-checklist.md` (~340 lines, 9 sections + caveat).
      Ticket already at `in progress`; per `clickup-status-as-hard-gate.md` paired-flip rule, would normally fire in same tool round as `gh pr create` — but MCP returned 'not connected' on the live attempt. Queued here for next-tick flush.
- created_at: 2026-05-03T (Uma run-010)
- attempts: 1 (MCP not connected at attempt time)

---

## ENTRY 2026-05-06-028

- op: create_task
- list_id: 901523123922
- payload:
    name: "design(level): Stratum-1 Room01 missing tutorial dummy + LMB/RMB beats (player-journey.md drift)"
    priority: P2
    tags: [bug, design-doc-drift, levels, onboarding]
    status: "to do"
    description: |
      **Filed by:** Drew (via run dispatched 2026-05-06 — Stage 2b investigation
      following Sponsor's post-fix-wave HTML5 trace showing all combat damage
      paths returning `damage=1`).

      **Symptom:** Sponsor's HTML5 trace on `embergrave-html5-f62991f` showed
      light AND heavy attacks both deal `damage=1`. With Grunt at 50 HP that's
      50 hits per kill, with no on-screen indication that this is intended.

      **Investigation result:** the `damage=1` is **NOT a damage-scaling bug**
      — it's `Damage.compute_player_damage()` correctly returning
      `FIST_DAMAGE = 1` because the player has no weapon equipped. Per
      DECISIONS.md `2026-05-02 — Damage formula constants locked`:
      *"Fist (no weapon) is **flat 1 damage** with no Edge/heavy scaling"*.
      Locked design.

      **Real bug:** `team/uma-ux/player-journey.md` Beats 4-5 specify Stratum-1
      Room01 contains a **non-threatening practice dummy + LMB/RMB tutorial
      prompts** ("WASD to move." → "Space to dodge-roll." → "LMB to strike."
      → dummy poof on third hit → door grinds open → "RMB for heavy strike."
      prompt before player exits to Beat 6 / Room02 / first real grunt).

      The shipped `resources/level_chunks/s1_room01.tres` has:
      - 2 Grunt mob_spawns at (11,3) and (8,5)
      - NO practice dummy
      - NO tutorial prompt overlay wired

      Live UX: player drops in fistless and immediately fights two 50-HP
      grunts at 1 damage per swing (100 fist hits total), no tutorial cue,
      no early loot drop. Combined with the `bug(onboarding): boot banner
      missing LMB/RMB attack bindings` ticket (`86c9m3969`), the M1 onboarding
      surface has zero teach-by-doing affordances. Both individually pass
      headless tests; the integration surface is what fails.

      **Why P2 (design-doc gap, not regression):** Room01 never shipped the
      practice dummy — there's no git history of a regression that removed
      it. The design doc and the shipped content disagree from the start of
      M1 RC. Player-journey is Uma's spec; level chunks are Drew's
      implementation. Neither was wrong in isolation — they were never
      reconciled. Sponsor's experience of "I just punch things forever" is
      the predicted UX outcome.

      **Recommended fix scope (Drew-owned):**
      1. Add a `PracticeDummy` mob type (or static `BreakableObject`) with
         tunable HP=3, no damage output, ember-poof on death.
      2. Update `s1_room01.tres` mob_spawns to: 1 dummy at center-room, 0
         grunts. Move existing 2 grunts to s1_room02.tres (currently has
         its own spawns — confirm via Drew before edit).
      3. Wire `TutorialPromptOverlay` event-bus emits at WASD/Space/LMB/RMB
         beats per Uma's spec (Devon-owned scaffold; Drew triggers from
         Room01 entry).
      4. Either drop a guaranteed iron_sword from the dummy OR ensure
         Room02 grunt has a weighted-bias drop so the player gets equipped
         before grunt #2.

      **Alternative (lower-cost):** if the practice-dummy beat is too much
      M1-late scope, a one-line `s1_room01.tres` edit to **delete one of the
      two grunt spawns** would at least halve the onboarding fistless slog.
      This is bandaid-grade, not design-correct — file alongside the proper
      ticket as a "if we ship M1 this week" fallback.

      **Cross-references:**
      - DECISIONS.md `2026-05-02 — Damage formula constants locked` (FIST_DAMAGE = 1 design lock)
      - `team/uma-ux/player-journey.md` Beats 4-5 (practice dummy + tutorial prompt spec)
      - `team/priya-pl/affix-balance-pin.md` §4 (Feel check #1: assumes T1 sword equipped)
      - `team/tess-qa/m1-bugbash-4484196.md` BB-5 (`86c9m3969`) — boot banner missing LMB/RMB (sibling onboarding miss)
      - Sponsor's HTML5 trace on `embergrave-html5-f62991f` run 25396441101

      **Owners:** Drew (level chunk + dummy mob), Uma (sign off the
      reconciliation between the doc spec and the implementation), Devon
      (TutorialPromptOverlay event bus if not built yet — check
      `team/uma-ux/player-journey.md` Beat 4 hand-off).
- created_at: 2026-05-06T (Drew run-002 Stage 2b)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-029

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "86c9y0zyv"
    name: "feat(dialogue): impl + first 3 hub-town dialogue trees + signal-signature wiring"
    status: "to do"
    description: |
      **W2-T2 — Dialogue system implementation + first 3 hub-town dialogue trees.**

      **Source of truth:** `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1 + v1.3 §B (W2 ticket-shape verdict — amend to fold Part D explicitly). Builds on the W1 dialogue spike (`86c9xuab3`, PR landed).

      **Owner:** Devon (primary, engine + UI + signal wiring); Drew assists on hub-town tree authoring.

      **Size:** L (6-10 ticks).

      **Priority:** P0.

      **Scope:**
      - **Part A — DialogueController consumer wiring.** Wire `DialogueController` autoload into the production play loop (`scripts/player/Player.gd` attack-input gating per `.claude/docs/dialogue-system.md` § "Player attack-input gating convention seed"). Modal `DialoguePanel` opens on NPC interact; closes on response selection or ESC.
      - **Part B — First 3 hub-town dialogue trees.** Three `DialogueTreeDef` `.tres` resources for the hub-town NPCs scoped by `m3-design-seeds.md` (e.g. marksman / merchant / storyteller — Drew confirms final identities). Each tree has 2-4 branches with at least one `quest_action` side-effect channel emit to exercise the `QuestActionRouter` listener stub.
      - **Part C — QuestActionRouter listener stub.** Minimal listener autoload that receives `dialogue_closed(npc_id: StringName)` + `quest_action(npc_id: StringName, action: StringName)` signals from `DialogueController`. Stub records last-event + emits a `quest_action_received` echo signal for test verification. Full QuestState integration is W2-T6.
      - **Part D — Drew nit fold (PR #320 review-nit routing per v1.2 §5.1).**
        - Nit 1 — `dialogue_closed(npc_id)` MUST be single-arg (not two-arg `(npc_id, branch_key)`). The `branch_key` is captured via `DialogueController.current_branch_key()` BEFORE `close()` clears state.
        - Nit 2 — `close()` signature is no-args (`close() -> void`).
        - Read-order discipline: the `QuestActionRouter` listener stub MUST read `current_branch_key()` synchronously BEFORE `close()` clears state. Paired GUT test `test_quest_action_listener_reads_branch_key_before_close.gd` pins the read-order.

      **Acceptance:**
      - Paired GUT in `tests/test_dialogue_controller.gd` (open/close lifecycle, branch resolution, quest_action emit), `tests/test_dialogue_panel.gd` (modal UI gating, ESC dismiss, response-selection routing), `tests/test_quest_action_router_stub.gd` (signal echo + last-event capture), `tests/test_quest_action_listener_reads_branch_key_before_close.gd` (Part D read-order pin).
      - Playwright spec `tests/playwright/specs/dialogue-hub-town.spec.ts` exercises the 3 hub-town trees end-to-end via release-build with `[dialogue-trace]` drift-pin assertions.
      - HTML5 visual verification per `.claude/docs/html5-export.md` — DialoguePanel is a modal UI surface with `modulate` fades; visual gate fires. Author-self-soak in incognito + DevTools per `html5-visual-gated-author-self-soak`.
      - Self-Test Report comment per Self-Test Report gate.
      - Tess sign-off via M3 Tier 3 acceptance plan rows DG-1..DG-10 + AC-C2 / AC-C3 row updates.

      **Out-of-scope:**
      - Full QuestState integration (W2-T6 owns it; this ticket ships the stub listener only).
      - Dialogue authoring beyond the first 3 hub-town trees (W3 expands the catalog).
      - Dialogue-driven world-map UI integration (W2-T5 surface).

      **Files in play:**
      - `scripts/dialogue/DialogueController.gd` (extend per consumer wiring needs)
      - `scripts/dialogue/DialoguePanel.gd` (production-wire from spike)
      - `scripts/player/Player.gd` (attack-input gating)
      - `scripts/quests/QuestActionRouter.gd` (NEW — listener stub)
      - `resources/dialogue/hub_town/*.tres` (3 new tree resources)
      - `tests/test_dialogue_*.gd` + `tests/test_quest_action_*.gd` (paired GUT)
      - `tests/playwright/specs/dialogue-hub-town.spec.ts` (Playwright)

      **Cross-references:**
      - `.claude/docs/dialogue-system.md` — DialogueTreeDef / DialogueController contract.
      - `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1 (Drew nit routing) + v1.3 §B (amend verdict).
      - `team/tess-qa/m3-acceptance-plan-tier-3.md` DG-1..DG-10 + AC-C2 rows.
      - `team/devon-dev/save-schema-v5-tier3-additions.md` (PR #320 — Drew's review nits source).
      - `m3-diablo-shape-directive` memory entry — dialogue is Commitment 2.
- created_at: 2026-05-23T (Priya si8-lock dispatch — MCP outage at attempt time)
- attempts: 1 (MCP not connected at attempt time)

---

## ENTRY 2026-05-23-030

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "86c9y1045"
    name: "feat(level): assemble_floor impl + S1 procgen retrofit (SI-8 (b) locked)"
    status: "to do"
    description: |
      **W2-T3 — `assemble_floor` impl + S1 procgen retrofit.**

      **SI-8 status:** **LOCKED to option (b) — partially procedural with hand-pinned set-pieces** (Sponsor sign-off 2026-05-23 10:08 UTC on PR #328). The (a) and (c) scope branches from v1.2 §5.2 drop out; this ticket body inlines the (b)-locked scope verbatim.

      **Source of truth:** `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.2 (option-neutral pre-shape) + PR #328 SI-8 recommendation section (Devon Part D foundation) + `team/priya-pl/si8-lock-2026-05-23-w2-unblock.md` (this dispatch's summary doc).

      **Owner:** Drew (primary, S1 ZoneDef authoring + retrofit) + Devon (secondary, FloorAssembler extension + integration).

      **Size:** L-XL (5-7 ticks per v1.2 §5.2 (b) row sizing).

      **Priority:** P0.

      **Dependencies:**
      - W2-T4 `86c9y108t` (world_seed save-write) lands first OR is far enough along to consume from. W2-T4 is small (S-M); minimal serialization cost.
      - W2-T1 `86c9y0zmg` (camera-scroll integration) — `Main._load_room_at_index → set_world_bounds(assembled_bounds)` wiring belongs to W2-T1; this ticket consumes the wired surface but does NOT modify it.

      **Scope ((b)-locked):**
      - **Part A — FloorAssembler extension (Devon).** Extend `scripts/levels/FloorAssembler.gd` per S1 retrofit needs. No shape change vs spike (the spike's runtime API is the contract); additive logic only.
      - **Part B — `s1_room01.tres` east-seam port fix (Drew).** Add EAST `&"exit"` port at `position_tiles=(14, 4)` per `tests/test_floor_assembler.gd:496` docstring + spike-finding fix-shape. Mating-count drops 1 → 0. Update the sibling pin `test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding` in the same PR (the pin currently asserts count == 1; post-fix it asserts count == 0 OR is renamed/removed per the docstring).
      - **Part C — S1 8-room retrofit to ZoneDef-driven assembly (Drew).** Each of the 8 S1 rooms becomes an anchor in a Stratum-1 `ZoneDef` (5 anchors per the spike worked-example pattern: entry + npc_room + quest_target + boss_room + exit, plus 3 additional anchor rooms for S1 specifically). `procedural_slot_pool` per (b) lock is smaller than (a) would require — light procedural fill between anchors only.
      - **Part D — Stratum-1 ZoneDef authoring (Drew).** New ZoneDef resources under `resources/level/zones/` (e.g. `s1_z1_outer_cloister.tres` per the spike worked example, expanded to cover the 8-room S1 set; further zones if S1 splits into multiple zones).
      - **Part E — GUT pin updates (Drew + Devon).** Extend `tests/test_floor_assembler.gd` with S1-zone-specific coverage: anchor reachability across all S1 ZoneDefs, port-mating clean across all retrofitted rooms, determinism across N≥8 seeds per the AC4-retro sample-size discipline.
      - **Part F — HTML5 visual-verification round.** Sponsor / author HTML5 soak per `.claude/docs/html5-export.md` HTML5 visual-verification gate. Z-index sensitivity at chunk seams + procedural-seam rendering divergence (R-PROCGEN.c) are the primary risk surfaces. Author-self-soak first per `html5-visual-gated-author-self-soak`; Sponsor confirms subjective feel per `sponsor-soak-routing.md` after Tess Playwright spec is green.

      **Acceptance ((b)-specific gates):**
      - `s1_room01.tres` east-seam port fix landed; `tests/test_floor_assembler.gd:496` pin updated; mating-count==0 across the worked-example zone.
      - All 8 existing S1 rooms retrofitted to ZoneDef-driven assembly; each declares anchor type per (b); smaller `procedural_slot_pool` than (a)-shape would require.
      - HTML5 visual-verification round passes: no z-index sharp edges at chunk seams; no visible gaps at procedural seams; HUD CanvasLayer immunity preserved across continuous-scroll path; no `USER WARNING:` / `USER ERROR:` console lines in author + Sponsor soak.
      - GUT pin extensions: anchor reachability + port-mating clean + N≥8 seed determinism + per-stratum / per-zone seed isolation per `m3-acceptance-plan-tier-3.md` AC-C5-4 / AC-C5-5.
      - Playwright spec `tests/playwright/specs/m3-procgen-determinism.spec.ts` covers AC-C5-1, AC-C5-2, AC-C5-3, AC-C5-7 with `[procgen-trace]` drift-pin pair.
      - Self-Test Report comment per Self-Test Report gate.
      - Tess sign-off via Track 1.5 PG-1..PG-8 rows in `m3-acceptance-plan-tier-3.md` + AC-C5 rows flip from `[PENDING-SPEC]` → `[GREEN]`.

      **Out-of-scope:**
      - **Pure-procedural fallback paths** (locked OUT by (b)) — no path where anchors are absent and all chunks are procedural.
      - **Per-stratum hybridity** (locked OUT by (b)) — no S1/S2/S3 divergence in the assembly model itself. `ZoneDef.stratum_id` permits per-zone divergence within the same model but not a model-level fork.
      - **S2 retrofit work** — W2-T3 is S1-only; S2 ZoneDef authoring lands in W3.
      - **`Main._load_room_at_index → set_world_bounds(assembled_bounds)` wiring** — that surface belongs to W2-T1 (camera-scroll integration). W2-T3 produces `AssembledFloor.bounding_box_px`; W2-T1 consumes it.
      - **Save schema bump** — W2-T4 ships world_seed additively on v5; W2-T3 consumes the save-read surface but does not modify it.

      **Files in play:**
      - `scripts/levels/FloorAssembler.gd` — extend per S1 retrofit needs (additive).
      - `resources/level_chunks/s1_room01.tres` — east-seam port fix (single-file edit).
      - `resources/level_chunks/s1_room02.tres` through `s1_room08.tres` — anchor metadata extension per ZoneDef-driven assembly.
      - `resources/level/zones/s1_z1_*.tres` (NEW) — S1 ZoneDef resources (anchor set + (b)-locked smaller procedural_slot_pool).
      - `tests/test_floor_assembler.gd` — W2 pin extensions; spike's 18 pins extend with S1-zone-specific coverage.
      - `tests/playwright/specs/m3-procgen-determinism.spec.ts` (NEW) — paired Playwright spec.

      **Cross-references:**
      - PR #328 SI-8 recommendation section (Devon Part D) — foundation for the (b) lock.
      - `m3-diablo-shape-directive` memory entry — Diablo-shape directive seed (5 Sponsor commitments).
      - `team/tess-qa/m3-acceptance-plan-tier-3.md` Track 1.5 PG-1..PG-8 + AC-C5 rows — Tess acceptance scaffold.
      - `.claude/docs/procgen-pipeline.md` — runtime API + port-mating discipline + seed-cascade contract.
      - `.claude/docs/camera-scroll.md` § "Open follow-ups" — W2-T1 consumer surface for `bounding_box_px`.
      - `team/drew-dev/level-chunks.md` § "Zone schema (M3 Tier 3 W1 spike)" — ZoneDef / ZoneAnchor / procedural_slot_pool schema source.
      - `team/priya-pl/si8-lock-2026-05-23-w2-unblock.md` — this dispatch's summary doc + Decision draft.
- created_at: 2026-05-23T (Priya si8-lock dispatch — MCP outage at attempt time)
- attempts: 1 (MCP not connected at attempt time)

---

## ENTRY 2026-05-23-031

- op: update_task
- list_id: 901523123922
- payload:
    task_id: "86c9y108t"
    name: "feat(save): per-character world_seed save-write + v5 additive field"
    status: "to do"
    description: |
      **W2-T4 — Per-character `world_seed` save-write + v5 additive field.**

      **Source of truth:** `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1 + v1.3 §B (W2 ticket-shape verdict — amend to fold Part D explicitly). Promotes Part B of the W1 procgen spike (`86c9xub9p`, PR #328 merged) from v4-additive (sentinel `0` backfill) to v5-canonical (rolled per-character on creation).

      **Owner:** Devon (primary, save-schema lift + impl).

      **Size:** S-M (1-3 ticks).

      **Priority:** P0 — unblocks W2-T3 procgen retrofit (consumes `Character.world_seed` for derive_zone_seed cascade).

      **Scope:**
      - **Part A — Save schema v5 lift.** Promote `character.world_seed: int` from the v4-additive layer (PR #328 Part B) to the v5-canonical layer per `team/devon-dev/save-schema-v5-plan.md`. v4 → v5 migration backfills `world_seed = 0` for legacy characters (sentinel = "needs roll on next character-open").
      - **Part B — Roll-on-creation discipline.** New character creation rolls `world_seed` via `randi()`; immutable thereafter. Existing v4-saved characters with `world_seed == 0` get re-rolled on first v5 load (one-time backfill).
      - **Part C — `_migrate_v4_to_v5` migration helper.** New migration in `scripts/save/Save.gd` per the v5-plan additive-only doctrine. Paired GUT pins for migration determinism + backfill semantics.
      - **Part D — Drew nit fold (PR #320 review-nit per v1.2 §5.1).**
        - Nit 3 — `_migrate_v5_to_v5_tier3` was a misnomer in the survey doc; correct name per Save.gd HEAD = v4 at the time of survey authorship. One-line footnote update to the survey § header noting Save.gd HEAD is still v4 + v5 lift is paper-only at survey authorship time. Footnote lands in `team/devon-dev/save-schema-v5-tier3-additions.md` survey § header.

      **Acceptance:**
      - Paired GUT in `tests/test_save.gd` (v4→v5 migration + roll-on-creation + immutability post-roll).
      - Paired GUT in `tests/test_world_seed_persists_across_save_load.gd` (existing 7 pins extend to v5-canonical layer; the spike's end-to-end pin `test_world_seed_drives_identical_assemble_across_save_load` lifts from v4-additive to v5-canonical).
      - Two consecutive new-character rolls produce different `world_seed` values (high entropy invariant; uses `randi()` per spike).
      - v4-saved character with `world_seed == 0` re-rolls to non-zero on first v5 load (one-time backfill semantics).
      - Footnote update lands in `team/devon-dev/save-schema-v5-tier3-additions.md` survey § header per Part D.
      - Self-Test Report comment per Self-Test Report gate (save-schema PRs ARE save-affecting; gate applies).
      - Tess sign-off.

      **Out-of-scope:**
      - Full v5 multi-character lift (out of scope per `save-schema-v5-plan.md`; this ticket ships world_seed-only canonical promotion).
      - Quest state save fields (W2-T6 surface).
      - World-map UI save fields (W2-T5 surface).
      - The procgen-side `FloorAssembler` consumption — that's W2-T3; this ticket ships the write side only.

      **Files in play:**
      - `scripts/save/Save.gd` — `_migrate_v4_to_v5` + roll-on-creation + immutability discipline.
      - `tests/test_save.gd` — migration + roll pins.
      - `tests/test_world_seed_persists_across_save_load.gd` — extend spike pins to v5-canonical layer.
      - `team/devon-dev/save-schema-v5-tier3-additions.md` — Part D survey § header footnote update.

      **Cross-references:**
      - `team/devon-dev/save-schema-v5-plan.md` — v5 additive-only doctrine source.
      - `team/devon-dev/save-schema-v5-tier3-additions.md` — Part D footnote target.
      - `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1 (Drew nit routing) + v1.3 §B (amend verdict).
      - PR #328 Part B (Devon) — v4-additive precursor that this ticket promotes to v5-canonical.
      - `.claude/docs/procgen-pipeline.md` § "Save-schema binding" — downstream consumer contract.
- created_at: 2026-05-23T (Priya si8-lock dispatch — MCP outage at attempt time)
- attempts: 1 (MCP not connected at attempt time)


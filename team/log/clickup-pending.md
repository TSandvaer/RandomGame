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

## ENTRY 2026-06-04-001
- op: update_task (status move TO DO → IN PROGRESS, then → READY FOR QA TEST)
- list_id: 901523123922
- payload:
    name: "feat(player): install new monk sprite rig (8-dir, 6 anims)"
    target_status: "ready for qa test"
    pr: "https://github.com/TSandvaer/RandomGame/pull/409"
- NOTE: **No ClickUp ticket ID was provided in the dispatch brief** for the
    monk-rig-install task, and no matching ticket was found in
    clickup-synced.md / clickup-pending.md. Drew did NOT fabricate an ID
    (per never-fabricate rule). **Orchestrator/Priya: locate or create the
    monk-rig ticket on the board and flip it to `ready for qa test`** paired
    with PR #409. The work is complete + PR open; ClickUp is the only gate
    not actioned (could not action without a real ticket ID).
- created_at: 2026-06-04 (Drew monk-rig-install)
- attempts: 0

## ENTRY 2026-06-06-001
- op: update_task (status move TO DO → IN PROGRESS → READY FOR QA TEST)
- task_id: 86ca5a5vy
- list_id: 901523123922
- payload:
    name: "feat(mobs): install shooter brazier-warden rig into shooter mob .tres"
    target_status: "ready for qa test"
    pr: "https://github.com/TSandvaer/RandomGame/pull/413"
- NOTE: Drew lacks the ClickUp MCP tool. PR #413 open + all gates green
    (GUT 0-failing, HTML5 release build success, HTML5 author-self-soak PASS,
    Playwright strictly-no-worse-than-main). **Orchestrator: flip 86ca5a5vy →
    `ready for qa test`** paired with PR #413, then route to Tess (game-side QA).
- created_at: 2026-06-06 (Drew shooter-rig-install)
- attempts: 0

## ENTRY 2026-06-06-002
- op: update_task (status move → READY FOR QA TEST, partial — 2 of 3 fixes)
- task_id: 86ca5agrd
- list_id: 901523123922
- payload:
    name: "fix(combat|art): shooter fire-casting polish — drop red tint + real fireball-projectile art + single-bowl cast (Sponsor soak #413)"
    target_status: "ready for qa test"
    pr: "https://github.com/TSandvaer/RandomGame/pull/413"
- NOTE: Drew lacks the ClickUp MCP tool. Pushed to PR #413's branch
    (drew/86ca5a5vy-shooter-rig-install) SHA 5295dbd. **Fix #1 (red telegraph
    tint removed) + #2 (real fireball projectile art + travel-dir rotation)
    DONE + paired tests + gdlint/gdformat clean.** **Fix #3 (single-bowl cast)
    BLOCKED on tooling — escalated to orch:** a sub-agent PIL erase of the
    conjured raised-hand flame is not cleanly viable (brazier + conjured flame
    overlap+swap position across the 6-frame cast; flame mask contaminated by
    eye-glow in non-south dirs — preview proved brazier damage + residual 2nd
    flame). Matches the ticket's own "pixel-mcp surgical edit / orch decides
    cast approach" note. See PR #413 Self-Test Report comment for full
    empirical evidence + integ-soak probe targets. **Orchestrator: (a) flip
    86ca5agrd status reflecting #1+#2 ready-for-QA + #3 open; (b) run the
    pixel-mcp single-bowl cast edit (orch-only tool) OR re-dispatch #3 once a
    cast-frame fix exists; (c) route #1+#2 to Tess + fold into the #413/#414
    integ-build re-soak.**
- created_at: 2026-06-06 (Drew shooter fire-casting polish)
- attempts: 0

## ENTRY 2026-06-07-001
- op: update_task (status move → READY FOR QA TEST)
- task_id: 86ca5errv
- list_id: 901523123922
- payload:
    name: "feat(level): S1 → FloorAssembler retrofit in Main.gd (keystone)"
    target_status: "ready for qa test"
    pr: "https://github.com/TSandvaer/RandomGame/pull/421"
- NOTE: Devon lacks the ClickUp MCP tool. S1→assembler keystone retrofit done +
    paired GUT tests (10/10 green local: integration + grunt-radius BFS
    navigability gate) + cross-lane regression sets green (S2 traversal/mob-spawns,
    camera wiring, floor assembler, M1 play loop) + Self-Test Report posted on
    PR #421. gdformat/gdlint clean (no new findings). Soak-gated behind
    ?s1_assembler=1 — default boot byte-identical. HTML5 visual gate: escape
    clause invoked (no interactive Chromium in CLI env); Sponsor-soak probe
    targets in PR body — route a diag-build artifact (path INERT in production
    until the flag is set). **Orchestrator: (a) flip 86ca5errv →
    ready for qa test paired with PR #421; (b) route to Tess (engine/integration
    QA).**
- created_at: 2026-06-07 (Devon S1 assembler retrofit)
- attempts: 0

---

## ENTRY 2026-06-11-001

- op: create_task
- list_id: 901523123922
- payload:
    name: "chore(iso): harvest iso ground pipeline — commit scripts, atlases, and tileset as reviewed PR"
    priority: high
    tags: [iso, harvest, tech-debt]
    status: "to do"
    description: |
      **Source:** R&D investigation 2026-06-11. Iso sprint 2026-06-08..11 left the
      ground pipeline uncommitted. This ticket closes the absorption gap for the
      iso ground layer.

      **Scope — files to commit in one harvest PR:**
      - `assets/iso_proof/*.py` — numpy/PIL procedural tile generation scripts
      - `assets/iso_proof/atlases/` — generated tile atlases (PNG)
      - `assets/iso_proof/iso_proof_tiles.tres` — TileSet resource referencing the atlas
      - `_check_iso_tiles.gd` + `_check_iso_tiles.gd.uid` — headless TileMap probe
      - `_check_iso_terrain.gd` + `_check_iso_terrain.gd.uid` — headless terrain probe
      - Any associated `_tile_judge/`, `_tile_direction.md`, floor_meta.json, floor mock/tileset PNGs
        that constitute ground pipeline output (verify by `git status` at task start)

      **Out of scope:** building kit (separate ticket H2 / ENTRY 2026-06-11-002);
      doc commits (separate ticket H3 / ENTRY 2026-06-11-003).

      **Acceptance criteria:**
      1. All ground pipeline files listed above are committed to `main` via a PR with
         title `chore(iso): harvest iso ground pipeline — scripts, atlases, tileset (H1)`.
      2. PR body describes each artifact: what it does, what tool/script generated it,
         and any known limitations or TODOs.
      3. Devon peer-reviews the PR (engine/harness surface per `tess-cant-self-qa-peer-review`
         convention). Review must confirm: no regressions in existing GUT suite; no
         `.gd` files with gdlint/gdformat violations; `.tres` resource loads cleanly
         in Godot 4.6 without errors.
      4. CI green before merge.
      5. No files from the building kit or docs land in this PR — keep surfaces clean.

      **Out of scope (explicit):**
      - No gameplay wiring (tiles are not yet integrated into production play loop)
      - No Tess QA sign-off required (harvest/chore class; peer review is the gate)
      - No HTML5 visual verification required (no interactive rendering paths)

      **Success test:** `git log --oneline -10 origin/main` after merge shows the
      harvest commit; `git status` on a fresh clone shows none of the listed files
      as untracked.

      **Owner:** Devon (harvest author + peer reviewer pair); orchestrator opens
      the PR and triggers Devon review per dispatch convention.

      **Size:** M. **Priority:** High (absorption debt blocks procgen productionization
      tickets from having a clean dependency baseline).

      **Cross-references:**
      - R&D investigation 2026-06-11 (source of this ticket)
      - `.claude/docs/orchestration-overview.md` § "R&D lane" (harvest gate mandate)
      - ENTRY 2026-06-11-002 (building kit harvest, sibling)
      - ENTRY 2026-06-11-003 (orch-docs harvest, sibling)
- created_at: 2026-06-11 (Priya, rnd-lane-convention task)
- attempts: 0

---

## ENTRY 2026-06-11-002

- op: create_task
- list_id: 901523123922
- payload:
    name: "chore(iso): harvest iso building kit — commit building scenes, scripts, and probes as reviewed PR"
    priority: high
    tags: [iso, harvest, tech-debt, levels]
    status: "to do"
    description: |
      **Source:** R&D investigation 2026-06-11. Iso sprint 2026-06-08..11 left the
      building kit uncommitted. This ticket closes the absorption gap for the iso
      building layer.

      **Scope — files to commit in one harvest PR:**
      - `assets/iso_proof/buildings/` — building sprite/atlas assets (all files)
      - `assets/props/s1_cloister/_pixellab_raw/` — raw PixelLab building PNGs
        (banner, braziers, cracked wall, moss, niche, pillar, rubble column variants)
      - `scenes/levels/demo/buildings/` — all building `.tscn` scenes (11 buildings
        per investigation verdict; verify exact count by `git status` at task start)
      - `scripts/levels/BuildingFade.gd` — building fade-in/out script
      - `_check_buildings.gd` + `_check_buildings.gd.uid` — headless building probe
      - `_check_fade.gd` — headless fade probe
      - `_yard_compose_judge/`, `_yard_review/` — yard composition judge outputs
        (if present; verify by `git status`)

      **Out of scope:** ground pipeline (separate ticket H1 / ENTRY 2026-06-11-001);
      doc commits (separate ticket H3 / ENTRY 2026-06-11-003).

      **Acceptance criteria:**
      1. All building kit files listed above are committed to `main` via a PR with
         title `chore(iso): harvest iso building kit — scenes, scripts, probes (H2)`.
      2. PR body describes each artifact: scene name, what building it represents,
         which PixelLab source it was generated from (PixelLab job ID or prompt hash
         if known), any known TODOs (e.g. placeholder geometry, missing shadow pass).
      3. Drew peer-reviews the PR (game-side surface per `tess-cant-self-qa-peer-review`
         convention). Review must confirm: scenes load without errors in Godot 4.6;
         BuildingFade.gd passes gdlint/gdformat; no GUT regressions; `.tscn` files
         reference only paths that exist in the committed tree.
      4. CI green before merge.
      5. No ground pipeline files or doc files land in this PR.

      **Out of scope (explicit):**
      - No wiring into Main.tscn or production play loop (separate productionization ticket)
      - No Tess QA sign-off required (harvest/chore class; peer review is the gate)
      - HTML5 visual gate: escape clause applies — building scenes are not wired into
        production render path yet; visual gate fires at the productionization PR

      **Success test:** `git log --oneline -10 origin/main` after merge shows the
      harvest commit; all 11 building scenes are accessible at `scenes/levels/demo/buildings/`
      in a fresh checkout; `BuildingFade.gd` is importable without errors.

      **Owner:** Drew (harvest author + peer reviewer pair); orchestrator opens
      the PR and triggers Drew review per dispatch convention.

      **Size:** M. **Priority:** High (sibling to H1; both unblock the S1 cloister-yard
      productionization path).

      **Cross-references:**
      - R&D investigation 2026-06-11 (source of this ticket)
      - `.claude/docs/orchestration-overview.md` § "R&D lane" (harvest gate mandate)
      - ENTRY 2026-06-11-001 (ground pipeline harvest, sibling)
      - ENTRY 2026-06-11-003 (orch-docs harvest, sibling)
      - `.claude/docs/art-direction.md` (building visual direction; being committed in H3)
- created_at: 2026-06-11 (Priya, rnd-lane-convention task)
- attempts: 0

---

## ENTRY 2026-06-11-003

- op: create_task
- list_id: 901523123922
- payload:
    name: "docs(orch): harvest iso sprint docs — godot-headless-tooling.md, art-direction.md, pixellab-pipeline.md delta, CLAUDE.md index"
    priority: normal
    tags: [iso, harvest, docs]
    status: "to do"
    description: |
      **Source:** R&D investigation 2026-06-11. Iso sprint 2026-06-08..11 produced
      three uncommitted doc files + one modified-uncommitted file. This ticket lands
      them on `main` via an orch-authored PR with peer review per the auto-execute
      convention for orch-docs PRs.

      **Scope — files to commit:**
      - `.claude/docs/godot-headless-tooling.md` — new file (currently untracked):
        headless `--script` TileMap paint/re-save pattern, `--import` precondition,
        type-inference parse trap, cold-start noise guide
      - `.claude/docs/art-direction.md` — new file (currently untracked):
        Sponsor's inspiration board, visual north-star (fine multi-tone worn stone,
        human-scale landmarks, lush purposeful decoration, warm cohesive palette,
        small-player/big-alive-world), look-at-the-actual-images mandate
      - `.claude/docs/pixellab-pipeline.md` — modified-uncommitted: delta captures
        iso-specific generation learnings (canvas-size trap, quantize dupe-slot
        mitigation, doctrine-compliance strategies, `import_image` param trap, cost
        model additions from iso sprint)
      - `CLAUDE.md` — index pointer additions for the two new doc files
        (`godot-headless-tooling.md` and `art-direction.md` must appear in the
        Detailed Documentation index table)

      **Out of scope:** artifact files (ground pipeline → H1; building kit → H2).
      Do not bundle any `.gd`, `.tscn`, `.tres`, or asset files in this PR.

      **Acceptance criteria:**
      1. All four files above are committed to `main` via a PR with title
         `docs(orch): harvest iso sprint docs — headless tooling, art direction, pixellab delta (H3)`.
      2. PR body is an orch-authored harvest PR per auto-execute convention (memory
         `auto-execute-classes-without-sponsor-ack` — orch-docs PRs with peer reviewer
         do not require Sponsor ack).
      3. Peer reviewer: Devon (engine/harness surface; godot-headless-tooling.md is
         the primary new doc). Review must confirm: no factual errors in headless
         tooling doc relative to actual Godot 4.6 CLI behavior; pixellab-pipeline.md
         delta is additive-only (no deletions of prior content); CLAUDE.md index
         additions are in the right location.
      4. CI green before merge.

      **Out of scope (explicit):**
      - No code, scene, or asset changes
      - No Tess QA sign-off required (docs-only PR)
      - No Sponsor ack required per auto-execute-classes convention

      **Success test:** after merge, `cat .claude/docs/godot-headless-tooling.md`
      and `cat .claude/docs/art-direction.md` return non-empty content; CLAUDE.md
      index contains entries for both files with correct paths.

      **Owner:** orchestrator authors; Devon peer-reviews. Orchestrator dispatches
      as a conventional orch-authored PR.

      **Size:** S. **Priority:** Normal (doc debt; does not block productionization
      but should land before new headless work is dispatched so Devon has the
      correct reference doc).

      **Cross-references:**
      - R&D investigation 2026-06-11 (source of this ticket)
      - `.claude/docs/orchestration-overview.md` § "R&D lane" (harvest gate mandate)
      - ENTRY 2026-06-11-001, ENTRY 2026-06-11-002 (sibling harvest tickets)
      - memory `auto-execute-classes-without-sponsor-ack` (merge authorization)
- created_at: 2026-06-11 (Priya, rnd-lane-convention task)
- attempts: 0

---

## ENTRY 2026-06-11-004

- op: create_task
- list_id: 901523123922
- payload:
    name: "chore(docs): refresh team/RESUME.md to current M3 iso state"
    priority: normal
    tags: [docs, tech-debt]
    status: "to do"
    description: |
      **Source:** R&D investigation 2026-06-11. team/RESUME.md is stale — still
      describes M2 Week 3 (2026-05-15 era state). Current state is M3 Tier 3 with
      iso pivot in progress (post-PR #420 spatial pivot decision, PRs #421/#423
      on `main`).

      **Scope:**
      Update `team/RESUME.md` to reflect current reality. Minimum required sections:

      1. **Current milestone / wave.** M3 Tier 3 (iso pivot wave). Reference the
         2026-06-07 DECISIONS.md entry for the S1 cloister-yard pivot and the
         2026-06-11 R&D lane convention amendment.
      2. **Key PRs since last RESUME.md update.** At minimum: PR #409 (monk sprite
         rig), PR #413 (shooter rig), PR #421 (S1→assembler keystone), PR #423
         (iso cobble floor generator), PR #424 (S1 open cloister-yard first walkable
         slice), PR #425 (S1 yard ground composition). Derive from `git log` — do
         not invent PR numbers.
      3. **Open / in-flight work.** Harvest tickets H1–H4 (ENTRY 2026-06-11-001
         through 004) + any other open ClickUp items visible from the pending queue.
      4. **Spatial direction.** The open-world cloister-yard pivot (memory:
         `s1-cloister-yard-open-world-direction`); iso conversion (memory:
         `buildings-isometric-diablo2-style`); assembler path (PR #421/#423 baseline).
      5. **Next orchestrator actions.** What the next session needs to do first —
         flush ENTRY 2026-06-11-001 through 004 to ClickUp, dispatch H1/H2 harvest
         PRs, dispatch H3 orch-docs PR.

      **Acceptance criteria:**
      1. `team/RESUME.md` committed to `main` via a PR with title
         `chore(docs): refresh RESUME.md — M3 iso pivot state (H4)`.
      2. All PR numbers cited are verified from `git log` or `gh pr list` — not
         invented. No fabricated SHAs or ticket IDs.
      3. Sections 1-5 above are present and accurate as of the commit date.
      4. CI green before merge (docs-only; CI should be trivially green).

      **Out of scope (explicit):**
      - No code, scene, or asset changes
      - No other team/ files (DECISIONS.md stays Priya-batch-PR-only)

      **Success test:** `cat team/RESUME.md` returns content with "M3" and "iso"
      in it; last-modified date is current.

      **Owner:** Priya. This is a PL coordination artifact — Priya authors from
      verified `git log` + pending-queue evidence. No peer review required for a
      RESUME.md update (docs-only, Priya-authored coordination artifact per ROLES.md).
      Orchestrator merges after CI green.

      **Size:** S. **Priority:** Normal (hand-off doc; important for session
      continuity but does not block feature work).

      **Cross-references:**
      - R&D investigation 2026-06-11 (source of this ticket)
      - `team/ROLES.md` (Priya's coordination artifact ownership)
      - `.claude/docs/orchestration-overview.md` § "R&D lane" (context for why RESUME.md is stale)
- created_at: 2026-06-11 (Priya, rnd-lane-convention task)
- attempts: 0

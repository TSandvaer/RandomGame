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

## ENTRY 2026-05-23-032

- op: create_task
- list_id: 901523123922
- payload:
    name: "investigate(lint): class-definitions-order false-positive scope on Director pattern"
    priority: normal
    tags: [investigate, lint, week-stage2-followup]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdlint baseline reports 92 `class-definitions-order`
      findings across `scripts/` + `tests/`. Confirmed in PR #333 Self-Test
      Report local run: `CameraDirector.gd` lines 180/185/190/194/237/262
      flag `Definition out of order in global scope`.

      `gdlintrc` line 1-15 declares the rule's required ordering:
      tools → classnames → extends → docstrings → signals → enums → consts →
      staticvars → exports → pubvars → prvvars → onreadypubvars →
      onreadyprvvars → others.

      **Why investigate-first:** the Director-pattern autoloads
      (`AudioDirector` / `TimeScaleDirector` / `CameraDirector` /
      `DialogueController`) intentionally interleave signal declarations
      near the methods that emit them, and may have const/var blocks
      structured for cohesion (related groups together) rather than the
      strict gdlint ordering. A naive 92-violation sweep risks reformatting
      the Director shape that `.claude/docs/*-director*.md` documents and
      `.claude/docs/audio-architecture.md` / `camera-layer.md` /
      `time-scale-director.md` / `dialogue-system.md` reference.

      Authoring this as Stage-2 precursor BEFORE the bulk fix-pass ticket
      (ENTRY 033) so the team has a verdict on whether to sweep or
      exception.

      **Scope:**
      1. Run `gdlint scripts/audio/AudioDirector.gd
         scripts/camera/CameraDirector.gd
         scripts/combat/TimeScaleDirector.gd
         scripts/dialogue/DialogueController.gd` and capture the full
         finding list for these four files.
      2. For each finding, classify: (a) genuine ordering violation (e.g.
         an `export` placed after a method body — clearly wrong), or
         (b) intentional cohesion ordering (signal next to emitter, const
         block grouped with related vars) where gdlint's strict ordering
         would degrade readability.
      3. **Question to answer in PR body:** does the Director-pattern code
         hit case (a), case (b), or a mix? If pure (a) → ticket 033's
         `class-definitions-order` sweep proceeds as planned. If pure (b)
         → file `disable: [class-definitions-order]` in `gdlintrc` line 21
         (currently `disable: []`) + ticket 033 sweep is skipped + the 92
         findings drop from the baseline. If mixed → recommend a partial
         disable scope (e.g. per-file `# gdlint:disable=class-definitions-order`
         pragmas on the four Director files only) + ticket 033 sweep
         proceeds on the remaining ~70 non-Director findings.

      **Out-of-scope:**
      - Bulk fixing the 92 findings (ticket 033's job).
      - Modifying gdlint rule definitions (we accept the rule as configured;
        scope is whether to disable globally vs per-file vs not at all).
      - Investigating other lint rule classes (handled by sibling
        investigation ticket ENTRY 033 / fix tickets ENTRY 034-037).
      - Editing the Director source files (the investigation reports a
        verdict; the fix ticket — if any — does the edit).

      **Acceptance (Done):**
      - PR opens with `lint-reports/director-class-order-finding-classification.md`
        listing every `class-definitions-order` finding in the four Director
        files, classified case (a) / (b) / mixed-rationale.
      - PR body answers the question: "does gdlint's
        class-definitions-order rule correctly handle the Director-pattern
        autoload shape?" with verdict YES / NO / MIXED + 1-paragraph
        rationale.
      - If NO or MIXED → PR includes the `gdlintrc` disable edit (global
        or per-file scope, whichever the verdict supports) AND updates
        ticket 033 (ENTRY 033 → after flush, real ticket ID) acceptance to
        reflect the post-disable finding count.
      - If YES → PR includes a one-line `lint-reports/director-class-order-finding-classification.md`
        note stating "no disable needed; ticket 033 sweep proceeds as
        baselined" and closes with no `gdlintrc` change.
      - Paired test / CI green: not required (the lint surface IS the test
        surface).

      **Owner:** Devon (engine-side; owns the Director files).
      **Size:** S (one file pass + one verdict write-up).
      **Priority:** P2 (blocks ticket 033 sweep sequencing; not user-facing).
      **Dependencies:** none (PR #333 already merged); blocks ticket 033.

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdlint baseline + 92-finding
        figure
      - `gdlintrc` lines 1-15 — class-definitions-order rule order; line
        21 — `disable: []` (current state)
      - `.claude/docs/audio-architecture.md` — `AudioDirector` topology
      - `.claude/docs/camera-layer.md` — `CameraDirector` topology
      - `.claude/docs/time-scale-director.md` — `TimeScaleDirector` topology
      - `.claude/docs/dialogue-system.md` — `DialogueController` topology
      - Sibling Stage-2 investigation: ENTRY 033 (`duplicated-load` false-
        positive scope on HTML5 cache warmup)
      - Sibling Stage-2 fix: ENTRY 034 (class-definitions-order sweep —
        blocked on this investigation's verdict)

      **Files in play:**
      - `gdlintrc` (read-only investigation; possibly edit `disable:` list
        if verdict is NO or MIXED)
      - `scripts/audio/AudioDirector.gd`
      - `scripts/camera/CameraDirector.gd`
      - `scripts/combat/TimeScaleDirector.gd`
      - `scripts/dialogue/DialogueController.gd`
      - NEW: `lint-reports/director-class-order-finding-classification.md`
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-033

- op: create_task
- list_id: 901523123922
- payload:
    name: "investigate(lint): duplicated-load false-positive scope on HTML5 cache warmup"
    priority: normal
    tags: [investigate, lint, week-stage2-followup, html5]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdlint baseline reports 58 `duplicated-load` findings
      across `scripts/` + `tests/`. `gdlintrc` line 22 enables the rule
      (`duplicated-load: null`).

      **Why investigate-first:** there may exist an intentional HTML5
      ResourceCache warmup idiom — repeated `preload(...)` calls in the
      same script to prime the resource cache during boot, mitigating the
      `gl_compatibility` cold-load hitch that `.claude/docs/html5-export.md`
      § "Service-worker cache trap" documents. gdlint's `duplicated-load`
      rule fires on any repeated `load`/`preload` of the same path
      regardless of intent — if the warmup idiom is present and load-
      bearing, a naive sweep collapsing the duplicates would silently
      regress HTML5 boot perf.

      Authoring this as Stage-2 precursor BEFORE the bulk fix-pass ticket
      (ENTRY 035) so the team has a verdict on whether to sweep or
      exception.

      **Scope:**
      1. Run `gdlint scripts/ tests/ 2>&1 | grep duplicated-load` and
         capture the full 58-finding list with file:line paths.
      2. For each finding, classify: (a) genuine duplicate that should
         collapse to a top-of-file `const Foo := preload("res://...")`
         pattern (the gdlint rule's intent), or (b) intentional warmup-
         preload idiom where the duplicate IS the feature (load-bearing
         for HTML5 cache warmup, doctrine-locked sprite preload sequences,
         etc.).
      3. **Question to answer in PR body:** does gdlint's duplicated-load
         rule correctly handle the intentional HTML5 ResourceCache
         `preload(...)` warmup idiom (if any exists)? If pure (a) → ticket
         035's sweep proceeds. If pure (b) → file `disable:
         [duplicated-load]` in `gdlintrc` line 21 + ticket 035 sweep
         skipped + 58 findings drop from baseline. If mixed → per-call
         `# gdlint:disable=duplicated-load` pragma at the warmup site(s)
         + ticket 035 sweep proceeds on the remaining findings.
      4. **Empirical verification:** if any warmup-idiom site exists, run
         a release-build of one of the affected scenes BEFORE and AFTER
         a test collapse + measure boot-time `[BuildInfo]` → first-room-
         render latency. If no measurable difference → collapse is safe;
         the warmup is a no-op. If measurable difference → preserve the
         duplicate, file the disable.

      **Out-of-scope:**
      - Bulk fixing the 58 findings (ticket 035's job).
      - Investigating other lint rule classes (sibling tickets).
      - Modifying gdlint rule definitions; scope is disable-vs-not.
      - HTML5 cache architecture changes (we work with the current
        runtime; the rule's verdict respects whatever idiom is currently
        in use).

      **Acceptance (Done):**
      - PR opens with `lint-reports/duplicated-load-finding-classification.md`
        listing every finding classified case (a) genuine-duplicate / (b)
        warmup-idiom / mixed-rationale.
      - PR body answers the question: "does gdlint's duplicated-load rule
        correctly handle the intentional HTML5 ResourceCache `preload(...)`
        warmup idiom?" with verdict YES / NO / MIXED / NO-WARMUP-EXISTS +
        1-paragraph rationale.
      - If any warmup-idiom site is found, PR body includes the
        before/after release-build boot-time measurement supporting
        preserve-vs-collapse.
      - If NO or MIXED → PR includes the `gdlintrc` disable edit (global
        or per-file/per-line scope) AND updates ticket 035 (ENTRY 035 →
        after flush, real ticket ID) acceptance to reflect the post-
        disable finding count.
      - If YES or NO-WARMUP-EXISTS → PR includes a one-line note +
        closes with no `gdlintrc` change.
      - Paired test / CI green: not required (lint surface IS test
        surface; empirical measurement is the boot-time delta if any).

      **Owner:** Devon (engine-side; owns the resource-loading paths).
      **Size:** S (one finding-classification pass + optional one
      release-build measurement).
      **Priority:** P2 (blocks ticket 035 sweep sequencing; HTML5 boot
      perf risk if rule sweep collapses warmup).
      **Dependencies:** none (PR #333 already merged); blocks ticket 035.

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdlint baseline + 58-finding
        figure
      - `gdlintrc` line 22 — `duplicated-load: null` (enabled); line 21
        — `disable: []` (current state)
      - `.claude/docs/html5-export.md` § "Service-worker cache trap" —
        canonical HTML5 cold-load concern that the warmup idiom (if any)
        would address
      - Sibling Stage-2 investigation: ENTRY 032 (class-definitions-order
        false-positive scope on Director pattern)
      - Sibling Stage-2 fix: ENTRY 035 (duplicated-load sweep — blocked
        on this investigation's verdict)

      **Files in play:**
      - `gdlintrc` (read; possibly edit `disable:` list)
      - `scripts/` (read-only investigation; per-site classification)
      - NEW: `lint-reports/duplicated-load-finding-classification.md`
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-034

- op: create_task
- list_id: 901523123922
- payload:
    name: "fix(lint): max-line-length sweep (~175 findings)"
    priority: normal
    tags: [lint, week-stage2-followup]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdlint baseline reports ~175 `max-line-length`
      findings across `scripts/` + `tests/`. Confirmed in PR #333 Self-
      Test Report local run: top finding category by volume (45% of
      total 387 findings).

      `gdlintrc` line 36 sets `max-line-length: 100`. Most violations
      are doc-comment paragraphs + long string formats + dense
      function signatures.

      **Why now:** smallest-blast-radius first, per PR #333's suggested
      sequencing. Mechanical reformat candidate — most lines can be
      collapsed via wrapping comments, splitting string concatenations,
      or splitting argument lists across multiple lines without semantic
      change.

      **Scope:**
      1. Run `gdlint scripts/ tests/ 2>&1 | grep max-line-length` and
         capture the full ~175-finding list, sorted by file.
      2. For each file with >5 findings, fix in-batch (most efficient
         diff review). For files with 1-5 findings, fix as encountered.
      3. **Single-PR vs split-by-directory:** recommend SINGLE-PR since
         the diff is mechanical (line-wrap only, zero semantic change).
         Split only if review burden exceeds 500 lines of diff at PR
         time. Devon's call at execution time based on local diff size.
      4. Common wrap strategies:
         - Long string literals: split at logical boundaries with `+`
           concatenation OR migrate to multi-line `"""..."""` if
           appropriate.
         - Long function signatures: split arguments across lines with
           hanging indent.
         - Long expressions: extract intermediate variable OR wrap at
           operator.
         - Long doc comments: rewrap at 100 chars.
      5. Verify each file with `gdlint <file>` post-fix; finding count
         must drop to zero on that file (or to a documented residual
         where 100-char cap is genuinely impractical — e.g. a long URL
         in a comment).
      6. CI green required: GUT tests must still pass (no semantic
         drift); Playwright suite must still pass.

      **Out-of-scope:**
      - Other lint rule classes (sibling tickets ENTRY 034 / 035 / 037).
      - Semantic refactoring (renaming, restructuring) — pure line-wrap
        only.
      - Editing `gdlintrc` `max-line-length: 100` to a higher value
        (rule is fixed; we adapt).
      - Documenting a "max-line-length residual" exception list (if any
        line is genuinely unfixable, leave one `# gdlint:disable=max-
        line-length` pragma at that line site; do not add to global
        disable).

      **Acceptance (Done):**
      - PR opens (likely SINGLE; split iff diff >500 lines).
      - Self-Test Report comment includes BEFORE/AFTER `gdlint scripts/
        tests/ 2>&1 | grep -c max-line-length` count; AFTER count must
        be 0 OR documented residuals with `# gdlint:disable=max-line-
        length` pragmas.
      - CI green (GUT + Playwright auto-fired on PR push per `.claude/docs/
        test-conventions.md` § "Playwright e2e CI auto-triggers").
      - Tess review APPROVE (mechanical fix; Tess-cant-self-QA peer
        review pattern does not apply because Tess is the reviewer
        here, not the author).
      - Inline `[lint-reports]` artifact on the PR's CI run shows
        post-fix baseline drops by ~175 findings.

      **Owner:** Devon (cleanest run since most violations live in
      `scripts/`; engine-side ownership).
      **Size:** M-L (depending on single-PR vs split-by-directory).
      **Priority:** P2 (CI hygiene; no user-facing impact).
      **Dependencies:** none (PR #333 already merged); independent of
      investigations ENTRY 032 / 033 and fix tickets ENTRY 035 / 036 /
      037 (`max-line-length` is orthogonal to the other rule classes).

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdlint baseline + 175-
        finding figure
      - `gdlintrc` line 36 — `max-line-length: 100`
      - `lint-reports/gdlint.txt` (artifact on PR #333's CI run) — full
        baseline finding list
      - Sibling Stage-2 fix tickets: ENTRY 035 (duplicated-load), ENTRY
        036 (class-definitions-order — blocked on ENTRY 032), ENTRY 037
        (max-public-methods), ENTRY 038 (gdformat reformat).

      **Files in play:**
      - `gdlintrc` (read-only)
      - `scripts/**/*.gd` (touched per finding location)
      - `tests/**/*.gd` (touched per finding location)
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-035

- op: create_task
- list_id: 901523123922
- payload:
    name: "fix(lint): duplicated-load sweep (~58 findings)"
    priority: normal
    tags: [lint, week-stage2-followup]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdlint baseline reports ~58 `duplicated-load` findings
      across `scripts/` + `tests/`. PR #333 body suggests "replace with
      a const at top of file" as the mechanical fix shape.

      **BLOCKED ON investigation ticket ENTRY 033** (`investigate(lint):
      duplicated-load false-positive scope on HTML5 cache warmup`). The
      sweep proceeds ONLY after ENTRY 033 reports verdict YES (rule
      handles warmup correctly) OR NO-WARMUP-EXISTS (no warmup idiom in
      codebase). If ENTRY 033 reports NO or MIXED, this ticket scope
      shrinks to the (a) genuine-duplicate findings only OR is closed
      with "rule disabled in gdlintrc, sweep no longer needed" status.

      **Why size S:** mechanical extraction of `preload("res://...")`
      calls into top-of-file `const Foo := preload(...)` decls; same
      identifier used at the prior call sites. Most files have 1-3
      findings; trivial per-site fix.

      **Scope (assuming ENTRY 033 verdict allows sweep):**
      1. Re-run `gdlint scripts/ tests/ 2>&1 | grep duplicated-load`
         post-investigation to get the trimmed finding list.
      2. For each finding, hoist the duplicated `preload(...)` to a
         top-of-file `const` declaration; replace all call sites with
         the const identifier.
      3. Verify with `gdlint <file>` post-fix; finding count drops to
         zero on that file.
      4. Each affected `<file>.gd` should have a clean `const`-grouped
         preload block near top-of-file (after extends + class_name +
         signals + docstring per `gdlintrc` line 1-15 ordering).
      5. CI green required: GUT + Playwright tests must still pass.

      **Out-of-scope:**
      - Findings classified (b) warmup-idiom by ENTRY 033 (skip those
        sites; they keep their duplicate-preload shape).
      - Other lint rule classes.
      - Editing `gdlintrc` (handled in ENTRY 033 if any disable is
        needed).
      - Semantic refactoring of the loaded resources themselves.

      **Acceptance (Done):**
      - PR opens after ENTRY 033 merges (ENTRY 033 PR # cited in this
        PR's body as dependency).
      - Self-Test Report comment includes BEFORE/AFTER
        `gdlint scripts/ tests/ 2>&1 | grep -c duplicated-load` count;
        AFTER count drops to zero OR to the (b) warmup-idiom-only
        residual ENTRY 033 documented.
      - CI green (GUT + Playwright auto-fired).
      - Tess review APPROVE.
      - Inline `[lint-reports]` artifact on the PR's CI run shows
        post-fix baseline drops by ~58 findings (or trimmed count).

      **Owner:** Devon (engine-side resource loading).
      **Size:** S (after investigation; mechanical extraction).
      **Priority:** P2 (CI hygiene).
      **Dependencies:** **HARD BLOCK on ENTRY 033 merge** (real ticket ID
      after flush). Do not dispatch this ticket until ENTRY 033 verdict is
      published.

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdlint baseline + 58-finding
        figure
      - `gdlintrc` line 22 — `duplicated-load: null` (enabled)
      - Dependency: ENTRY 033 investigation
      - `.claude/docs/html5-export.md` § "Service-worker cache trap" —
        HTML5 boot perf context investigation respects

      **Files in play:**
      - `gdlintrc` (read-only; updated only by ENTRY 033 if disable
        needed)
      - `scripts/**/*.gd` (touched per finding location)
      - `tests/**/*.gd` (touched per finding location, if any)
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-036

- op: create_task
- list_id: 901523123922
- payload:
    name: "fix(lint): class-definitions-order sweep (~92 findings)"
    priority: normal
    tags: [lint, week-stage2-followup]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdlint baseline reports ~92 `class-definitions-order`
      findings across `scripts/` + `tests/`. `gdlintrc` line 1-15
      enumerates the rule's required ordering.

      **BLOCKED ON investigation ticket ENTRY 032** (`investigate(lint):
      class-definitions-order false-positive scope on Director pattern`).
      The sweep proceeds ONLY after ENTRY 032 reports verdict YES (rule
      handles Director shape correctly) OR routes the Director files to
      per-file disable + non-Director sweep continues. If ENTRY 032
      reports NO with global disable → this ticket is closed with "rule
      globally disabled, sweep no longer needed" status.

      **Why size M (post-investigation):** reorders within each affected
      file are mechanical (cut/paste const block, signal block, etc.)
      but careful diff review needed to ensure no semantic drift
      (e.g. an `onready` var that depended on a sibling const must not
      be reordered above the const's definition).

      **Scope (assuming ENTRY 032 verdict allows sweep):**
      1. Re-run `gdlint scripts/ tests/ 2>&1 | grep class-definitions-
         order` post-investigation to get the trimmed finding list
         (excluding any Director files / sites ENTRY 032 routed to
         per-file disable).
      2. For each finding, reorder the offending block to match
         `gdlintrc` line 1-15 ordering: tools → classnames → extends →
         docstrings → signals → enums → consts → staticvars → exports →
         pubvars → prvvars → onreadypubvars → onreadyprvvars → others.
      3. Verify with `gdlint <file>` post-fix; finding count drops to
         zero on that file.
      4. Semantic check per-file: ensure no `onready` / `@onready` var
         was reordered above its initializer dependency (would crash on
         instantiation). Run paired GUT tests for affected scenes.
      5. CI green required: GUT + Playwright tests must still pass.

      **Out-of-scope:**
      - Files / sites ENTRY 032 classified (b) intentional-cohesion (skip
        those; they keep their original ordering).
      - Other lint rule classes.
      - Editing `gdlintrc` rule order (handled in ENTRY 032 if any
        disable is needed).
      - Semantic refactoring of the affected classes.

      **Acceptance (Done):**
      - PR opens after ENTRY 032 merges (ENTRY 032 PR # cited in this
        PR's body as dependency).
      - Self-Test Report comment includes BEFORE/AFTER
        `gdlint scripts/ tests/ 2>&1 | grep -c class-definitions-order`
        count; AFTER count drops to zero OR to the (b)-classified-only
        residual ENTRY 032 documented.
      - Semantic check report in Self-Test Report: every affected
        scene's GUT smoke test confirms no `onready` initialization
        regression.
      - CI green (GUT + Playwright auto-fired).
      - Tess review APPROVE.

      **Owner:** Devon (engine-side; reorders touch files Devon has
      deepest authority on).
      **Size:** M (mechanical reorder + semantic diff review).
      **Priority:** P3 (CI hygiene; sequenced after ENTRY 032 +
      ENTRIES 034/035).
      **Dependencies:** **HARD BLOCK on ENTRY 032 merge**.

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdlint baseline + 92-finding
        figure
      - `gdlintrc` line 1-15 — required ordering
      - Dependency: ENTRY 032 investigation
      - `.claude/docs/audio-architecture.md` / `camera-layer.md` /
        `time-scale-director.md` / `dialogue-system.md` — Director-
        pattern docs that ENTRY 032 may exempt

      **Files in play:**
      - `gdlintrc` (read-only; updated only by ENTRY 032 if disable
        needed)
      - `scripts/**/*.gd` (touched per finding location, minus any
        Director files ENTRY 032 routes to per-file exemption)
      - `tests/**/*.gd` (touched per finding location)
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-037

- op: create_task
- list_id: 901523123922
- payload:
    name: "fix(lint): max-public-methods sweep (~23 findings)"
    priority: normal
    tags: [lint, week-stage2-followup]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdlint baseline reports ~23 `max-public-methods`
      findings across `scripts/` + `tests/`. `gdlintrc` line 37 sets
      `max-public-methods: 20` — any class with >20 public (non-`_`-
      prefixed) methods triggers.

      **Why sequence LAST:** PR #333 body explicitly flagged this — "may
      need genuine refactor (AudioDirector, CameraDirector, InventoryPanel,
      etc.) — defer until last; not all 23 will be cleanly fixable."
      Director-pattern autoloads accumulate API surface by design — they
      ARE the central owner of a shared resource per
      `.claude/docs/{audio-architecture,camera-layer,time-scale-director}.md`
      and expose APIs for many call sites. Sweeping them with naive
      method-splitting risks degrading the Director topology.

      Sequence dependency: this ticket runs AFTER ENTRIES 034/035/036/038
      so the other ~360 findings clear first and the residual is
      bounded to the genuine architectural surface.

      **Scope:**
      1. Run `gdlint scripts/ tests/ 2>&1 | grep max-public-methods` and
         capture the ~23-file list with method counts.
      2. For each affected class, classify:
         - **(a) Genuine bloat** — class has accumulated unrelated APIs
           that should split into a sibling class (rare).
         - **(b) Director-pattern surface** — class is an autoload central
           owner; high method count IS the design. File `# gdlint:disable=
           max-public-methods` at top of file with one-line rationale
           comment.
         - **(c) UI panel surface** — `InventoryPanel` / `DialoguePanel` /
           similar; high method count reflects panel API breadth. Same
           treatment as (b): per-file disable + rationale.
         - **(d) Refactor candidate** — class has cohesion-breaking method
           count; split into helper class. Rare; only when clear
           cohesion break exists.
      3. For each class:
         - (a)/(d) → split into helper class with paired test migration.
         - (b)/(c) → file the per-file disable pragma + rationale comment.
      4. Verify with `gdlint scripts/ tests/ 2>&1 | grep -c
         max-public-methods` post-fix; finding count drops to zero (all
         residuals carry pragmas).
      5. CI green required: GUT + Playwright tests must still pass; any
         refactor (a)/(d) cases require paired GUT tests covering the
         split surface.

      **Out-of-scope:**
      - Reverting Director pattern decisions; rationale comments respect
        the existing architecture.
      - Editing `gdlintrc` `max-public-methods: 20` to a higher value
        (we want the rule active; we use per-file disable for legitimate
        exceptions).
      - Other lint rule classes.

      **Acceptance (Done):**
      - PR opens AFTER ENTRIES 034/035/036/038 merge (sequence-last per
        PR #333 body recommendation).
      - Self-Test Report comment lists each of the ~23 affected classes
        with classification (a)/(b)/(c)/(d) + treatment applied.
      - Self-Test Report includes BEFORE/AFTER
        `gdlint scripts/ tests/ 2>&1 | grep -c max-public-methods`
        count; AFTER must be zero.
      - For any (a)/(d) refactor cases: paired GUT tests exist covering
        the helper-class split + the original class's reduced surface.
      - CI green (GUT + Playwright auto-fired).
      - Tess review APPROVE.

      **Owner:** Devon (engine-side; touches Director autoloads + UI
      panel classes).
      **Size:** M (mechanical disable pragmas + occasional refactor).
      **Priority:** P3 (CI hygiene; sequenced LAST).
      **Dependencies:** sequence-after ENTRIES 034/035/036/038 (soft;
      not hard-blocked, but reviewer cognitive load is lower when this
      runs with the other sweeps already merged).

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdlint baseline + 23-finding
        figure + "may need genuine refactor — defer until last"
        recommendation
      - `gdlintrc` line 37 — `max-public-methods: 20`
      - `.claude/docs/audio-architecture.md` / `camera-layer.md` /
        `time-scale-director.md` / `dialogue-system.md` — Director-
        pattern justification for per-file disable

      **Files in play:**
      - `gdlintrc` (read-only)
      - `scripts/audio/AudioDirector.gd`
      - `scripts/camera/CameraDirector.gd`
      - `scripts/combat/TimeScaleDirector.gd`
      - `scripts/dialogue/DialogueController.gd`
      - `scripts/ui/InventoryPanel.gd`
      - `scripts/ui/DialoguePanel.gd`
      - Other classes per gdlint finding list (TBD at execution)
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-038

- op: create_task
- list_id: 901523123922
- payload:
    name: "chore(lint): gdformat reformat sweep (~179 files)"
    priority: normal
    tags: [lint, week-stage2-followup, chore]
    status: to do
    description: |
      **Source:** Stage-2 follow-up to PR #333 (`ci(static-analysis): add
      gdlint + gdformat warnings-only step`, merge commit `0758550`,
      2026-05-23). gdformat baseline reports ~179 files would be
      reformatted across `scripts/` + `tests/` (18 files unchanged).

      **Why now:** mechanical, zero logic changes — `gdformat` rewrites
      whitespace, indentation, line breaks, quote style per gdtoolkit's
      canonical formatter. PR #333 body recommends "isolated PR with
      manual diff review for any semantic surprises" — the diff is large
      but mechanical; single-PR ships clean.

      **Why single-PR (not split):** gdformat's behavior is deterministic
      and idempotent — splitting into per-directory PRs adds review
      burden without reducing risk. Single-PR diff is also the easiest
      for reviewer to skim for the few sites where gdformat may surprise
      (e.g. a deliberate multi-line string literal that gdformat collapses).

      **Scope:**
      1. Run `gdformat scripts/ tests/` (no `--check`; actually applies
         the reformat).
      2. Stage all changes via `git add scripts/ tests/`.
      3. Spot-check the diff for surprise reformats:
         - Multi-line strings that gdformat may have collapsed unwisely.
         - Comment alignment changes that obscure intent.
         - Trailing-comma additions/removals.
      4. For any surprise, document in PR body (gdformat decision +
         whether it's acceptable). If a surprise is unacceptable, mark
         that specific line/block with a `# gdformat:off ... # gdformat:on`
         pragma to preserve original formatting (rare; use sparingly).
      5. Verify with `gdformat --check scripts/ tests/` post-fix; the
         "would reformat" count must drop to zero.
      6. CI green required: GUT + Playwright tests must still pass
         (semantic-zero change; should pass trivially).

      **Out-of-scope:**
      - Lint rule fixes (sibling tickets ENTRY 034/035/036/037).
      - Editing `gdlintrc` (gdformat config isn't in gdlintrc; default
        gdformat config used).
      - Semantic refactoring of any kind.

      **Acceptance (Done):**
      - SINGLE PR opens with `gdformat scripts/ tests/` output (no
        `--check`).
      - Self-Test Report comment includes BEFORE/AFTER `gdformat --check
        scripts/ tests/ 2>&1 | grep -c "^would reformat"` count; AFTER
        must be 0.
      - PR body documents any surprise reformats + treatment.
      - CI green (GUT + Playwright auto-fired).
      - Tess review APPROVE.

      **Owner:** Devon (best done in one wave for clean diff; engine-
      side coordination).
      **Size:** L (large mechanical diff; ~179 files; review burden is
      the cost driver, not authoring).
      **Priority:** P2 (CI hygiene; mechanical so should ship clean).
      **Dependencies:** none direct; recommended to land AFTER ENTRIES
      034/035 to reduce diff-overlap during review (gdformat may touch
      same lines as max-line-length fixes). NOT hard-blocked — Devon's
      call at execution time.

      **Cross-references:**
      - PR #333 (merge commit `0758550`) — gdformat baseline + 179-file
        figure
      - `lint-reports/gdformat.txt` (artifact on PR #333's CI run) —
        full baseline reformat list

      **Files in play:**
      - `scripts/**/*.gd` (~ majority touched)
      - `tests/**/*.gd` (~ majority touched)
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)

---

## ENTRY 2026-05-23-039

- op: create_task
- list_id: 901523123922
- payload:
    name: "fix(docs): floor_assembler.gd derive_zone_seed docstring 3-arg → 2-arg correction"
    priority: normal
    tags: [docs, week-stage2-followup, procgen]
    status: to do
    description: |
      **Source:** Drew's PR #332 review (file
      `team/drew-dev/pr332-approve.md`, peer review for
      `.claude/docs/procgen-pipeline.md` capture). Drew verified the
      docstring at `scripts/world/floor_assembler.gd` (M3 Tier 3 W1
      spike, merge commit `7bfae0f` for the doc capture PR;
      `e900222` for the upstream spike branch) has stale signature
      example:

      > "FloorAssembler.gd's own docstring at lines 30-31 has a stale
      > 3-arg example, but procgen-pipeline.md correctly documents the
      > actual 2-arg signature — the doc is MORE accurate than the
      > source's own docstring."

      Source docstring at lines 30-31 references the OLD 3-arg shape
      `derive_zone_seed(world_seed, stratum_seed, zone_id)`. Actual
      signature post-spike is 2-arg `derive_zone_seed(stratum_seed,
      zone_id)` (verified by Drew at FloorAssembler.gd line 244 in
      his PR #332 review).

      **Note on path:** the brief cites `scripts/world/floor_assembler.gd`
      but Drew's verified path is `scripts/levels/FloorAssembler.gd`.
      Use Drew's verified path — Drew's PR #332 review reads the file
      from main HEAD post-PR-#328 merge. (`.claude/docs/procgen-pipeline.md`
      also references `scripts/levels/FloorAssembler.gd`.) Confirm
      path at execution; the docstring fix is the same regardless.

      **Scope:**
      1. Open `scripts/levels/FloorAssembler.gd` (Drew's verified path;
         confirm at execution).
      2. Edit lines 30-31 (or whatever range the stale 3-arg example
         occupies) to match the actual 2-arg signature: `derive_zone_seed(
         stratum_seed, zone_id) -> int`.
      3. Verify the docstring example matches the canonical seed
         cascade in `.claude/docs/procgen-pipeline.md` § "Seed-cascade
         contract":
         ```
         stratum_seed = FloorAssembler.derive_stratum_seed(world_seed,
                                                            stratum_id)
         zone_seed = FloorAssembler.derive_zone_seed(stratum_seed,
                                                     zone_id)
         ```
      4. CI green required (no logic change; GUT tests for
         `test_derive_zone_seed_is_deterministic` etc. should all still
         pass).

      **Out-of-scope:**
      - Changing the actual function signature (the function is correct;
        only the docstring is stale).
      - Other docstring fixes in the same file (file may have more
        stale comments; if found, file a sibling ticket — keep this
        one trivial-S).
      - Updating `.claude/docs/procgen-pipeline.md` (already correct
        per Drew's review).

      **Acceptance (Done):**
      - PR opens with single-file edit to
        `scripts/levels/FloorAssembler.gd`.
      - Diff is ≤ ~15 lines (docstring correction only).
      - Self-Test Report comment confirms: (a) docstring lines now show
        2-arg signature; (b) cross-check against
        `.claude/docs/procgen-pipeline.md` § "Seed-cascade contract"
        shows alignment; (c) `tests/test_floor_assembler.gd` GUT smoke
        passes (no functional change).
      - CI green.
      - Tess review APPROVE (trivial; doc-only).

      **Owner:** Drew (game-side spike author — already familiar with the
      file) OR Devon (engine-side; either is appropriate). Recommend
      Drew first chance; Devon if Drew is in flight on other procgen
      work.
      **Size:** S (single-file docstring edit; ~15-line diff max).
      **Priority:** P3 (doc hygiene; no user-facing impact; no functional
      risk).
      **Dependencies:** none.

      **Cross-references:**
      - Drew's PR #332 review file `team/drew-dev/pr332-approve.md`
        lines 8-9 — the original "minor non-blocking" callout
      - PR #332 (merge commit `7bfae0f`) — procgen-pipeline.md capture
      - PR #328 (upstream procgen spike merge) — the function whose
        docstring this fixes
      - `.claude/docs/procgen-pipeline.md` § "Seed-cascade contract" —
        canonical 2-arg signature reference
      - `scripts/levels/FloorAssembler.gd` line 244 — actual function
        site (verified by Drew at PR #332 review time)

      **Files in play:**
      - `scripts/levels/FloorAssembler.gd` (docstring edit lines 30-31
        or thereabouts)
- created_at: 2026-05-23T (Priya orch-authored Stage-2 follow-up sweep)
- attempts: 0 (deferred filing — orchestrator to flush)


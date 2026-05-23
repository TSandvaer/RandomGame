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

## ENTRY 2026-05-23-029

- op: create_task
- list_id: 901523123922
- payload:
    name: "qa(playwright): quarantine triage — re-enable 6 specs with N≥8 empirical verification"
    priority: high
    tags: [process, follow-up, week-N, qa]
    status: "to do"
    description: |
      **Filed by:** Priya (bundled process PR — placeholder ticket `86c9y00m1`
      from PR #330 replacement).

      **Context.** PR #330 (Tess, merged 2026-05-23) quarantined 6 persistent
      Playwright failures via `test.skip(...)` to restore main to green:
      - `tests/playwright/specs/pr291-aftershock-visual.spec.ts:29`
      - `tests/playwright/specs/pr291-boss-slam-diag.spec.ts:24`
      - `tests/playwright/specs/pr300-wake-anim-visual.spec.ts:45`
      - `tests/playwright/specs/t16-cinematic-climax.spec.ts:42`
      - `tests/playwright/specs/audio-bus-boot-smoke.spec.ts:37`
      - `tests/playwright/specs/soak-narrative-regression.spec.ts:264`

      Failure clusters per PR #330 body:
      - **Cluster A** (3 specs): boss-wake-IDLE 10000ms timeout class; cite
        `html5-export.md` § "Playwright headless ≠ real-browser perception".
      - **Cluster B** (1 spec): USER WARNING boot line; needs `WarningBus.warn`
        / `expectedUserWarnings` allow-list re-enable path.
      - **Cluster C** (2 specs): promoted from PR #322 documented flake
        (`86c9xy0mk`) — retry no longer reliably green.

      **Scope.** Triage each of the 6 quarantined specs per its cluster;
      author the re-enable fix; verify the spec passes **N≥8 consecutive runs
      against main HEAD** before removing `test.skip()` (sample-size discipline
      pinned in `tests/playwright/README.md` § "Quarantined specs"). One
      re-enable PR per spec OR one PR per cluster — author's call.

      **Re-enable PR requirements:**
      - Cite this ticket in the PR body.
      - Cite the 8-run sweep evidence (run-id URLs) in the Self-Test Report.
      - The `test.skip(...)` deletion + the citation-comment-header deletion
        must be in the same diff.

      **Owners.** Tess (clusters A + B; harness debt). Drew (cluster C if
      promoted-flake roots are game-side; Devon if engine-side). Routing per
      `tess-cant-self-qa-peer-review`.

      **Cross-references:**
      - PR #330 body — full cluster breakdown + run-id sampling
      - `tests/playwright/README.md` § "Quarantined specs (do not bisect;
        pending triage)" — N≥8 re-enable discipline
      - Memory `triage-from-authoritative-summary-not-display.md` —
        cite-tool for verifying each re-enable's green count

      **Replaces placeholder `86c9y00m1`.** After this ticket is created, sed-
      replace all 7 placeholder references (6 specs + README L297/L314/L316)
      to the new ticket ID. If the new ID equals the placeholder, no replace.

- created_at: 2026-05-23T (Priya bundled-process PR)
- attempts: 0 (queued; MCP not enumerated in sub-agent tool surface — orch flushes)

---

## ENTRY 2026-05-23-030

- op: create_task
- list_id: 901523123922
- payload:
    name: "bug(qa): AC2 harness walk-latency — 1.6s key-down → walk gap after Room 02 load"
    priority: normal
    tags: [bug, qa, follow-up]
    status: "to do"
    description: |
      **Filed by:** Priya (bundled process PR follow-up from PR #331 retro).

      **Symptom.** When `ac2-first-kill.spec.ts` issues a 100ms WASD chord
      after Room 02 load, the player walks only ~42px (expected ~100px+).
      Trace shows a **1.6s gap** between the harness key-down event and the
      `Player.pos | state=walk` console emit.

      **Context.** PR #331 (Drew, merged 2026-05-23) shipped a harness-side
      workaround — aim Hitbox from live Grunt position rather than relying on
      pre-walk player coordinates. The merge unblocked AC2 mainline, but the
      underlying engine-vs-harness latency puzzle remains.

      **Hypotheses (engine-side investigation needed):**
      1. **Canvas-focus class** — Playwright keyboard events may land before
         the iframe canvas claims focus on cold-load. First few keys absorbed
         by the document root, not the game.
      2. **Respawn-frame-absorbs-input** — Room transition's first physics
         frame after `scene_changed` may discard input as part of the
         transition state-machine.
      3. **Audio-context user-gesture gate** — HTML5 `gl_compatibility`
         AudioContext requires a user gesture to unlock; first WASD chord may
         be consumed by the gate.
      4. **WebGL2 context-loss / context-restore race** — `gl_compatibility`
         pipeline may hitch on first frame post-room-load.

      **Investigation scope (Devon, engine):**
      - Add a `[input-trace]` shim that logs every key event the engine
        receives from the moment a new scene loads.
      - Run AC2 spec under the trace; correlate Playwright dispatch timestamp
        against engine-side receive timestamp.
      - Identify which of the 4 hypotheses (or a 5th) accounts for the gap.
      - Recommend either an engine fix (preferred — restores parity with real
        users) OR a documented harness convention (last-resort — pins the
        workaround).

      **Why this matters.** Drew's PR #331 harness fix unblocks the immediate
      merge but doesn't restore "WASD-after-room-load works as a player would
      expect." Real users may experience the same 1.6s walk-latency after
      every room transition — if so, this is a bug that hides behind
      muscle-memory ("I press WASD twice to start moving").

      **Cross-references:**
      - PR #331 body + Self-Test Report (Drew)
      - Commit `0925ba4` (PR #331 head — harness fix landed here)
      - `tests/playwright/specs/ac2-first-kill.spec.ts:83` — the impacted
        spec (passes after harness fix at ~41.6s)
      - `.claude/docs/test-conventions.md` § "Special handling for
        `test.fail()` glyphs" — related Playwright-harness convention
      - `.claude/docs/html5-export.md` § "Service-worker cache trap" —
        adjacent HTML5-side latency surface

      **Owners.** Devon (engine-side input-trace + diagnosis). Drew (harness-
      side verification once root-cause identified).

- created_at: 2026-05-23T (Priya bundled-process PR)
- attempts: 0 (queued; MCP not enumerated in sub-agent tool surface — orch flushes)

---

## ENTRY 2026-05-23-031

- op: create_task
- list_id: 901523123922
- payload:
    name: "tools(orchestrator): triage-playwright.sh wrapper + CLAUDE.md display-vs-summary callout"
    priority: normal
    tags: [tools, process, follow-up, orchestrator]
    status: "to do"
    description: |
      **Filed by:** Priya (bundled process PR follow-up from 2026-05-23
      misclassification incident).

      **Context.** 2026-05-23 the orchestrator dispatched 3 agents on a
      phantom "8+ Playwright regressions" framing by grepping `✘` glyphs
      from `gh run view --log-failed`. The actual run summary said
      `1 failed, 15 skipped, 35 passed`. Cost: ~3 wasted agent dispatches +
      escalated framing to Sponsor + ~1hr churn. Doctrine for this exists
      (memory `triage-from-authoritative-summary-not-display.md`) but
      didn't fire because the orchestrator generated the brief from display
      output without consulting it.

      **Scope (two-part deliverable):**

      **Part 1 — `tools/triage-playwright.sh` wrapper.** Bash script that:
      1. Accepts a run-id as `$1` (or fetches latest from main HEAD).
      2. Calls `gh run view <id> --log` once; parses the `N failed / M
         passed / K skipped` summary line authoritatively.
      3. Emits ONLY: `N failed | M passed | K skipped` + a named list of
         each failing spec (one per line, file:line format).
      4. Suppresses all `✘` / `✓` / `-` glyph output — eliminates the
         glyph-counting temptation entirely.
      5. Exit 0 if `N failed == 0`; exit 1 otherwise.
      6. Tested against PR #330/#331 sample runs to confirm zero
         false-positives.

      Companion: `tools/triage-gh-checks.sh` for `gh pr checks` output
      (similar shape — authoritative status-rollup, not per-check glyph
      list). Future siblings (`triage-vitest.sh`, `triage-gut.sh`) follow
      the same convention.

      **Part 2 — `CLAUDE.md` top-level callout.** Promote the display-vs-
      summary doctrine from memory-only to a 2-3 line callout in
      `CLAUDE.md` § "Hard rules (orchestrator + team)" so it auto-loads
      into every dispatch context (memory is loaded by orch main session
      but NOT by sub-agents per `sub-agent-context-load-discipline`). One
      line referencing the wrapper scripts; one line referencing the
      authoritative-summary rule; one line cite to the memory.

      **Owners.** Devon (Part 1 — tools surface; Bash + shell scripting).
      Priya (Part 2 — CLAUDE.md edit + cross-reference cleanup).

      **Cross-references:**
      - Memory `triage-from-authoritative-summary-not-display.md`
      - Memory `orchestrator-preventive-verification.md` (companion;
        landed in this same bundled PR)
      - 2026-05-23 incident: 3 wasted dispatches on phantom 8-failure
        cluster — `decisions-while-away.md` entry of that date

      **Why this matters.** Memory-only documentation will keep losing
      this race until structural changes land. The wrapper closes the
      glyph-counting surface at the tool level (you can't extrapolate
      from glyphs that aren't emitted). The CLAUDE.md callout makes the
      doctrine visible at session-start without depending on sub-agents
      reading the memory file (which they don't auto-load).

- created_at: 2026-05-23T (Priya bundled-process PR)
- attempts: 0 (queued; MCP not enumerated in sub-agent tool surface — orch flushes)

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


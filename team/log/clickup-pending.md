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

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

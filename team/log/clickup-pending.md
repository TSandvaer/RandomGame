# ClickUp pending queue

Operations that failed against the ClickUp MCP and need replay on the next dispatch.
Format per `team/CLICKUP_FALLBACK.md`. Move synced entries to `clickup-synced.md`.

---

(empty — all 17 entries flushed 2026-05-02 by orchestrator after MCP reconnected. See `clickup-synced.md` for history. New ClickUp task IDs created during flush: `86c9kxnqx` (test-hooks chore), `86c9kxnr8` (qa role-expansion ack), `86c9kxntp` (Grunt layer bug, major), `86c9kxnve` (content-factory risky tests bug, minor).)

## ENTRY 2026-05-02-018
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: in progress
- created_at: 2026-05-02T20:20
- attempts: 1
- note: Devon run 008 — start of `chore(ci): hardening pass`. MCP disconnected on dispatch start; queueing per CLICKUP_FALLBACK.md. Will flip to `complete` at end of run via a second entry if MCP still down.

## ENTRY 2026-05-02-019
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: complete
- created_at: 2026-05-02T20:30
- attempts: 1
- note: Devon run 008 — completion of `chore(ci): hardening pass`. PR self-merged per chore(ci) protocol exemption. (Both flips queued together in the same run since MCP is down end-to-end; orchestrator should apply 018 then 019 sequentially on next reconnect — either order is also fine since 019's terminal status overrides 018's transitional one.)

## ENTRY 2026-05-02-020
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: ready for qa test
- created_at: 2026-05-02T20:14
- attempts: 1
- note: **Supersedes ENTRY 019.** Devon run 009 — follow-up PR #78 (`devon/ci-hardening-followup`) opened against `main` with the three gaps the current dispatch flagged on top of run 008's PR #76 (workflow `timeout-minutes: 10`, `addons/gut/` cache keyed on `GUT_VERSION`, flake-quarantine pattern doc). Cold + warm cache demo runs landed (25258478843 cold / 25258516097 warm). Routed through Tess per current dispatch — the prior run-008 self-merge was made under that agent's reading of GIT_PROTOCOL's `chore(ci)` exemption; current dispatch overrides with "Tess signs off". Apply ONLY this entry (020) on next MCP reconnect; ENTRY 019's `complete` flip is no longer correct. ENTRY 018 (`in progress`) is still fine as a transitional waypoint but will be overridden by 020 (`ready for qa test`) — replay both 018 then 020 in order.

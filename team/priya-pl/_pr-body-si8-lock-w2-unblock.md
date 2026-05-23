## Summary

SI-8 locked by Sponsor at 2026-05-23 10:08 UTC on PR #328 to **option (b) — partially procedural with hand-pinned set-pieces**. This PR captures the lock as institutional memory and unblocks the W2 dispatch chain:

- **Summary doc** (`team/priya-pl/si8-lock-2026-05-23-w2-unblock.md`, ~150 lines) — what (b) means, which W2 tickets unblock, ticket-update log, cross-refs to PR #328 + v1.2 §5.2 + v1.3 §B.
- **Three queued ticket-body updates** (`team/log/clickup-pending.md` ENTRY 029 / 030 / 031) — W2-T2 + W2-T3 + W2-T4 bodies pre-filled with target text. ClickUp MCP failed-to-connect at this dispatch; orchestrator flushes after MCP reconnects.

## Ticket-update log

| Ticket | ID | Update mode | Notes |
|---|---|---|---|
| W2-T2 dialogue impl | `86c9y0zyv` | queued-fallback (ENTRY 029) | Folds v1.3 §5.1 Part D (Drew nits 1+2 + read-order discipline) |
| W2-T3 procgen retrofit | `86c9y1045` | queued-fallback (ENTRY 030) | SI-8 (b) scope locked; (b)-specific acceptance + OOS + files-in-play + size L-XL |
| W2-T4 world_seed save-write | `86c9y108t` | queued-fallback (ENTRY 031) | Folds v1.3 §5.1 Part D (Drew nit 3 — survey § header footnote) |

MCP outage at dispatch time = same structural class as the W1 procgen-spike Self-Test Report flip ([`clickup-mcp-three-occurrence-structural`](https://github.com/anthropics/claude-code/issues?q=clickup-mcp-three-occurrence-structural)). Per `team/CLICKUP_FALLBACK.md`, queue-and-flush handled it; no work blocked.

## Decision draft (for next DECISIONS.md batch)

```
Decision draft: SI-8 — M3 Tier 3 procgen shape locked to (b) partially procedural with hand-pinned set-pieces. Foundation: PR #328 SI-8 recommendation section + 2026-05-23 Sponsor sign-off on this orch turn. Reversibility: ZoneDef.stratum_id permits any anchor density per-zone if specific design demands.
```

## Files authored

- `team/priya-pl/si8-lock-2026-05-23-w2-unblock.md` — NEW. Summary doc.
- `team/log/clickup-pending.md` — three new queue entries (029 / 030 / 031) appended.

## Sponsor-input items

None — SI-8 already locked by Sponsor pre-PR. This PR captures the lock + unblocks downstream dispatch.

## Test plan

- [x] Worktree branched from `origin/main` (`c:/Trunk/PRIVATE/RandomGame-priya-wt`).
- [x] Summary doc + queue entries written with absolute paths cited.
- [x] Decision draft line included in PR body for next batch.
- [ ] Orchestrator flushes ENTRY 029 / 030 / 031 via `mcp__clickup__update_task` after MCP reconnects.
- [ ] W2 dispatch chain proceeds per `post-wave3-sequencing.md` v1.2 §6 Day-1 / Day-2 sequencing (W2-T4 first on Devon-wt; W2-T1 first on Drew-wt; W2-T3 on Day 2 after W2-T4 lands).

**Ticket:** `chore/orch-authored` — no ticket flip needed for this Priya-docs PR.

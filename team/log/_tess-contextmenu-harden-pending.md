# ClickUp pending — Tess contextmenu-harden chore

## ENTRY 2026-05-31 — chore(test): harden contextmenu-suppress spec to fail on revert

- **op:** create_task
- **list_id:** `901523123922` (RandomGame list, per `team/CLICKUP_FALLBACK.md`)
- **payload:**
    - name: `chore(test): harden contextmenu-suppress spec to fail on revert`
    - priority: 3 (Normal)
    - status: (default)
    - description: |
        The committed contextmenu-suppress.spec.ts (on main via #389) is a false-green for the
        DCL-deferral regression class: its test 5 ("suppressor active as soon as canvas exists")
        dispatches the contextmenu AFTER waitForSelector("#canvas"), by which time DOMContentLoaded
        has already fired on a fast headless load — so a revert to the DCL-deferred suppressor form
        still passes it. Hardened by splicing a pre-DCL probe (page.route) that fires a contextmenu
        at document during head parse while readyState==="loading". OOS: re-fixing suppressor / any
        game-code change. Peer reviewer: Drew.
- **created_at:** 2026-05-31
- **attempts:** 2
- **Status: UNSYNCED — ClickUp MCP DOWN.** `mcp__clickup__create_task` returned `404 Not found`
  against BOTH `901523123922` (canonical RandomGame list per CLICKUP_FALLBACK.md) and `901810005857`
  this session — the MCP server is unreachable, not a bad list ID. The whole tool-output channel
  degraded this session (Bash stdout / Read of fresh files / MCP results intermittently empty).
  Per never-fabricate, NO ticket ID was invented and none is on the PR.
- **Replay:** orchestrator/Priya flush this on the next dispatch when MCP reconnects; capture the
  real ticket ID and attach it to PR branch `tess/contextmenu-test-harden`.

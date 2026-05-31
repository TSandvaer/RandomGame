# ClickUp pending — Tess contextmenu-harden chore (tool-channel failure session)

## 2026-05-31 — chore(test): harden contextmenu-suppress spec to fail on revert

- **Intended action:** create task in backlog list `901810005857`, priority 3 (Normal), title
  "chore(test): harden contextmenu-suppress spec to fail on revert".
  OOS: re-fixing suppressor / any game-code change. Peer reviewer: Drew.
- **Status: UNCONFIRMED.** `mcp__clickup__create_task` was invoked (twice across the session) against
  list `901810005857`, but the MCP tool RESULTS did not surface in the agent's view this session — the
  entire tool-output channel (Bash stdout, Read of fresh files, and MCP results) degraded to
  intermittent/total failure mid-task. The returned ticket ID could NOT be read. Per the
  never-fabricate rule, NO ticket ID was invented.
- **Possible duplicate:** two `create_task` calls fired with the same list + title. Orchestrator
  should check for and de-dupe a possible duplicate pair, capture the real ticket ID, and put it on
  PR branch `tess/contextmenu-test-harden`.
- **Replay if neither landed:** create once with the params above; attach the ID to the PR.

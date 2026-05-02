# ClickUp Fallback Procedure

The Project Leader (Priya) is the primary ClickUp user. The MCP server can disconnect mid-session. Procedure when that happens:

1. **Try ClickUp first**, every time. If the call succeeds, write directly to RandomGame list `901523123922`.
2. **On failure**, append the operation to `team/log/clickup-pending.md` as a queue entry — exact title, description, tags, priority, status. Tasks proceed locally; ClickUp is the eventual store of record.
3. **Each heartbeat tick**, the orchestrator (or Priya at her next dispatch) attempts to flush the pending queue back to ClickUp. Successfully synced entries are moved to `team/log/clickup-synced.md` with the resulting ClickUp task ID.
4. **Never block real work** on ClickUp availability. The local ledger is the live state; ClickUp is the canonical mirror.

## Pending queue format

```
## ENTRY YYYY-MM-DD-NNN
- op: create_task | update_task | add_comment | add_tag | ...
- list_id: 901523123922
- payload:
    name: "feat(combat): basic mob attack loop"
    priority: high
    tags: [week-2, combat]
    status: to do
    description: |
      ...
- created_at: 2026-05-02T14:23
- attempts: 0
```

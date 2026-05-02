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

## Summary

Three documentation captures from the M3 Tier 1 character-art batch (PRs #271-#278, all merged) that closed during session `session-2026-05-18-1315-m3-tier1-character-art-closed`. Pure docs follow-up — no code changes.

### `.claude/docs/pixellab-pipeline.md` — Strategy 4

New section after Strategy 3: **Luminance-band role routing + character-beat HSV overrides** (validated 2026-05-18 on PR #276 S1 Grunt v2 → S2 Stoker retint).

- Why it's distinct from Strategies 1-3: those route by color distance (RGB/CIEDE2000). That works for first-time doctrine-lock of a fresh PixelLab generation. It **fails** for cross-stratum retints of an already-doctrine-locked sprite — color distance is silhouette-blind across stratum doctrines, so red eye-glow can route to cloth-base, iron buckles can warm into bronze, etc.
- Strategy 4 routes by **luminance ROLE** (highlight / lit / mid / shadow / deep) → target stratum doctrine role. Works because the source sprite's tonal structure is correct by construction (already doctrine-locked).
- **Character-beat overrides fire first** — HSV-gated detection for red eye-glow (`H ∈ [350°, 20°] AND S > 0.45 AND V > 0.4`) and iron-neutral metal (`S < 0.15 AND 0.25 < V < 0.65`) bypass the luminance dispatch entirely so accents survive the retint.
- Includes band-to-role table, Python routing function from `tools/bake_stoker_palette.py`, the "when to use 3 vs 4" decision matrix, and a 5-step validation pattern.

### `.claude/docs/orchestration-overview.md` — two new subsections under "Git workflow"

**1. Worktree cleanup before `gh pr merge --delete-branch`** (replaces the older "harmless; auto-rotates on next dispatch" line, which undersold the ClickUp-flip short-circuit risk).

- Documents the 3-action breakdown of `gh pr merge --delete-branch` (merge / delete remote / delete local) and explains why step 3 fails when an agent worktree holds the branch.
- Captures the **ClickUp-flip short-circuit risk**: `gh` exits non-zero on the step-3 failure, which can skip the paired ClickUp `complete` status flip (`clickup-flip-paired-with-merge` memory).
- Recovery sequence: `git -C <agent-wt> switch --detach HEAD` → retry merge (returns "Pull request was already merged") → run the short-circuited ClickUp flip.
- **Prevention** — agents whose work has been merged self-detach BEFORE submitting their final report. Dispatch briefs that end with "and merge" should include this explicitly.
- Validated 2026-05-18 (PR #276 Stoker merge first hit the failure path; PRs #274 + #277 then merged clean using pre-detach as the standard).

**2. Multi-line PR bodies / comments — always use `--body-file`, never heredoc**

- Markdown special chars (`#`, backticks, `<`, `>`, `*`, `_`, `$`, `!`) collide with shell quoting in both bash and PowerShell. Heredoc `--body "$(cat <<EOF ... EOF)"` and inline `--body "..."` both stall on non-trivial markdown.
- Validated 2026-05-18: Devon's first M3W-7 dispatch stalled mid-heredoc trying to embed a multi-line PR body. The 600 s stream watchdog killed the agent before recovery. Recovery dispatch using `--body-file` worked first try.
- Same trap applies to `gh pr comment`, `gh issue create`, `gh issue comment`, anything taking `--body`.
- Dispatch-brief discipline: when the brief ends with "open a PR" / "post a Self-Test Report", show the `--body-file <path>` form in the example. Sub-agents copy the shape — wrong examples burn cycles.

This PR body itself was authored via `--body-file` per the new discipline. Meta but intentional.

## Test plan

- [x] Diffs reviewed locally — content matches the session-save's pre-staged description
- [x] No code or asset changes — pure `.claude/docs/*.md` markdown
- [ ] CI green (lint / GUT / Playwright should all be no-op for doc-only)
- [ ] GitHub markdown renders both files correctly (tables, fenced code blocks, headers)
- [ ] Spot-check the three new sections in the rendered GitHub view for collapsed/broken markdown

## Related

- Session save: `session-2026-05-18-1315-m3-tier1-character-art-closed.md`
- M3 Tier 1 batch PRs (already merged): #271, #273, #274, #275, #276, #277, #278
- Memories referenced: `clickup-flip-paired-with-merge`, `orch-authored-pr-merge-needs-sponsor-ack`

🤖 Generated with [Claude Code](https://claude.com/claude-code)

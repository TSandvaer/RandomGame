# Post-PR-#333 — gdlint Stage-2 Follow-up Ticket Sweep

**Owner:** Priya
**Authored:** 2026-05-23
**Status:** Ticket-creation sweep complete; bodies queued for ClickUp flush via fallback queue.

## Context

PR #333 (`ci(static-analysis): add gdlint + gdformat warnings-only step`,
merge commit `0758550`, 2026-05-23) shipped Stage 1 of the gdtoolkit
static-analysis rollout. The Stage-1 baseline surfaced:

- **387 gdlint findings** across `scripts/` + `tests/`, top categories:
  - `max-line-length` — 175 (`gdlintrc:36` = 100-char cap)
  - `class-definitions-order` — 92 (`gdlintrc:1-15` ordering rule)
  - `duplicated-load` — 58 (`gdlintrc:22` enabled)
  - `max-public-methods` — 23 (`gdlintrc:37` = 20-method cap)
  - Smaller categories (load-constant-name, max-file-lines, function-name,
    max-returns, function-variable-name, mixed-tabs-and-spaces, class-
    variable-name, unused-argument, loop-variable-name, unnecessary-pass)
    not yet ticket-shaped — these are the long tail (1-9 findings each)
    that the four top categories' sweeps will mechanically address as
    side-effect, OR will be folded into a tail-end cleanup pass after the
    top-four sweeps land.
- **179 gdformat reformat findings** (files would be reformatted; 18
  unchanged).

Plus an orthogonal finding from Drew's PR #332 review: stale 3-arg
docstring on `scripts/levels/FloorAssembler.gd:30-31`
(`derive_zone_seed`).

Per PR #333 final-report, Stage-2 fix-pass tickets are the orch-docs
follow-up to bound the lint surface before Stage-3 promotes warnings to
errors.

## Filed tickets (8 total)

All 8 tickets queued via the ClickUp fallback pattern
(`team/CLICKUP_FALLBACK.md`) into `team/log/clickup-pending.md` as
ENTRIES `2026-05-23-032` through `2026-05-23-039`. ClickUp MCP flush by
orchestrator post-dispatch will assign real ticket IDs.

| ENTRY | Headline (conventional-commit shape) | Owner | Size | Priority | Sequence |
|---|---|---|---|---|---|
| **032** | `investigate(lint): class-definitions-order false-positive scope on Director pattern` | Devon | S | P2 | First — blocks ENTRY 036 |
| **033** | `investigate(lint): duplicated-load false-positive scope on HTML5 cache warmup` | Devon | S | P2 | First — blocks ENTRY 035 |
| **034** | `fix(lint): max-line-length sweep (~175 findings)` | Devon | M-L | P2 | Parallel — orthogonal to investigations |
| **035** | `fix(lint): duplicated-load sweep (~58 findings)` | Devon | S | P2 | **HARD BLOCKED** on ENTRY 033 verdict |
| **036** | `fix(lint): class-definitions-order sweep (~92 findings)` | Devon | M | P3 | **HARD BLOCKED** on ENTRY 032 verdict |
| **037** | `fix(lint): max-public-methods sweep (~23 findings)` | Devon | M | P3 | LAST — sequence after 034/035/036/038 |
| **038** | `chore(lint): gdformat reformat sweep (~179 files)` | Devon | L | P2 | Recommended after 034/035 (diff overlap risk) |
| **039** | `fix(docs): floor_assembler.gd derive_zone_seed docstring 3-arg → 2-arg correction` | Drew or Devon | S | P3 | Independent of lint sweep |

## Sequencing recommendation

```
[032 investigate]                  [033 investigate]    [034 max-line-length]   [039 docstring fix]
      │                                   │                       │                       │
      ▼                                   ▼                       │                       │
[036 class-order sweep]            [035 dup-load sweep]            │                       │
                                                                  ▼                       │
                                                          [038 gdformat sweep]            │
                                                                  │                       │
                                                                  ▼                       │
                                                          [037 max-public-methods]        │
                                                                  ▼                       ▼
                                                           (Stage 3: promote to errors)
```

**Parallel-dispatch shape:** the orchestrator can fire 032/033/034/039
in parallel on Day 1 (no inter-dependencies). 035 dispatches after 033
merges; 036 after 032 merges; 038 ideally after 034 to minimize
diff-overlap noise; 037 last to handle Director-pattern API-surface
residuals after the other ~360 findings clear.

**Velocity estimate (calendar):** Day 1 (parallel 032+033+034+039); Day
2-3 (035+036+038 land sequentially as deps clear); Day 4 (037 sweep).
~4 calendar days total assuming Devon's full attention. Realistic with
other in-flight work: ~1 week. Stage 3 promotion (drop `set +e`/`true`
in `ci.yml` and let gdlint exit non-zero block PRs) gated on all 8
tickets merging + baseline at zero or documented residuals.

## Why investigation-first on two of the eight

Per `bandaid-retirement-scope-blowup` memory rule, sweep-style tickets
are scope-underestimated when they touch load-bearing patterns. Two of
the four big rule classes had legitimate "are these all real
violations?" questions:

- **`class-definitions-order`** — Director-pattern autoloads
  (`AudioDirector` / `TimeScaleDirector` / `CameraDirector` /
  `DialogueController`) intentionally cluster signals next to emitters
  + group const blocks for cohesion. gdlint's strict ordering may
  collide with the documented Director topology
  (`.claude/docs/{audio-architecture,camera-layer,time-scale-director,dialogue-system}.md`).
  ENTRY 032 reports verdict before ENTRY 036 sweeps.

- **`duplicated-load`** — there MAY be an intentional HTML5
  ResourceCache `preload(...)` warmup idiom mitigating
  `gl_compatibility` cold-load hitch per
  `.claude/docs/html5-export.md` § "Service-worker cache trap." If
  present, collapsing the duplicate silently regresses HTML5 boot
  perf. ENTRY 033 reports verdict before ENTRY 035 sweeps.

The remaining two classes (`max-line-length`, `max-public-methods`)
have no analogous load-bearing-pattern concern and ship as direct
sweeps. `max-public-methods` is sequenced LAST per PR #333's own
recommendation because Director-pattern surfaces will land in (b)/(c)
classification — per-file disable pragma with rationale, not refactor.

## Cite trail

- PR #333 merge commit `0758550` — gdlint baseline (387 findings, 179
  reformats) + suggested top fix-pass tickets in PR body
- PR #333 Self-Test Report (TSandvaer comment 1) — local-run finding
  excerpts confirming `class-definitions-order` and `max-line-length`
  hits on `CameraDirector.gd`
- PR #332 merge commit `7bfae0f` — `.claude/docs/procgen-pipeline.md`
  capture
- Drew's PR #332 review file `team/drew-dev/pr332-approve.md` lines
  8-9 — `floor_assembler.gd` 3-arg → 2-arg docstring finding
- `gdlintrc` — rule configuration (max-line-length: 100,
  class-definitions-order ordering, duplicated-load enabled,
  max-public-methods: 20)
- `lint-reports/gdlint.txt` + `lint-reports/gdformat.txt` artifacts
  attached to PR #333's CI run — full baseline finding list

## Doc-update considerations

None this dispatch — the 8 tickets queue + this summary doc are pure
orch-docs / process artifacts. No `.claude/docs/*.md` updates warranted.
Memory rules in scope (`bandaid-retirement-scope-blowup`,
`clickup-status-as-hard-gate`, `same-day-decisions-rebase-pattern`,
`sponsor-decision-delegation`) applied; no new memory candidate.

## Decision drafts (for next weekly DECISIONS.md batch — Monday)

None this dispatch — the sequencing recommendation is operational
tactical detail, not a strategic decision-of-record. If Devon's ENTRY
032 or ENTRY 033 verdicts surface a `gdlintrc` disable, that disable IS
the decision-of-record and will be captured in the verdict PR's body
(no separate DECISIONS.md entry needed; gdlintrc IS the decision).

## Cross-references

- `team/log/clickup-pending.md` ENTRIES 032-039 — full ticket bodies
- `team/priya-pl/post-wave3-sequencing.md` v1.3 — current M3 Tier 3
  sequencing context (lint-sweep tickets are parallel-orthogonal to
  W2 system-shape work)
- `team/CLICKUP_FALLBACK.md` — fallback queue format
- PR #333 (merge commit `0758550`) — Stage-1 gdlint CI integration
- PR #332 (merge commit `7bfae0f`) — Drew's review-flagged finding

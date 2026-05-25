# Retro template

Copy this template when authoring a new retrospective. Per-retro files live at `team/priya-pl/retros/retro-YYYY-MM-DD-<topic>.md` (NOT in `.claude/retros/` — this directory holds only the template + future template revisions).

**Why retros exist:** the dominant context-bloat surface in orchestrated projects is verbose post-mortems and pattern observations sitting in the main conversation window. A retro file PROMOTES those observations to disk, where they can be (a) cited later without re-deriving, and (b) routed to a DURABLE destination (`.claude/docs/` / auto-memory / `team/log/process-incidents.md` / ClickUp / CLAUDE.md hard rule). Findings that don't make it to a durable destination effectively die at retro-time — past RG retros (`ac4-white-whale-retro.md`, `m2-week-2-retro.md`, `m2-week-3-mid-retro.md`, `week-2-retro-and-week-3-scope.md`) had reduced impact precisely because the lesson-promotion step was ad-hoc.

---

## When to fire a retro

Per memory `per-class-retro-trigger-convention` (Sponsor-locked 2026-05-23), retros fire on FOUR specific PR-merge classes. Routine impl merges do NOT trigger a retro — they ship without one.

1. **Wave-completion PR** — the PR whose merge closes a planning Wave (W1 / W2 / W3 of a Tier). Detect via ticket-id (W-prefix in title or ticket body) OR by counting open W-N tickets transitioning to `complete` in the same session.
2. **Spike PR** — any PR whose title starts `spike(...)` or whose ticket has the `spike` tag. Spikes prove/disprove a hypothesis by definition.
3. **Process-incident PR** — PRs that document a process incident, a memory entry update remediating prior failure, or a hook/skill/convention change (orch-docs / orch-hooks).
4. **Multi-iteration PR** — any PR that went through ≥3 reviewer round-trips before merge.

**Plus ad-hoc:** Sponsor or Priya can fire a retro outside the trigger list ("do a retro on PR #N"). Per-class is the floor for automation, not the ceiling.

**Who dispatches:** orchestrator detects the trigger at merge-pair time (alongside the ClickUp flip per memory `clickup-flip-paired-with-merge`) and dispatches Priya with a retro brief for that PR. Three or more triggers in one session warrants a meta-retro at session-save covering the cluster.

---

## Retro structure

Mandatory sections (in this order). Aim for ≤2 pages unless the retro is a milestone-arc close.

### Header

```
# Retro — <topic / wave / incident scope>
Date: YYYY-MM-DD
Trigger class: <Wave-completion | Spike | Process-incident | Multi-iteration | Ad-hoc>
PR(s) in scope: <#N, #N+1, ...>
Author: Priya
Honest grade: <letter + 1-line justification>
```

### Context (1-2 sentences)

What shipped + the headline metric (PRs merged, tests added, iterations endured). No narration.

### What happened

Concrete chronology of the PR(s) under review. Include: dispatch sequence, reviewer round-trips, broken-main events, agent re-dispatches, key Sponsor interventions. Cite PR URLs, commit SHAs, comment IDs — per memory `doc-capture-verify-cites-first`, every concrete value MUST be verifiable.

### Patterns observed

- **PATTERN — `<name>`** — description + when it applies. Validated by `<evidence — PR # / SHA / file path>`.
- **ANTI-PATTERN — `<name>`** — description + how to avoid. Cost incurred this cycle: `<orchestrator time / agent re-dispatches / broken-main duration>`.

Mark each as net-new vs reinforcement-of-existing. Reinforcement entries cite the existing memory/doc by name.

### Hypothesis verdict (only if Sponsor framed hypotheses)

| Hypothesis | Verdict | Evidence |
|---|---|---|
| ... | TRUE / FALSE / PARTIAL | `<PR # / SHA / cite>` |

### Durable lessons promoted

The load-bearing section. Every finding worth keeping MUST name its destination per the routing matrix below. Findings without a destination are NOT durable — they die at retro-time.

| Finding | Destination | Owner | Status |
|---|---|---|---|
| `<1-line lesson>` | `<see routing matrix below>` | `<Priya / Orch / persona>` | `<filed / in-flight / pending>` |

### Next-session backlog

Concrete actions surfaced by the retro. Each one either becomes a ClickUp ticket OR is rolled into the next sprint's planning. No "we should think about X" — actionable or cut.

1. `<action — file ticket / write doc PR / refine dispatch template / etc.>` — owner + cost estimate
2. ...

---

## Durable lessons promoted — routing matrix

Every retro finding lands in ONE of these destinations. Picking the right destination is the difference between a finding that compounds and a finding that's forgotten.

| Destination | Use when | Authoring path |
|---|---|---|
| `.claude/docs/<file>.md` | Architectural convention, system topology, or non-obvious mechanic that future sessions will need eagerly loaded | Author follow-up doc PR (Priya or relevant persona); SessionStart auto-loads these |
| Project-scoped memory entry | Durable orchestrator preference / RG-specific workflow rule that should persist across sessions but isn't architectural | New `.md` under `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/` + entry in `MEMORY.md` index |
| User-global memory entry | Cross-project lesson (orchestration discipline, dispatch hygiene, sub-agent contract) | New `.md` under `~/.claude/memory/` + entry in user-global `MEMORY.md` |
| `team/log/process-incidents.md` | Post-mortem of a process-class failure (broken main, scope blowup, MCP outage, soak miscalibration) | Append entry with date / class / cost / remediation |
| ClickUp ticket | Tactical follow-up to assign (NIT cleanup, deferred fix, infrastructure work) | File under appropriate list with reviewer pre-assigned |
| `CLAUDE.md` hard rule | Cited memory has fired 3+ times (third-occurrence escalation pattern, per memory `sponsor-soak-artifact-links` precedent) | Sponsor approval required; orch-docs PR adds rule to project CLAUDE.md `## Hard rules` section |
| `team/DECISIONS.md` (via Priya batch PR) | Cross-team structural decision worth preserving as institutional memory | Add as `Decision draft:` line in retro final report; Priya batches into Monday DECISIONS.md PR per CLAUDE.md convention |

**The 3rd-occurrence escalation pattern:** when a memory fires for the third time on the same class of incident, promote it to a project CLAUDE.md hard rule. Worked example: `sponsor-soak-artifact-links` was escalated to hard-rule status 2026-05-24 after 3 fires (PR #143 May 6, PR #304 May 22, W2-T5 May 24). Track occurrence count in the memory's `## Why` section as evidence accumulates.

---

## Reporting digest

Per memory `retrospective-reporting-convention`, every retro MUST surface to Sponsor as a structured digest in-channel — the artifact alone is insufficient. The orchestrator relays this digest verbatim from the retro doc's final section.

Required digest shape (paste at the END of the retro doc, pre-populated so orchestrator just relays):

```
## Retrospective: <scope> (Priya) — <PR # or doc path>

**Honest grade:** <letter + 1-line justification>
**Methodology:** <1-sentence sample description>

**Top patterns (with cite-able evidence):**
1. **P1** <name> — <1-line w/ PR # or memory cite>
2. **P2** <name> — <1-line w/ PR # or memory cite>
3. **P3** <name> — <1-line w/ PR # or memory cite>

**Hypothesis evaluation (if Sponsor framed hypotheses):**
| Hypothesis | Verdict | Evidence |
|---|---|---|
| ... | TRUE / FALSE / PARTIAL | ... |

**Top mitigations (with orch recommendation):**
1. <action> — <owner, cost, expected impact>
2. <action> — <owner, cost, expected impact>
3. <action> — <owner, cost, expected impact>

**Sponsor decision surface:** <0-N items requiring explicit Sponsor ack>
- <item> — <recommendation>

**Next retro cadence:** <when + scope>

**Artifacts:** <PR URL>, <doc path>
```

**Honest-grading discipline (per Priya persona):** no victory laps. Grades earned, not gifted. M2-W2 was a C+ (planned content didn't ship); M2-W3 mid was a B+ (huge velocity but R6 fired hard, AC4 still gated). The team gets better from honest grades, not optimistic ones.

---

## Filing convention

- **Per-retro file path:** `team/priya-pl/retros/retro-YYYY-MM-DD-<topic>.md`
  - Example: `team/priya-pl/retros/retro-2026-06-02-m3-tier3-w1-close.md`
  - Topic slug is kebab-case, 2-4 words max — describes what the retro covers, not the verdict.
- **Older ad-hoc retros stay in place** at `team/priya-pl/*.md`. No migration sweep — just adopt this convention going forward.
- **Template lives at** `.claude/retros/RETRO-TEMPLATE.md`. Do NOT author per-retro files here.
- **PR-body for the retro:** the retro doc itself goes in the PR body (or linked from the PR body if too long). PR title format: `docs(retro): <scope> — <trigger class>`.
- **SessionStart load:** the retro file itself does NOT auto-load. Only the promoted lessons (docs / memory / process-incidents entries you authored from the retro) carry into future-session context. This is by design — retro files are reference, not always-loaded preamble.

---

## How to use this template

1. **Copy to a dated file:** `cp .claude/retros/RETRO-TEMPLATE.md team/priya-pl/retros/retro-YYYY-MM-DD-<topic>.md`.
2. **Author within the triggering session if possible** — context is freshest.
3. **Fill the routing matrix entries inline as you write** — don't defer "we'll figure out where this goes later." If a finding can't be routed to a concrete destination, it's not durable enough to keep.
4. **Promote durable lessons in the SAME orchestration round** the retro is authored. Doc PRs, memory entries, and process-incident appends happen as part of the retro merge, not deferred.
5. **Surface the reporting digest** to Sponsor in-channel when the retro PR opens. Orchestrator relays verbatim.
6. **Cross-reference** in `team/DECISIONS.md` (Priya's Monday batch PR) if the retro triggered a structural decision.
7. **Don't repeat in subsequent conversations** what's already in the retro — the file IS the artifact. Cite by path, don't paraphrase.

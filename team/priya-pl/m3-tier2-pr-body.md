## Summary

M3 Tier 2 — boss-room polish — **expanded to full Uma `boss-intro.md` spec** (Sponsor decision 2026-05-20). Scope doc v1.1 lays out a **wave-ordered ship plan**: 18 dispatch-ready tickets across 3 fan-out-friendly waves, ~3 weeks calendar of distributed work, closing all 30 BI-criteria + F1–F4 climax beats + skip-rule.

## Verdict in one line

**Ship the full cinematic layer. 3 waves of 6 tickets each. ~3 weeks calendar with parallel-dispatch across Devon + Drew + Uma + Sponsor PixelLab generation. No single role bottlenecks any wave.**

## The headline finding (unchanged from v1)

Uma's `boss-intro.md` spec (30 BI-criteria + F1–F4) was **largely never implemented**. The boss state machine + M3W-4 AnimatedSprite2D visuals + PR #278 SFX cues are wired clean — but the cinematic layer Uma designed (door slam, nameplate, ambient fade, BGM crossfade to boss music, camera zoom, world-time-slow on phase transitions, defeat title card, embers-rising dissolve) was largely never built. The signals `entry_sequence_started` / `entry_sequence_completed` / `boss_defeated` exist in production code but **fire to zero subscribers**.

The full-spec ship-call closes that gap entirely. The team is sized correctly to ship it in 3 waves.

## Wave plan headline

| Wave | Tickets | Cinematic delivery | Calendar |
|---|---|---|---|
| **1 — foundational, no spike gates** | T11 TimeScaleDirector + T1 BGM crossfade + T2 hit-pause + T3 phase-transition slow + T4 defeat title card + T7 phase-break + boss-wake SFX | Boss music, hit-pause weight, phase-break audio/time-slow, defeat title card. Emotional load-bearing subset closes. | ~1 week |
| **2 — spike-resolved foundations + design direction** | T9 Camera2D autoload + T12 vignette CanvasLayer + T10 S1 ambient + T8 boss wake animation + T5 slam telegraph indicator + T6 slam aftershock | Camera2D in M1 play loop (foundational); ambient ducks on entry / resumes on defeat; vignette + telegraph polish. | ~1 week |
| **3 — heavy lifts gated on Wave 2** | T13 BossNameplate + T18 below-10% pulse + T14 door slam visual + T15 HUD context-region + T16 embers-rising sustained dissolve + camera ease-in + T17 skip-after-first-kill flag | Full nameplate (BI-07–15); door visual (BI-01, BI-02); HUD red treatment (BI-20); F2 climax with camera ease-in; intro skip (BI-21, BI-22). | ~1 week |

**At Wave 3 close: all 30 BI-criteria + F1–F4 are wired. Full spec ships.**

## What's in the doc

1. **§1 Inventory (unchanged from v1)** — Stratum1Boss + Stratum1BossRoom current state, broken into combat (wired), M3W-4 visuals (wired), PR #278 audio (wired), cinematic layer (largely unimplemented, file-by-file source refs).
2. **§2 Candidates (unchanged from v1)** — 19 plausible polish-area candidates across 5 axes.
3. **§3 Ticket catalogue (expanded)** — 18 dispatch-shaped tickets (was 10 in v1; added T11 TimeScaleDirector, T12 vignette, T13 nameplate, T14 door slam, T15 HUD context-region, T16 embers-rising sustained, T17 skip flag, T18 below-10% pulse). Each ticket carries owner / effort / AC / wave / dependencies.
4. **§4 Wave plan (NEW — replaces v1 "Recommended cut")** — 3 waves with per-ticket table, parallelization rationale, highest-risk surfaces + mitigations, total-effort table.
5. **§5 Open questions (trimmed)** — 3 remaining tonal/direction items (Uma boss name, hit-pause scope, vignette palette direction). Scope-envelope question removed (resolved).

## Sponsor-input items

The scope-envelope question is **resolved 2026-05-20: full spec, not 4-ticket cut.** Remaining Sponsor-input items are tonal/direction calls that don't block Wave 1 dispatch but want a sketch-pass before relevant waves land:

1. **§5.1 T4 title-card copy** — ship Uma's "WARDEN OF THE OUTER CLOISTER" working title or rename? Sponsor can ack in Wave 1; default = ship Uma's name.
2. **§5.2 T2 hit-pause scope** — boss-only (Tier 2 scope) or extend to all mobs (separate combat-feel ticket)? Default = boss-only.
3. **§5.3 T12 vignette palette + opacity curve** — Uma direction needed before T12 ships in Wave 2. Defers to Uma; not Sponsor-blocking.

## ClickUp tickets filed

Wave-1 / Wave-2 / Wave-3 ticket creation in list `901523123922` (status `to do`) — see the comment chain on this PR for the ticket IDs as they land. Naming prefix `M3-T2-` for grouping.

## DECISIONS entry

`Decision draft:` for the 2026-05-20 expansion call surfaced in the final report; collected in next Monday's batch-PR per the centralized-decisions protocol.

## Test plan

- [x] Sponsor decision recorded (full-spec expansion).
- [x] Scope doc updated to v1.1 with wave-ordered ship plan.
- [x] All 18 tickets carry owner / effort / AC / wave / dependencies.
- [x] Highest-risk surfaces flagged with mitigations.
- [ ] Wave-1 ClickUp tickets land in list 901523123922.
- [ ] Wave-2 + Wave-3 ClickUp tickets land in same list.
- [ ] DECISIONS batch-PR Monday collects the expansion call.

## Doc updates

Three non-obvious findings flagged in §"Non-obvious findings" — with the full spec now in scope, **all three findings have concrete in-flight tickets**:

- **Cinematic-layer gap baseline** → capture in `combat-architecture.md` § boss when **Wave 1 closes** (subscribers wired; loop closed).
- **`Engine.time_scale` ownership** → fresh `.claude/docs/time-scale-director.md` when **T11 lands** (Wave 1 day 1) — the director's API contract + stack semantics are the kind of cross-system contract `.claude/docs/` exists for.
- **`Camera2D` in M1 play loop** → fresh `.claude/docs/camera-layer.md` when **T9 closes** (Wave 2) — HTML5 + gl_compatibility quirks justify a dedicated doc.

All captures are in-implementation-PR scope (maintain-docs Stop hook on the merging PR); not orphan doc work in this PR.

No `.claude/docs/` edits in this PR — this is pure scoping work; doc captures land when implementation surfaces them.

ClickUp tickets land post-merge (or in parallel comments while CI runs).

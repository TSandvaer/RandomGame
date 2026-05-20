# docs(palette): amend vignette tint #000000 → #0A0606 per Uma vignette-spec (PR #292)

Resolves the latent inconsistency Uma flagged in [`team/uma-ux/vignette-spec.md`](team/uma-ux/vignette-spec.md) (landed via PR #292) between `palette.md` line 30 and the S1 anti-list (line 101).

## What changed

`team/uma-ux/palette.md` line 30 — Core neutrals table, Vignette row:

```diff
- | Vignette                  | `#000000` | Dark overlay, 30% (S1) → 60% (S8).     |
+ | Vignette                  | `#0A0606` | Warm-black overlay, 30% (S1) → 60% (S8). Sub-1.0 RGB per channel for HTML5 HDR-clamp safety; slight R-bias honors S1 "warm cloister" anti-list. See `vignette-spec.md` (T12 direction, landed via PR #292) for full opacity-curve + rendering-primitive contract. |
```

## Why

`palette.md` line 30 listed `#000000` as the vignette color since the doc landed — predating the S1 anti-list (line 101: "Pure black `#000000` — too contrasty, breaks the 'warm cloister' mood. Reserved for stratum 7-8"). Two rows in the same file contradicted each other.

Uma's vignette-spec.md (PR #292) resolves this by locking the cross-stratum vignette tint to `Color(0.04, 0.024, 0.024, opacity)` = `#0A0606` — sub-1.0 RGB per channel (HTML5 HDR-clamp safety per [`.claude/docs/html5-export.md`](.claude/docs/html5-export.md)) with a slight R-bias matching the S1 warm-cloister identity. This PR amends `palette.md` to match the locked spec.

Sponsor-input items: none — direction-driven cleanup amendment per Uma's already-landed spec; no Sponsor-decision surface.

## What's NOT changed

The other `#000000` references in `palette.md` are intentional and untouched:

- **Line 101** — S1 anti-list (the rule that pure black is reserved for S7-S8). Now consistent with line 30 amendment.
- **Lines 287, 290, 291** — S8 (Heart of Embergrave) explicit `#000000` use, the one stratum where pure-black is permitted ("the only stratum where pure-black is permitted; reserved use").
- **Line 317** — S3-S8 anti-list rule formalizing "Pure black `#000000` — S7-S8 only."
- **Line 347** — M2 settings-menu high-contrast UI mode reference.
- **Line 363** — Tester checklist PL-09: "Stratum 1 contains zero pure-black tiles in environment."

Single-line scope-locked amendment.

## Test plan

- [x] palette.md is doc-only — no GUT / Playwright impact
- [ ] CI green on PR (verified before merge)
- [ ] Sponsor ack OR orchestrator auto-merge after confirming pure-amendment-no-broader-implications

## Cross-references

- [`team/uma-ux/vignette-spec.md`](team/uma-ux/vignette-spec.md) — Uma's T12 direction brief (the spec this PR amends `palette.md` to honor).
- [`team/uma-ux/palette-stratum-2.md §2`](team/uma-ux/palette-stratum-2.md) — S2 vignette tint `#0A0404` (precedent: same warm-black sub-1.0 pattern, one-point-warmer for S1).
- [`.claude/docs/html5-export.md`](.claude/docs/html5-export.md) § "Renderer / HDR modulate clamp" — drives the sub-1.0 RGB requirement.
- PR #292 — Uma's vignette-spec.md landing.

## PR class

Orchestrator-authored-class (direction-driven cleanup). No Tess QA gate; per `orch-authored-pr-merge-needs-sponsor-ack` memory rule, leaving open for Sponsor ack OR orchestrator auto-merge once confirmed pure-amendment with no broader implications.

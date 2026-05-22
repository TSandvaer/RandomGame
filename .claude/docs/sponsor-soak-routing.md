# Sponsor soak routing — when Playwright + Tess is sufficient

This doc codifies a routing rule that emerged from the M3 Tier 3 W1 retro (PR #314 — continuous-scroll camera spike, 2026-05-22): **not every visual-class PR needs full Sponsor soak**. When the PR ships with a Playwright spec covering the mechanical surface, Tess + the spec own correctness; Sponsor's soak time is reserved for subjective-feel slices only.

This rule is **complementary** to two existing rules and does not replace either:

- **`html5-visual-verification-gate`** (orchestrator memory entry) — the *author* obligation: any tween/modulate/Polygon2D/CPUParticles2D/Area2D-state PR must self-soak HTML5 before flipping to ready-for-QA.
- **`html5-visual-gated-author-self-soak`** (orchestrator memory entry) — author MUST self-soak before claiming fix-complete on the gated PR classes.

Sponsor-soak-routing is the *Sponsor* obligation side: given that those gates are met, when does Sponsor's manual soak add signal vs. duplicate work the harness already covered?

## The split

**Mechanical correctness — Tess + Playwright spec own this:**

- Geometry / coordinate math (deadzone boundaries, clamp positions, follow-target tracking offsets).
- API contracts (`CameraDirector.set_world_bounds(...)` accepts `Rect2`; `follow_target` honours deadzone).
- Edge cases (target beyond bounds, target at bounds-corner, deadzone hysteresis on direction reversal).
- BuildInfo SHA verification.
- Universal warning gate (no `USER WARNING:` / `USER ERROR:` lines).
- `[combat-trace]` API-invocation confirmations.

If the PR ships with a spec hitting these surfaces and the spec is green on the release-build artifact, Tess's verdict carries — no Sponsor mechanical soak required.

**Subjective feel — Sponsor owns this:**

- Does the deadzone size *feel* right at the rendered framerate? (Camera too snappy / too loose?)
- Does the bounds-clamp transition read natural or jarring?
- Does the visual cadence (scroll speed, attack-anim follow-through, particle density) read as intended at human-perception speed?
- Does the room "feel cinematic" in the way the design brief implied?
- Tonal coherence (does this S2 room READ as Cinder Vaults vs S1-with-red-filter)?

The Playwright spec cannot answer these. Headless `gl_compatibility` rendering at deterministic frame intervals is fundamentally different from a real browser at the user's framerate with a human in the loop.

## How to route a soak ask

When the orchestrator is about to ask Sponsor for a soak, run this check first:

1. **Does a Playwright spec exist covering the mechanical surface?** If YES, Tess runs it and posts a verdict before any Sponsor ask.
2. **What does the spec NOT cover?** Enumerate the human-perception slice explicitly (deadzone feel, transition smoothness, cadence). This becomes Sponsor's targeted soak ask.
3. **Right-size the Sponsor ask.** Direct artifact link + 1-2 minute focused soak ("does the deadzone feel right when you walk W→E across the bounds?") — not "please soak the whole PR".

If NO spec exists yet, the right move is usually "Tess authors the spec first, then we route".

## When Sponsor soak IS the gate (not bypassable)

This rule does not collapse to "skip Sponsor soak" — it sharpens it. Sponsor soak remains the binding gate for:

- Author-soak-class PRs the author hasn't self-soaked yet (`html5-visual-gated-author-self-soak`).
- First-of-class visual surfaces (new shader, new particle system, new audio cue) where the spec cannot yet exist because the visual baseline hasn't been established.
- Tier-completion sign-offs (W1 done, W2 done, milestone-RC) — Sponsor reviews the integrated whole.
- Anything where Sponsor's domain expertise (tonal direction, design taste, aesthetic) is the deciding voice.

## Cite-of-record

PR #314 (M3 Tier 3 W1 continuous-scroll camera spike, commit `e695bd9`) shipped with `tests/playwright/specs/camera-scroll-spike.spec.ts` covering follow-target tracking, deadzone behaviour, and world-bounds clamping. Sponsor soaked the full PR (~5-10 minutes) when the spec would have covered ~80% of that surface in ~2 minutes of Tess time. The retrospective surfacing: 1-2 minutes of Sponsor subjective-feel soak (deadzone size, scroll smoothness, transition naturalness) would have been the right scope.

## Cross-references

- `team/TESTING_BAR.md` — testing-bar gates (paired tests + green CI + edge probes + Tess sign-off).
- `team/tess-qa/playwright-harness-design.md` — Playwright spec conventions, control-comparison technique, three-way classification scheme.
- `.claude/docs/html5-export.md` § "Visual-verification gate" — author obligation for `gl_compatibility` divergence-prone surfaces.
- `.claude/docs/test-conventions.md` § "Playwright headless ≠ real-browser perception" — why human-soak isn't replaceable for perception assertions.

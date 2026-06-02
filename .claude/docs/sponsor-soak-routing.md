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

## Design-vs-bug triage — investigate before dispatching a fix

A soak finding where a mob or boss "behaves wrong" may be **authored-correct-to-spec, not a code defect**. Dispatching a fix from the symptom wastes an agent cycle on code that is working as designed — and produces a PR that correctly implements the wrong objective. The orchestrator-never-codes rule means the orchestrator must NOT grep the source to settle this; the correct mechanism is an **investigation-only dispatch** (no code change, no PR) that returns a typed verdict.

**Triage protocol — verify authored intent at three independent levels:**

1. **Code-comment level.** An explicit "by design" comment or a zero-value constant with a matching comment (e.g. `move_speed_base: float = 0.0  # STATIONARY — never moves`; `velocity = Vector2.ZERO` every tick with a "rooted-to-plinth" comment; *absence* of a `move_and_slide()` call where a mobile sibling has one).
2. **Class-doc level.** The class header / `## Design` block describing the intent (e.g. `ArchiveSentinel.gd:28` "the Sentinel never CHASES").
3. **Design-brief level.** A binding design doc (`team/uma-ux/`, a `DECISIONS.md` entry, a bound ticket) naming the mechanic as deliberate and distinct from a prior-stratum precedent.

If **all three confirm intent** → the finding is a **balance/design verdict**, not a bug. Surface to Sponsor with options ("X is stationary by spec; options: A keep / B reposition-between-casts / C mobile-chase"); the director picks, the orchestrator implements the chosen revision. If the code does **not** match the spec at any level → genuine **code defect** → dispatch a fix normally.

The discriminating question: *"Is the gap between code and spec (a bug), or between spec and Sponsor's expectation (a design call)?"* Only the first warrants an immediate fix dispatch. This is the design-domain analog of the `diagnostic-traces-before-hypothesized-fixes` memory entry (the code-bug analog).

**Design-lock sequencing — design-owner brief FIRST (Pattern A).** When the chosen revision touches a design lock *owned by another persona* (Uma owns visual/tonal identity locks; Devon owns inventory/harness locks), sequence the dispatches: (1) the design-owner amends their lock + writes the revised brief, (2) that brief merges/confirms, (3) THEN the implementer is dispatched against the current spec. Do NOT dispatch the implementer in parallel against the unrevised lock — the code will be grounded in the old spec and diverge from whatever the design-owner produces.

**Worked example (S2 ArchiveSentinel soak, 2026-05-30; boss class merged in PR #374).** Sponsor soaked build `38e0ecb` (`?start_room=9&boss_hp_mult=0.2`) and reported the boss "stands still all the time — easy to kill." Investigation-only dispatch (Drew) confirmed authored-stationary at all three levels: `ArchiveSentinel.gd:329` (`move_speed_base = 0.0  # STATIONARY`), `:620-625` (`velocity = Vector2.ZERO`, "rooted-to-plinth", no `move_and_slide()` anywhere — vs `Stratum1Boss.gd:824/839/847/864` which has `_process_chase` + `move_and_slide()`), class doc `:28` ("never CHASES"), and `team/uma-ux/palette-stratum-2.md:356` ("stationary phase-shift boss, NOT a mobile melee boss"). The boss WAS aggroing + casting (player took damage) — only movement was absent, by spec. Verdict = design verdict, not bug. Sponsor chose "reposition between casts (phase-blink)"; sequencing applied — Uma amended her lock + briefed the blink (PR #381), THEN Drew implemented against it.

## Cite-of-record

PR #314 (M3 Tier 3 W1 continuous-scroll camera spike, commit `e695bd9`) shipped with `tests/playwright/specs/camera-scroll-spike.spec.ts` covering follow-target tracking, deadzone behaviour, and world-bounds clamping. Sponsor soaked the full PR (~5-10 minutes) when the spec would have covered ~80% of that surface in ~2 minutes of Tess time. The retrospective surfacing: 1-2 minutes of Sponsor subjective-feel soak (deadzone size, scroll smoothness, transition naturalness) would have been the right scope.

## Cross-references

- `team/TESTING_BAR.md` — testing-bar gates (paired tests + green CI + edge probes + Tess sign-off).
- `team/tess-qa/playwright-harness-design.md` — Playwright spec conventions, control-comparison technique, three-way classification scheme.
- `.claude/docs/html5-export.md` § "Visual-verification gate" — author obligation for `gl_compatibility` divergence-prone surfaces.
- `.claude/docs/test-conventions.md` § "Playwright headless ≠ real-browser perception" — why human-soak isn't replaceable for perception assertions.

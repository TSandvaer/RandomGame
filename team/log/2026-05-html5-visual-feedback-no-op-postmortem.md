# HTML5 visual-feedback no-op — postmortem

**Tick:** 2026-05-06 (run-032, post-`[combat-trace]`-confirm retrospective)
**Author:** Tess
**ClickUp:** the underlying functional bug ships on `86c9ncd9g` (Drew, in flight); this postmortem is the test-framework-policy artifact that closes the gap so this class of failure can never ship again.
**Status:** Open until Drew's `86c9ncd9g` fix lands + Devon's HDR + Polygon2D fixes land. This doc is the **reusable wisdom + test-bar update**, not the patch.

---

## TL;DR (5 lines)

1. **Symptom:** Sponsor's HTML5 soak on RC `f62991f` (the diagnostic build cut for `[combat-trace]`) reported zero visual feedback on hits / swings / deaths. Mobs took damage and were knocked back, but no flash / wedge / death-tween rendered.
2. **Root causes (three independent bugs, two of them platform-agnostic):** (a) **white-on-white modulate** — PR #115 hit-flash tweens parent `CharacterBody2D.modulate` from `Color(1,1,1,1)` to `Color(1,1,1,1)` and back (zero delta); the multiplicative cascade onto a child `Sprite` whose own modulate is non-white means even a notional delta wouldn't paint the way the spec intended. **Latent since PR #115 merged 2026-05-03.** (b) **HDR clamp on web** — Devon's `gl_compatibility` HTML5 export clamps `Color(1.4, 1.0, 0.7, 1)` to `Color(1.0, 1.0, 0.7, 1)`, killing the player ember-flash punch. (c) **Polygon2D wedge invisibility** — the swing-wedge Polygon2D doesn't render in `gl_compatibility` HTML5 export with the current vertex layout / z-index combination.
3. **Why tests didn't catch it:** the paired-test bar in PR #115 + #122 asserted `tween_valid == true`, `tween.is_running()`, and constant-equality (e.g. `HIT_FLASH_HOLD == 0.020`). Every assertion was true. None asserted **observable visual delta** — that target color differs materially from rest, that the modulate landed on the actually-drawn node, or that pixels under the affected region changed between frames. Headless GUT with `--headless` skips the framebuffer entirely, so even a screenshot-diff approach wouldn't have surfaced it under our default test runner.
4. **Remediation:** Drew owns the white-on-white functional fix (`86c9ncd9g`); Devon owns the HDR + Polygon2D fixes; this PR ships the **policy** — `TESTING_BAR.md` "Visual primitives — observable delta required" section + post-mortem entry — so future visual-feedback PRs can't repeat the gap.
5. **Reusable lesson:** **"tween liveness ≠ visible flash."** When a test exercises a visual primitive, asserting "the tween fired" is necessary but **insufficient**. The test must also assert (i) target ≠ rest, (ii) the modulate lands on the visible draw target (not a parent whose child overrides it), and (iii) where feasible, the pixels actually change. Pair these with **HTML5 visual-verification** for the renderer-specific failure modes that headless rendering can't surface.

---

## Symptom

**Sponsor's report (2026-05-06, HTML5 soak on `f62991f`):**

- Combat lands — mobs visibly knocked back on hit, HP decreases, room eventually clears once enough mobs die (after the PR #136 functional safety-net).
- **Zero visual feedback rendered.** No mob hit-flash. No mob death-tween (mob just disappears via the safety-net `SceneTreeTimer` from PR #136). No swing-wedge from the player. No player ember-flash. No ember-burst on death. No boss-shake on climax.
- `[combat-trace]` console output (per Drew's PR #136 diagnostic instrumentation) confirmed:
  ```
  [combat-trace] Grunt._play_hit_flash | tween_valid=true rest=(1.00,1.00,1.00)
  ```
  → the tween fires, with `rest_color = (1,1,1)` and target `(1,1,1)` — a literal no-op even before the parent/child cascade is considered.

**User-facing impact:** **HIGH.** Combat is functionally working but cosmetically dead. Sponsor's M1 acceptance criterion #4 ("combat reads on-screen") fails. Mid-soak break-out is the M1-blocker that triggered Uma's `combat-visual-feedback.md` spec in the first place; we shipped that spec's implementation but the implementation itself has been a no-op since merge.

---

## Reproduction steps

**Pre-fix repro (the bug in production — confirmed `[combat-trace]` evidence on `f62991f`):**

1. Trigger HTML5 release build: `gh workflow run release-github.yml --ref main` on `f62991f` (or any post-PR-#115 SHA).
2. Download artifact `embergrave-html5-f62991f.zip`, extract, serve via `python -m http.server` (or the standard sponsor-soak host).
3. Open in browser with F12 DevTools → Console open BEFORE clicking Run.
4. Click Run, attack a mob (LMB), observe:
   - Mob is knocked back (functional fix from PR #109 working).
   - Mob HP decreases (Hitbox + take_damage working).
   - **No visible flash.** Mob looks identical to its rest state during the 80 ms hit-flash window.
   - `[combat-trace] Grunt._play_hit_flash | tween_valid=true rest=(1.00,1.00,1.00)` appears in console — tween is firing, rest color is white, target color is white.
5. Same observations for player swing-wedge (no orange triangle paints), player ember-flash (no luminance bump), death-tween (mob just vanishes).

**Why headless tests did not repro:** the existing GUT suite asserts the tween's existence + duration + state-engine contracts (e.g. `mob_died` fires at frame-1 of `_die`). It does **not** sample the framebuffer or compare modulate values against rest. `godot --headless` skips the renderer entirely; `--rendering-driver opengl3` headed-mode would paint the framebuffer but is not in our default CI matrix.

**Why desktop manual-soak did not repro earlier:** the desktop `forward_plus` renderer doesn't HDR-clamp, so the player ember-flash worked there. The white-on-white mob hit-flash was equally invisible on desktop — but Sponsor's pre-PR-#136 desktop sessions were short and the white flash, even if it had landed correctly, is 80 ms. The combination of (a) flash being absent and (b) sessions being short meant the gap wasn't surfaced as "no flash" — it was filed as "combat is hard to read" and we attributed it to placeholder fidelity. Sponsor's HTML5 soak with explicit instrumentation finally pinned it.

---

## Root cause

**Three independent bugs surfaced together; only one of them is what this postmortem and policy update is centrally about.**

### 1. White-on-white modulate cascade (mob hit-flash) — platform-agnostic, latent since PR #115

The mob hit-flash code in `Grunt`, `Charger`, `Shooter`, `Stratum1Boss` (PR #115) tweens the parent `CharacterBody2D`'s `modulate`:

```gdscript
# (paraphrased, from the PR #115 implementation)
var rest_modulate = self.modulate           # parent CharacterBody2D modulate at rest = Color(1,1,1,1)
var tween = create_tween()
tween.tween_property(self, "modulate", Color(1,1,1,1), HIT_FLASH_IN)   # 20ms → white
tween.tween_interval(HIT_FLASH_HOLD)                                    # 20ms hold
tween.tween_property(self, "modulate", rest_modulate, HIT_FLASH_OUT)    # 40ms ← white
```

**Bug 1a (the surface bug):** `rest_modulate` is the parent's current modulate, which **defaults to `Color(1,1,1,1)`** on every mob scene. Tweening from white to white and back produces zero delta. Even with a perfect renderer, this is a no-op.

**Bug 1b (the cascade trap, deeper):** `modulate` in Godot **cascades multiplicatively** from parent to children — the rendered color of a child node is `child.modulate × parent.modulate × …` up the tree. The intent of the spec ("flash the mob white") was to flash the **visible Sprite/ColorRect that's drawn**, not the parent CharacterBody2D (which has nothing to draw — it's the physics body root). Even if the parent-side tween had used a non-white target color, the cascade onto a child whose own modulate is non-white (e.g. a tinted enemy sprite) would multiply and not produce the spec-intended flash. The mob-side cue should have been applied to the visible-draw child (Sprite2D / ColorRect / Polygon2D body), not the parent CharacterBody2D.

**Why latent since PR #115:** the paired tests in `test_combat_visuals.gd` asserted constants (`HIT_FLASH_HOLD == 0.020`), tween liveness (`tween_valid == true`), and contract invariants (`mob_died` fires at frame-1). All true. None asserted observable color delta or that the modulate change applied to the visible-draw target. The bug shipped clean through Tess's PR #115 sign-off because the test-bar didn't have the rule yet.

### 2. HDR clamp on `gl_compatibility` HTML5 (player ember-flash) — platform-specific

The player ember-flash in PR #122 tweens `Color(1.4, 1.0, 0.7, 1)` (slight luminance boost). The `gl_compatibility` web export clamps any channel above 1.0 to 1.0, producing `Color(1.0, 1.0, 0.7, 1)` — a barely-visible warm tint, not the intended punch. **This is Devon's lane** (HTML5 renderer-specific fix); flagged in the post-mortem for completeness because it stacks with bug 1 to make combat read as completely flat on web.

### 3. Polygon2D swing-wedge invisibility on `gl_compatibility` HTML5 — platform-specific

The swing-wedge Polygon2D in PR #122 doesn't paint visibly under `gl_compatibility` HTML5 with the current `z_index = -1 (behind player Sprite ColorRect)` configuration. Likely a renderer-specific layer-ordering bug or a Polygon2D vertex/transform issue that doesn't surface under `forward_plus` desktop. **Also Devon's lane.**

**Why we treat bug 1 as the load-bearing test-framework lesson:** bugs 2 and 3 are platform-specific renderer bugs that need HTML5 visual verification (already a memory rule via `html5-visual-verification-gate.md`). Bug 1 is the **test-framework gap** — it would have failed on **every platform** if anyone had asserted observable color delta, and the policy fix is generalizable to every visual primitive across the codebase, not just HTML5. That's the lesson worth codifying.

---

## Why tests didn't catch it

The PR #115 test suite (`tests/test_combat_visuals.gd`) and PR #122 test suite (`tests/test_player_visual_feedback.gd`) together asserted, for the visual-feedback layer:

- Tween validity: `assert_true(tween.is_valid())` after `_play_hit_flash` is called.
- Tween liveness: `assert_true(tween.is_running())` for the duration window.
- Constant equality: `assert_eq(Grunt.HIT_FLASH_IN, 0.020)`, `assert_eq(Grunt.HIT_FLASH_HOLD, 0.020)`, `assert_eq(Grunt.HIT_FLASH_OUT, 0.040)`.
- Cross-mob constant equality: `assert_eq(Grunt.HIT_FLASH_IN, Charger.HIT_FLASH_IN, ...)`.
- Tween-end behavior: `await get_tree().create_timer(0.10).timeout; assert_true(node.modulate == rest_modulate)`.
- Critical contract: `mob_died` emits at frame-1 of `_die`, BEFORE the tween starts (load-bearing for room-clear logic).

**What the suite did NOT assert:**

- That the tween's **target color** is materially different from the **rest color** (the tween's start). White → white tweens trivially pass every "is_running" / "is_valid" / "modulate ends at rest" assertion above.
- That the modulate change is applied to the **visible-draw node** (the Sprite2D / ColorRect / Polygon2D that actually paints), not to a parent CharacterBody2D whose draw is nominal.
- That, post-tween-fire mid-flight, the **rendered framebuffer pixels under the mob region** are different from a baseline frame captured pre-tween. (This is the highest bar; not always feasible in headless CI; explicitly noted as "feasible / aspirational" in the policy update.)

**The lesson:** "tween fires" is necessary but **not sufficient**. A passing tween-liveness assertion can mask a no-op visual.

---

## Remediation

**Already in flight:**

- **Drew, `86c9ncd9g`** — fixes the white-on-white mob hit-flash. Expected approach: change tween target to a saturating color (e.g. `Color(2.0, 2.0, 2.0, 1.0)` or palette-driven flash color) **and** apply the modulate to the visible-draw child (Sprite2D / ColorRect inside the CharacterBody2D), not the parent. Drew authors the paired test for his own fix per the new policy this PR adds — the test must assert `target_color != rest_color` and that the modulate landed on the visible-draw target.
- **Devon (HTML5-specific)** — HDR clamp fix for player ember-flash on `gl_compatibility` (likely tween a sub-1.0 ember tint instead of the current `1.4` luminance boost, or switch to additive overlay) + Polygon2D wedge visibility fix on web export.

**This PR (Tess, `tess/observable-visual-delta-rule`):**

- Adds **"Visual primitives — observable delta required"** section to `team/TESTING_BAR.md` codifying the policy.
- Appends an entry to `team/log/process-incidents.md` linking to this postmortem (so Priya's normalized incident log captures the pattern).
- This postmortem itself in `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`.
- (Optional, evaluated below) addendum to `team/orchestrator/dispatch-template.md` so the rule is surfaced in every visual-work brief.

**Future hardening (deferred to a separate dispatch — out of scope here):**

- A **renderer-painting CI lane** — run a subset of visual tests under `--rendering-driver opengl3` (headed mode in xvfb on Linux runners) so framebuffer-sample assertions become tractable. This is non-trivial CI work and Devon's lane; flagged here for the next CI hardening sweep.
- A **HTML5 render-driver smoke** — extend the existing `team/tess-qa/html5-rc-audit-*` pattern to spot-check visual primitives on every release artifact, not just the boot scene. Likely a Tess + Devon collab on a follow-up `qa(...)` ticket.

---

## Reusable lesson

**"Tween liveness ≠ visible flash."**

Whenever a test exercises a tween, modulate change, color/alpha animation, or any other visual primitive:

1. Assert `target ≠ rest` (observable delta exists at the tween-property level).
2. Assert the visual-property change lands on the **visible-draw node**, not an ancestor whose child overrides it (modulate cascades multiplicatively).
3. Where feasible, sample the rendered framebuffer at the affected region and compare pixel deltas across the tween window. Headless rendering with `--headless` does not paint the framebuffer; this assertion class wants either a `--rendering-driver opengl3` headed CI lane or a defer-to-manual-HTML5-soak fallback explicitly noted in the test.

Any one of these three would have caught the white-on-white bug. The first one (target ≠ rest) is the cheapest and lands as a one-liner `assert_ne(target_color, rest_color)` in every visual-primitive test. The third (framebuffer pixel-delta) is the highest bar and the most generalizable, and is where the next CI hardening pass should head.

This generalizes to **every visual primitive in the codebase**, not just hit-flash:

- Tweens on `modulate`, `scale`, `rotation`, `position` — assert target ≠ rest.
- Color/alpha animations on UI panels — assert target ≠ rest, applied to the visible draw target.
- Particle bursts (`CPUParticles2D`) — assert `emitting == true` AND `amount > 0` AND particles actually spawn during the lifetime window.
- ColorRect / Polygon2D color changes — assert `(modulate * self_modulate * color)` net visible color delta, not just one of the three.

---

## References

- **PR #115** — `feat(combat): mob-side visual feedback — hit-flash + death tween + boss particles` (Drew, 2026-05-03 squash-merge `0802d37`-or-thereabouts). The PR that shipped the latent white-on-white bug.
- **PR #122** — `feat(combat): player-side visual feedback — swing wedge + ember-flash on attack` (Devon, merged 2026-05-03 19:04 UTC). Sister PR with the HDR-clamp + Polygon2D-invisibility renderer-specific bugs.
- **PR #136** — `fix(combat): decouple mob queue_free from death tween + HTML5 combat trace` (Drew, merged 2026-05-06). The diagnostic build that surfaced the `[combat-trace]` evidence + the functional safety-net that unblocks combat even with broken visuals. Drew's PR body explicitly flagged the white-on-white modulate as "a separate platform-agnostic visual bug that the trace will not surface — flagged here for the follow-up PR."
- **`team/uma-ux/combat-visual-feedback.md`** — Uma's spec, §1 (player ember-flash) + §2 (mob hit-flash). The spec is correct; the implementation drifted (white-target instead of saturating-color, parent-modulate instead of child-modulate).
- **Sponsor's `[combat-trace]` capture** — `[combat-trace] Grunt._play_hit_flash | tween_valid=true rest=(1.00,1.00,1.00)` on RC `f62991f`, 2026-05-06.
- **ClickUp `86c9ncd9g`** — Drew's white-on-white functional fix (in flight).
- **Orchestrator memory `html5-visual-verification-gate.md`** — pre-existing rule that Tween/modulate/Polygon2D/CPUParticles2D PRs need explicit HTML5 verification before merge. This postmortem strengthens that rule with the **observable-delta** addendum at the test-bar level.
- **Orchestrator memory `product-vs-component-completeness.md`** — the broader pattern: passing tests ≠ shipping product. Hit-flash tests passed; visual feedback didn't ship. Same family of failure as the M1 Main.tscn-stub miss.

---

## Caveat — fix-forward vs. retroactive paired test

Drew's `86c9ncd9g` will ship with a paired test that exercises the new policy (target ≠ rest + visible-draw-target check). The **already-merged** PR #115 + #122 test files (`test_combat_visuals.gd`, `test_player_visual_feedback.gd`) won't be retro-fitted under this dispatch — that's Drew's lane in his fix PR, not Tess's lane in this policy PR. Tess's review of Drew's `86c9ncd9g` will gate on the new tests landing per the new bar (this is captured in Tess's "out of scope" line in this dispatch and will be re-checked on Drew's PR review).

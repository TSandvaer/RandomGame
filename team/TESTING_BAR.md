# Testing Bar

**Sponsor directive (2026-05-02):** "I want you to use a lot of time testing, I don't want to debug and return findings all the time."

Translation: by the time anything reaches the Sponsor for sign-off, it must already have been hammered thoroughly. Sponsor's role is **acceptance**, not bug-finding. If the Sponsor finds a bug during sign-off, the team failed its testing bar.

This document is binding on every role. Everyone reads it. Tess enforces it.

---

## Definition of Done (DoD) — applies to every feature task

A task is **not** "complete" until ALL of the following:

1. **Code or content lands** — feature works end-to-end on the developer's machine (or in CI for headless features).
2. **Unit tests exist** — for any system with non-trivial logic (state machines, save/load, combat math, loot rolling, level progression). Use GUT in Godot, run via `--script gut/cmdline.gd` headless. Aim for **the meaningful behaviors** to be tested, not 100% line coverage. If a feature genuinely cannot be unit-tested (pure visual / scene composition), say so explicitly in the commit message.
3. **CI green** — GitHub Actions workflow passes on the commit. No "I'll fix CI later." No skipping flaky tests — fix or quarantine with a follow-up ClickUp task.
4. **Integration check vs. M1 acceptance criteria** — if the feature touches one of the 7 M1 acceptance criteria in `team/priya-pl/mvp-scope.md`, the corresponding test from Tess's plan (`team/tess-qa/m1-test-plan.md`) must pass. Run it. Document the result in the ClickUp task description before flipping to `ready for qa test`.
5. **Tess signs off** — Tess (or her agent on the next heartbeat) flips the task from `ready for qa test` to `complete`. Devs do **not** flip their own features to `complete`. The status flow is mandatory: `to do` → `in progress` → `ready for qa test` → `complete`. Skipping `ready for qa test` is forbidden for feature work.
6. **Self-Test Report posted (UX-visible PRs)** — for any PR touching a player-visible surface (scene tree, UI, visual feedback, audio cue, input affordance, save format, level content), the **author posts a Self-Test Report comment on the PR before Tess's review begins**. Tess's review starts from the report, not from a cold-read of the diff. If the report is missing on a UX-visible PR, Tess bounces it immediately — don't burn review budget cold-reading a UX diff. Categories that REQUIRE the report: `feat(integration|ui|combat|level|audio|progression|gear)`, `fix(ui|combat|level|audio|integration)`, `design(spec)` when consumed by an in-flight `feat` PR. Format + headless fallback in `team/GIT_PROTOCOL.md` § "Self-Test Report (UX-visible PRs)" and orchestrator memory `self-test-report-gate.md`. Categories that do NOT require it (CI green is sufficient): `chore(ci|repo|build|state|orchestrator|planning)`, `docs(team|scope)`, `test(...)`, `.tres`-only data refactors.
7. **Edge cases probed** — Tess explicitly tests at least three failure modes per feature (rapid input, mid-action interrupt, save/load round-trip across the feature's state, OS-level interruption like tab-blur for HTML5). Findings either land as a fix in the same task or as a follow-up `bug(...)` task with severity.

Exempt from #2, #4, #5, #6: pure documentation tasks (`docs(...)`, `design(spec): ...` not consumed by an in-flight feat). They still need #1 and #3.

---

## Product completeness ≠ component completeness

Component-level test coverage and CI-green status are NOT proof the product is shippable. A feature is not "complete" until it is **instantiated in the entry-scene's runtime tree** and reachable through the same path the player uses.

- **CI green + paired tests** = component-complete. The unit/integration tests prove the system works in isolation.
- **Component instantiated in the play surface** (entry scene loads it; it appears in the runnable build artifact) = product-complete.
- **Sponsor sign-off requires product-complete**, not component-complete.

**Practical applications:**

1. Treat any agent report of "feature-complete" as **component-complete only** until you have independently verified the integration surface — read the entry-scene file (`scenes/Main.tscn` or whatever `run/main_scene` points at) and confirm the new system is instantiated there or in a scene that Main.tscn loads.
2. Watch for "(Note, not blocking)" or similar throwaway flags in QA reports. If any reviewer writes "X is not yet wired into Main.tscn" or "Main.tscn is still a stub," that is a P0 flag, not a side note. Elevate to a gating ticket.
3. Don't dispatch features faster than you integrate them. If 5 subsystems land but `Main.tscn` hasn't been touched in those 5 PRs, you are accumulating integration debt. Stop feature dispatch and dispatch an integration pass before claiming any milestone-level "complete."
4. For HTML5/web specifically: **the build artifact is the truth.** Don't claim "shippable" until you (or an agent) has triggered a release build, downloaded the artifact, extracted it, and either visually inspected the entry scene or driven an end-to-end integration test through the same path the player uses.
5. Tickets that say "implement the panel" are NOT the same as "wire the panel into the game." Make wiring explicit on every UI/system ticket — in the dispatch brief, in the acceptance criteria, in the Done clause.

**Backstory:** the M1 Main.tscn-stub miss — ~30+ PRs of "feature-complete" claims while the runnable build was a week-1 boot stub — is the cautionary tale. CI passed; tests passed; the artifact was a player square on a black banner. The Sponsor's first 2-minute soak exposed the gap. See orchestrator memory `product-vs-component-completeness.md` for the full incident write-up.

**Mantra:** components pass tests. Products integrate. Don't conflate them.

---

## Visual primitives — observable delta required

When a test exercises a tween, modulate change, color/alpha animation, particle burst, or any other visual primitive, asserting `tween.is_valid()` / `tween.is_running()` / "the tween fires" is **necessary but insufficient**. A passing tween-liveness assertion can mask a no-op visual. The test MUST also assert one or more of the following, at the strongest tier feasible for the primitive under test:

1. **Tier 1 (mandatory, cheapest) — target ≠ rest.** Assert that the tween's target value is materially different from the rest/start value. For modulate flashes: `assert_ne(target_color, rest_color)`. For scale tweens: `assert_ne(target_scale, rest_scale)`. White → white is a tween, but it is not a *visible flash*. A one-liner that catches the entire class of white-on-white / no-op-target bugs.

2. **Tier 2 (mandatory for parented modulate / cascading visual properties) — applied to the visible-draw node.** Modulate cascades multiplicatively (`rendered = child.modulate × parent.modulate × ...`). For modulate tweens on parented nodes: the test must verify the modulate is applied to the *visible-draw* node (the Sprite2D / ColorRect / Polygon2D that actually paints), not to a parent CharacterBody2D / Node2D whose draw is nominal and whose child has its own non-white modulate. If the spec says "flash the mob white" and the implementation tweens the parent body's modulate while the child sprite has modulate `Color(0.8, 0.5, 0.3, 1)`, the cascade produces `0.8 × 1.0 = 0.8` on the red channel — barely a flash. Pin the modulate-target assertion to the actual visible-draw node.

3. **Tier 3 (aspirational, where feasible) — framebuffer pixel-delta.** Sample the rendered framebuffer at the affected region (`Viewport.get_texture().get_image()`) and compare pixel deltas across the tween window. The strongest assertion class: pixels actually changed where the spec says they should. **Caveat — headless rendering does not paint the framebuffer.** Godot's `--headless` flag (the default in our GUT CI) skips the renderer entirely; pixel-delta tests run under `--headless` will trivially "pass" with all-zero pixels. For framebuffer assertions to be meaningful, the test must run under `--rendering-driver opengl3` headed mode (e.g. via xvfb on Linux runners). This is non-trivial CI work; until a renderer-painting lane lands, framebuffer assertions are deferred and the Tier 1 + Tier 2 assertions are the binding floor.

4. **HTML5-specific — pair with the HTML5 visual-verification gate.** Tweens, modulates, Polygon2D, and CPUParticles2D PRs are subject to the pre-existing HTML5 visual-verification rule (orchestrator memory `html5-visual-verification-gate.md`). Headless GUT tests are insufficient to catch renderer-specific failure modes (HDR clamp on `gl_compatibility`, Polygon2D z-index drift, etc.). The Self-Test Report must capture an actual HTML5 export soak before Tess approves; merging a tween/modulate PR on headless-CI-green alone is not within the bar.

**Why this rule exists:** PR #115 (mob hit-flash) and PR #122 (player swing-wedge + ember-flash) both shipped tween-based visual feedback whose paired tests asserted `tween_valid == true`, constant equality, and tween-end behavior — all green. None asserted observable color delta or visible-draw-target landing. **The mob hit-flash tween was a literal no-op** (white target on white rest, applied to a parent CharacterBody2D whose child Sprite has a non-white modulate that cascades the flash away). The bug shipped 2026-05-03 and was only caught 2026-05-06 by Sponsor's HTML5 `[combat-trace]` soak — three days of "feature-complete" status while the on-screen reality was that combat had no visual feedback at all.

**Concrete examples — Tier 1 one-liner additions:**

```gdscript
# In test_combat_visuals.gd (Drew's lane, applies to mob hit-flash):
func test_grunt_hit_flash_target_color_differs_from_rest():
    var g = _spawn_grunt()
    var rest = g.modulate
    var target = Grunt.HIT_FLASH_TARGET_COLOR  # the new constant Drew exposes for the fix
    assert_ne(target, rest, "hit-flash target color must differ from rest — white-on-white is a no-op")

# In test_player_visual_feedback.gd (Devon's lane, applies to player ember-flash):
func test_player_ember_flash_target_tint_differs_from_rest():
    var p = _spawn_player()
    var rest = p.modulate
    var target = Player.EMBER_FLASH_TINT  # Color(1.4, 1.0, 0.7, 1) on desktop, sub-1.0-clamped fallback on web
    assert_ne(target, rest, "ember-flash target tint must differ from rest — clamp-to-rest is a no-op")
```

**Concrete examples — Tier 2 visible-draw-target check:**

```gdscript
# In test_combat_visuals.gd:
func test_grunt_hit_flash_applied_to_visible_sprite_not_parent_body():
    var g = _spawn_grunt()
    g.take_damage(1, Vector2.ZERO, null)
    # The visible-draw target is the child Sprite2D / ColorRect, not the CharacterBody2D itself.
    var visible_target = g.get_node("VisibleSprite")  # whatever the project convention is
    assert_eq(visible_target.modulate, Grunt.HIT_FLASH_TARGET_COLOR,
        "hit-flash modulate must land on the visible-draw node; parent-only is cascade-trapped")
```

**What this rule does NOT require:**

- It does not require Tier 3 (framebuffer-pixel-delta) on every visual test today. Tier 3 is aspirational pending a renderer-painting CI lane.
- It does not require retro-fitting already-merged tests. Existing `test_combat_visuals.gd` and `test_player_visual_feedback.gd` are owned by Drew's `86c9ncd9g` fix PR + Devon's HDR/Polygon2D fix PRs respectively — they will land the Tier 1 + Tier 2 assertions in the same PR as their functional fix, per `tests-with-features` rule above.
- It does not block `chore` / `docs` / `test`-only PRs that don't introduce new visual primitives.

**See also:**

- `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md` — full incident write-up.
- `team/log/process-incidents.md` — pattern-watch entry for this incident.
- Orchestrator memory `html5-visual-verification-gate.md` — the renderer-side complement to this rule.

---

## Pre-soak gates — catch findings BEFORE Sponsor soaks (Sponsor directive 2026-06-02)

**Sponsor directive (2026-06-02):** *"can you do more to catch things before I soak, so i dont have to soak and re-soak so much?"*

**Root cause of the re-soak churn** (from project history): (a) agents declare fix-complete on green CI without real-browser verification — headless GUT/Playwright ≠ real-browser perception (PR #291 bit twice this way); (b) Sponsor-soak handoffs carry speculated rather than code-verified instructions, and a wrong URL-param or wrong step burns a whole soak round (PR #328, PR #391). These gates put more catch-points BEFORE the Sponsor sees a build.

These three gates are ADDITIVE to the existing visual-verification gate, author-self-soak gate, and sponsor-soak-routing rule above — they do not replace them. They are the Sponsor-selected subset (2026-06-02); an author-self-soak HARD-gate was explicitly NOT selected and is NOT part of this bar.

### Pre-soak Gate 1 — Tess independent release-build verification (visual-class PRs)

**Rule.** For any PR in the HTML5-visual-gated class (`Tween` / `CanvasItem.modulate` / `Polygon2D` / `CPUParticles2D` / `Area2D`-state mutations / `ColorRect` with HDR colors / new `gl_compatibility`-rendered primitive / z-index ordering / TileMap-scroll), Tess performs an **INDEPENDENT verification pass on the real release-build artifact** before posting APPROVE — she does NOT approve on the author's CI-green + author's Self-Test screenshots alone. Tess's verdict is grounded in evidence she generated against the artifact, not in trust of the author's claims.

**What "independent verification" means concretely:**

1. Tess fetches the release-build artifact for the PR HEAD SHA (the same artifact a Sponsor soak would use), confirms `[BuildInfo]` SHA matches PR HEAD, and exercises the gated visual surface herself.
2. The QA review comment states the artifact run-id + SHA Tess verified against, and what she observed on the gated surface (not just "author's screenshots look right").

**Escape-clause-aware (per `.claude/docs/html5-export.md` § "Visual-verification escape clause").** If Tess's environment cannot drive an interactive browser (CLI / container / headless-only), she does NOT silently skip:

- She runs the **Playwright spec(s) covering the surface against the release-build artifact** (trace + config + spawn-position + universal-warning-gate coverage), AND spot-checks via Playwright screenshot captures where feasible.
- She **honest-discloses in the QA comment which surface she verified by which means**: "verified mechanically via Playwright spec X against artifact `<run-id>`; interactive-perception verification of <surface> deferred to Sponsor per the escape clause — probe targets: <list>." This is the per-surface enumeration shape, not a blanket "ran Playwright."
- Per `team/TESTING_BAR.md` § "Auto-memory: `html5-visual-gated-author-self-soak`": Playwright headless proves "spawned with the right config," NOT "a human will see it." Tess MUST NOT upgrade a headless-screenshot pass into a "Sponsor will see it" APPROVE — that perception slice routes to Sponsor with named probe targets.

**Why this is a NET catch-point, not duplicate work.** The author-self-soak gate (above) is the author proving due-diligence. Gate 1 is a SECOND independent party reproducing against the artifact before it reaches the Sponsor — the failure mode it closes is "author's self-soak missed it / author's screenshot was at a sub-perceptual timing window / author claimed renderer-safe-primitive exemption." PR #291's two Tess-APPROVE-then-Sponsor-overturn iterations are the cautionary tale: Tess approved on the author's GUT+CI evidence twice; an independent artifact pass (interactive OR honest-disclosed Playwright-on-artifact + Sponsor-routed perception slice) would have caught the divergence one round earlier.

**Cross-reference — this composes with the orchestrator merge-gate** (`team/GIT_PROTOCOL.md` § "Orchestrator merge-gate verification"): that gate verifies the Self-Test Report's HTML5 section is present at merge time. Gate 1 sits earlier — at Tess's APPROVE, before the merge tool-round — and requires Tess's own artifact-grounded evidence in the QA comment.

### Pre-soak Gate 2 — verified-only Sponsor-soak instructions

**Rule.** Every Sponsor-soak handoff MUST give exact, **code-VERIFIED** steps + correct URL params. Never speculation, never pattern-completion ("CameraDirector.follow_target binds the marker so WASD must scroll"), never instructions inferred from API knowledge without confirming against the actual scene/script. A wrong step or wrong param burns an entire soak round.

This promotes orchestrator memory `soak-instruction-no-speculation` to a **hard handoff rule** binding on every soak-handoff author (the agent who self-soaks + drafts the handoff, and the orchestrator who relays it).

**What "code-verified" means for each instruction line:**

- **"Press / move / refresh to see X"** — the action must be confirmed against the actual input-handler / scene wiring (grep the binding, read the scene), OR omitted. Do not infer a control from engine-API knowledge.
- **URL params** — only params the build actually reads, with the exact value semantics confirmed against `scripts/debug/DebugFlags.gd` call-sites.
- **Expected observation** — what the Sponsor should see must trace to a real code path, not a hoped-for behavior.

**DebugFlags param discipline (per `.claude/docs/html5-export.md` § "DebugFlags URL params"):**

| Soak goal | Correct URL param | NEVER |
|---|---|---|
| S2 traversal (z1→z2→z3→boss) | `?force_descend=1` **ALONE** | combine with `start_room=9` |
| S2 boss-arena (skip traversal) | `?start_room=9` **ALONE** (pair `?boss_hp_mult=0.2` for phase-2 reach, subject to the per-boss parity gap) | combine with `force_descend=1` |

**The mutual-exclusivity gotcha:** `?start_room=9` + `?force_descend=1` together load the boss room underneath AND layer the DescendScreen overlay on top — the boss aggros and kills an idle player through the overlay. This produced a wasted soak cycle on PR #391. The params are individually documented in `DebugFlags.gd` but the interaction is NOT guarded in code; it is a caller-discipline rule that EVERY soak handoff must honor.

**Per-boss `boss_hp_mult` parity caveat.** `?boss_hp_mult=N` is NOT inherited by every boss class (`ArchiveSentinel` does not read it as of PR #380). If the soak targets a boss whose `boss_hp_mult` wiring is unconfirmed, the handoff MUST either confirm the wiring or route phase-2 reach to a `diag/*` `hp_base`-nerf artifact — never assume the param works.

**Required artifact link shape.** Every soak handoff carries the fully-resolved direct artifact download URL inline (`https://github.com/<owner>/<repo>/actions/runs/<run_id>/artifacts/<artifact_id>`) — no run-page-only references, no `<run-id>` placeholders (hard rule per orchestrator memory `sponsor-soak-artifact-links`). For spike PRs with a `diag/*` proof-scene branch, the link MUST be the diag-build artifact, not the production release-build (per `spike-soak-uses-diag-artifact-not-production`).

**Enforcement.** The "Sponsor-soak steps (code-verified)" section is now a required block in the Self-Test Report for any PR whose handoff includes a Sponsor-soak ask (see `team/GIT_PROTOCOL.md` § "Self-Test Report"). A handoff carrying any unverified/speculated step is bounced back to the author for verification before it reaches the Sponsor.

### Pre-soak Gate 3 — visual-snapshot baselines (automated layer)

**Rule (forward-looking).** Tier-3 framebuffer-level visual-regression coverage via Playwright screenshot snapshots (`toMatchSnapshot` / `toHaveScreenshot` with a pixel-diff tolerance) on key UX surfaces, so a "the equipped-glyph went tofu again" class regression is caught at CI gate time rather than at Sponsor-soak time.

This is the automated complement to Gates 1+2 (which are human/process gates). It is **scoped, not yet built** — implementation is tracked by ClickUp `86c9ufaga` ("qa(spec): visual-fidelity Tier-2 — Playwright screenshot snapshot baseline"), a later Devon/Tess task. Until that ticket lands, Tier 1 (target ≠ rest) + Tier 2 (visible-draw-target landing) per § "Visual primitives" remain the binding floor; Gate 3 is the M3 Tier-3 promotion.

### Pre-soak Gate 4 — first-of-class art aesthetic review (Uma) (Sponsor directive 2026-06-03)

**Rule.** Any **NEW first-of-class visual asset** — a tileset, a sprite, a prop set, a VFX, a boss visual, or a first application of a palette to a new surface — requires an **Uma aesthetic review of the asset rendered IN CONTEXT** before it reaches Sponsor soak or merge. "In context" means tiled / placed in a real scene at the **actual game camera zoom**, and judged against the relevant Uma direction brief (e.g. `team/uma-ux/env-art-s1-direction.md`). Uma — not QA, not the impl author, not the orchestrator — posts the aesthetic sign-off (or REQUEST CHANGES) on that in-context render.

**This gate is distinct from the other catch-points; it does not duplicate them:**

- **Not QA (Gate 1 / Tess).** Tess verifies *mechanical render-correctness* — tiles paint, no `USER WARNING`, collision perimeter intact, `[BuildInfo]` SHA matches. Aesthetics are explicitly **not QA's job**; "the tiles paint correctly" and "the tiles look good tiled across a room" are different verdicts.
- **Not the snapshot baseline (Gate 3 / `86c9ufaga`).** Visual-snapshot baselines catch **regressions** of brand-new art against an approved reference — they cannot judge "this brand-new art looks bad" on **first introduction**, because there is no approved baseline yet. Gate 4 is the first-introduction aesthetic judgment that *establishes* what a future baseline would lock.
- **Not the author's self-soak.** The author's HTML5 self-soak proves the surface renders; it is not an aesthetic sign-off by the direction-owner.

**Binding rule — judge art in context, never as isolated swatches.** Approval of an asset shown as **isolated or scaled-up swatches** (a 4×-scaled contact sheet, a single tile blown up, a sprite on a neutral background) does **NOT** constitute aesthetic sign-off. The **binding view is the in-context render at the actual game camera zoom** — tiled across a real room, placed alongside the other props, at the size and density the player will actually see. An asset that reads fine as an isolated swatch can read as a defect once tiled (the canonical failure: a tileset that looks textured at 4× but reads as **"a grid of bordered boxes"** tiled across a room at game zoom — exactly the anti-pattern Uma warned against in her own `env-art-s1-direction.md` §6.3).

**Who produces the in-context render Uma signs off on:**

- For **impl-wired assets** (a tileset/prop placed into a chunk `.tscn` by Drew/Devon): the impl author's **HTML5 self-soak screenshot** at game zoom — the same artifact the author-self-soak gate already requires — IS the in-context render. Uma reviews that screenshot against the brief.
- For **orchestrator-generated assets not yet impl-wired** (a PixelLab-generated tileset/prop before a Drew ticket exists): the **orchestrator places the asset in a throwaway test scene at game zoom** (or a `diag/*` build) and captures the in-context render. Uma signs off on THAT, not on the PixelLab contact-sheet output.

Either way, the artifact of record is the **in-context render at game zoom**, and Uma's sign-off comment names which render she reviewed.

**Why this is a NET catch-point.** The Sponsor S1 perception-soak (2026-06-03, build `aa8a30b`) caught the floor tileset reading as a grid of bordered boxes — the §6.3 anti-pattern — *after* it had cleared every prior gate: Tess's QA verified mechanical render-correctness (not aesthetics, correctly not her job); Uma, who authored the direction, never reviewed the GENERATED RESULT against her own brief; and the tiles were approved as isolated 4×-scaled swatches in a contact sheet, so the grid only became visible tiled across a room at game zoom. Gate 4 closes that exact gap: the direction-owner reviews the generated result, in context, at game zoom, before the Sponsor sees it.

---

## Load-bearing memory rules ported here for sub-agent visibility

These rules originate as auto-memory entries in the orchestrator's user-scope (`~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/`). Sub-agents do NOT auto-read auto-memory; they only see rule content when the orchestrator puts it in a dispatch brief. The M3 retrospective (2026-05-22, PR #315) found that "rule codified ≠ rule applied" was a recurring root cause (pattern P3) — sub-agents were unaware of rules that lived only in auto-memory. The fix is here: port the load-bearing rules into a doc sub-agents read at dispatch time. The auto-memory entries continue to exist as the orchestrator's reference; this is the sub-agent-facing mirror.

**How to use:** if you are a sub-agent, the rules below are binding on you regardless of whether your dispatch brief restates them. Each section begins with `Auto-memory: <memory-name>` so the lineage is preserved.

---

### Auto-memory: `html5-visual-verification-gate`

**Rule:** UX-visible PRs that touch Godot's `Tween`, `CanvasItem.modulate`, `Polygon2D`, or `CPUParticles2D` primitives MUST get an explicit HTML5-runtime verification before merge — either Sponsor confirmation on a debug build, or a debug-build with logging that traces the visual path. Headless GUT tests passing is NOT a sufficient signal for these primitives.

**Why:** PRs #115 (mob hit-flash + death-tween) and #122 (player swing-wedge + ember-flash) shipped with green headless tests + Tess sign-off. Both completely failed to render in HTML5: tweens didn't fire, modulate animations were no-ops, particles didn't spawn. Worse, PR #115 gated `mob.queue_free` on `_death_tween.finished` — when the tween hung in HTML5, mobs became functionally immortal, breaking the entire combat loop. Headless tests asserted "tween fires" not "visual change is observable"; product-vs-component completeness gap. Devon's PR #136 hot-fix (decouple queue_free from tween) restored the combat loop but the visual layer was still broken until follow-up work.

**How to apply.** When working a PR with `feat(combat)` / `fix(ui)` / `design(ux)` scope that touches Tween/modulate/Polygon2D/CPUParticles2D code paths:
- The testing-bar requires HTML5 verification, not just headless GUT.
- Require either (a) Sponsor confirms in soak before merge, or (b) ship a debug build with `[combat-trace]`-style logging that proves the visual call chain reaches the renderer.
- Tess's sign-off comment must explicitly state HTML5 verification status, not just "headless green."
- Critical functional code paths (like `queue_free` gating) must NEVER depend on a visual primitive firing — use `SceneTreeTimer` or `call_deferred` as the source of truth, with the visual tween as a parallel cosmetic path.
- Self-Test Report on UX-visible PRs touching these primitives needs an explicit HTML5 line item (not just a runtime check assertion).

**Routing — when Playwright + Tess is sufficient (PR #314 retro, 2026-05-22).** **If the PR ships with a Playwright spec covering the mechanical surface (geometry / API contracts / edge cases / BuildInfo SHA / universal-warning gate / `[combat-trace]` API-invocation confirmations), Tess + spec own correctness; Sponsor soak is the 1-2 minute subjective-feel slice only** (deadzone feel at framerate, transition naturalness, scroll cadence, tonal coherence — things headless `gl_compatibility` cannot answer). Run the routing check before asking Sponsor to soak a visual-class PR — if a spec already exists hitting the mechanical surface, Tess runs it + posts verdict first, then Sponsor's ask is right-sized to the human-perception slice. **Cite-of-record:** `.claude/docs/sponsor-soak-routing.md` (codified post-PR-#314 spike) + orchestrator memory `sponsor-soak-routing-rule.md`. **Composes with — does not replace** `html5-visual-gated-author-self-soak` (author-side burden of proof, still required) and the first-of-class / tier-completion / shader-aesthetic surfaces where Sponsor soak IS the binding gate (see `sponsor-soak-routing.md` § "When Sponsor soak IS the gate"). The routing rule sharpens the Sponsor ask; it does not collapse to "skip the soak".

This is the canonical poster-child for `product-vs-component-completeness` (below). Reference both rules together when working visual-layer surfaces.

**Cross-ref — first-of-class art also needs an Uma aesthetic review (Pre-soak Gate 4).** This gate proves the visual *renders correctly* in WebGL2; it does NOT judge whether brand-new first-of-class art *looks good* tiled/placed at game zoom. For any NEW tileset / sprite / prop set / VFX / boss visual / first palette application, also clear **Pre-soak Gate 4** (above): an Uma aesthetic review of the asset rendered IN CONTEXT at game zoom against her direction brief, never as isolated swatches. (Driver: the 2026-06-03 S1 build-`aa8a30b` floor tileset read as a "grid of bordered boxes" tiled across a room after clearing every render-correctness gate.)

---

### Auto-memory: `html5-visual-gated-author-self-soak`

**Rule:** For any PR touching an `html5-visual-verification-gate` class surface (CPUParticles2D, tween modulate, Polygon2D, ColorRect with HDR colors, Area2D state mutations, z-index ordering, shape outlines via `_draw()`, any new `gl_compatibility`-rendered visual primitive), the **authoring agent** MUST self-soak the actual HTML5 release-build in an incognito browser (DevTools F12 console open) before posting the Self-Test Report and claiming fix-complete.

**GUT-green + CI-green are NECESSARY but NOT SUFFICIENT.** Headless GUT and the release-build CI step do not exercise the `gl_compatibility` WebGL2 pipeline; they exercise the engine's import + headless paths only. Bugs that manifest only on `gl_compatibility` (HDR clamp, Polygon2D rendering quirks, z=0 same-z occlusion, shader compat, particle emission semantics) are invisible to those two surfaces. The only surface that catches them is an actual browser running the release-build.

**Empirical precedent — PR #291 (2026-05-21).** Drew authored T5+T6+B3+B4 fixes. Two consecutive iterations were both APPROVED by Tess based on GUT-green + CI-green. Both were Sponsor-soaked in HTML5 incognito — and BOTH reported that T6 aftershock was invisible AND B3 slam-animation was still kicking the wrong frames. Drew's pattern in both iterations: empirical diagnosis from desktop builds + diagnostic-trace confidence + GUT paired tests covering the code paths. Tess sign-off on the test layer. **No actual browser-side verification by the author.** The gl_compatibility-runtime divergence bit twice. Sponsor verbatim 2026-05-21: *"prevent claiming fix-complete on GUT+CI alone."*

**How to apply — for AUTHORING agents.**

1. **Before posting Self-Test Report v1**, build the release artifact: `gh workflow run release-github.yml --ref <branch>` → wait for green → `gh api repos/<owner>/<repo>/actions/runs/<run-id>/artifacts` → download.
2. **Extract to a fresh empty folder** (per service-worker cache trap — never reuse a previous soak folder).
3. **Serve locally**: `python -m http.server 8080` (or `py -m http.server 8080` on Windows).
4. **Open in incognito** browser with DevTools F12 console open.
5. **Verify `[BuildInfo]` SHA** matches the branch HEAD SHA.
6. **Reach the gated surface and exercise it.** For combat: trigger the boss/mob behavior under test. For UI: open the panel + interact. For audio: enter the room and listen.
7. **Capture evidence**: screenshot, console log paste, or trace-line capture proving the visual behavior matches the design intent.
8. **Then post the Self-Test Report** with a "HTML5 author-self-soak" section including the evidence captured.

**Burden of proof for infeasibility.** Hand-waved infeasibility claims are not acceptable. Before claiming "cannot be done headless," demonstrate failure of three approaches in order: (a) Playwright input simulation, (b) existing `[combat-trace]` / debug hook in the codebase, (c) new debug-only URL param to bypass the trigger. Only if all three fail with concrete documented failure modes is "infeasible" an acceptable claim. Drew's PR #291 v6 empirical precedent established that Playwright-screenshot capture from a CLI agent IS feasible for HTML5-class surfaces on this codebase.

**CRITICAL — Playwright headless ≠ real-browser perception.** Playwright headless screenshots prove "particles spawned with the right config." They do NOT prove "a human will see them in real-time motion." Self-Test Report claims must be honest: cite what Playwright proves (trace + config + spawn position) and route visibility-of-effect verification to Sponsor interactive soak. Authors MUST NOT claim "Sponsor will see it" from Playwright headless evidence alone.

---

### Auto-memory: `self-test-report-gate`

**Rule:** Any PR that touches a **player-visible surface** (scene tree, UI, visual feedback, audio cue, input affordance, save format, level content) MUST include a Self-Test Report comment from the author BEFORE Tess reviews. Tess's review starts from the report, not from a cold-read of the diff.

**Categories that REQUIRE the Self-Test Report:**
- `feat(integration)`, `feat(ui)`, `feat(combat)`, `feat(level)`, `feat(audio)`, `feat(progression)`, `feat(gear)`
- `fix(ui)`, `fix(combat)`, `fix(level)`, `fix(audio)`, `fix(integration)`
- `design(spec)` only when the spec is consumed by an in-flight `feat` PR (otherwise design is paper-only)

**Categories that do NOT require it (CI green is sufficient):**
- `chore(ci|repo|build|state|orchestrator|planning)`
- `docs(team|scope)`
- `test(...)` (test-only PRs)
- `.tres`-only data refactors

**Why:** The M1 Main.tscn-stub miss (~30 PRs of "feature-complete" claims while the runnable build was a week-1 boot stub) would have been caught on the first PR if every author had to point at the actual playable surface. The first time someone tried that and saw "Embergrave — boot OK + Player square," the entire team would have realized Main.tscn was unwired. This rule is the process artifact that operationalizes `product-vs-component-completeness` (below).

**How to apply.** After `gh pr create`, post a PR comment with the Self-Test Report. Full format in `team/GIT_PROTOCOL.md` § "Self-Test Report (UX-visible PRs)" — includes build artifact SHA + scene path + verification method + AC walkthrough + side-effect inventory + cross-lane integration check + open concerns. **If the report is missing on a UX-visible PR, Tess bounces immediately** — don't burn review budget cold-reading the diff.

**Headless-environment fallback:** if the agent has no browser binary (GUT-only environment), the Self-Test Report uses `godot --headless` to load the actual entry scene + drive the play loop programmatically. The verification section notes "verified via headless integration test, no browser repro available — Sponsor's interactive soak is the final gate." For HTML5-visual-gated surfaces, this fallback is composed with the author-self-soak burden of proof above (try Playwright input simulation first).

---

### Auto-memory: `testing-bar`

The full Definition of Done above (§ "Definition of Done (DoD)") IS the codified testing-bar rule — this section is intentionally a back-pointer to confirm alignment.

**Rule (one-liner):** by the time anything reaches the Sponsor for sign-off, it must already have been hammered thoroughly. Sponsor's role is acceptance, not bug-finding. If the Sponsor finds a bug during sign-off, the team failed its testing bar.

**Why:** Sponsor's explicit directive 2026-05-02: *"I want you to use a lot of time testing, I don't want to debug and return findings all the time."*

**How to apply.** Every feature task includes: paired GUT tests in the same commit, green CI, integration check vs the relevant acceptance criterion, **three edge-case probes** (rapid input, mid-action interrupt, save/load round-trip across the feature's state, OS-level interruption like tab-blur for HTML5), and **Tess sign-off** before flipping ClickUp to `complete`. Devs cannot self-sign feature PRs. The bar caught the silent-skip bug (Stratum1BossRoom parse error hid 31 tests) only because integration coverage was being layered. Honor it.

The Definition of Done above is the binding shape; this back-pointer exists so sub-agents searching for "testing-bar" in this doc land at the right anchor.

---

### Auto-memory: `product-vs-component-completeness`

**Rule:** Component-level test coverage and CI-green status are NOT proof the product is shippable. A feature is not "complete" until it is **instantiated in the entry-scene's runtime tree** and reachable through the same path the player uses.

- **CI green + paired tests** = component-complete. The unit/integration tests prove the system works in isolation.
- **Component instantiated in the play surface** (entry scene loads it; it appears in the runnable build artifact) = product-complete.
- **Sponsor sign-off requires product-complete**, not component-complete.

**Why:** On 2026-05-03 the Sponsor downloaded the `embergrave-html5-591bcc8` artifact, served it locally, and saw: a Player square + "Embergrave — boot OK. WASD to move..." banner. Nothing else. **All M1 systems** (grunts, charger, shooter, boss, rooms 1-8, RoomGate, StratumProgression, level-up math, damage formula, affix system, inventory panel, stat-allocation panel, save migration) **shipped as isolated components with their own scenes + autoloads but were never instantiated in the runnable scene tree.** For ~30+ PRs and many heartbeat ticks, the orchestrator confidently reported "M1 feature-complete" while the actual playable build was a week-1 smoke stub. The Sponsor's first 2-minute soak exposed the gap. The flag was raised twice in writing (Tess run-013, Priya week-3 retro W3-A1) and ignored both times.

**How to apply.**

1. Treat any agent report of "feature-complete" as **component-complete only** until you have independently verified the integration surface — read the entry-scene file (`scenes/Main.tscn` or whatever `run/main_scene` points at) and confirm the new system is instantiated there or in a scene that Main.tscn loads.
2. Watch for "(Note, not blocking)" or similar throwaway flags in QA reports. If any reviewer writes "X is not yet wired into Main.tscn" or "Main.tscn is still a stub," that is a P0 flag, not a side note. Elevate to a gating ticket.
3. Don't dispatch features faster than you integrate them. If 5 subsystems land but `Main.tscn` hasn't been touched in those 5 PRs, you are accumulating integration debt.
4. For HTML5/web: **the build artifact is the truth.** Don't claim "shippable" until you (or an agent) has triggered a release build, downloaded the artifact, extracted it, and either visually inspected the entry scene or driven an end-to-end integration test through the same path the player uses.
5. Tickets that say "implement the panel" are NOT the same as "wire the panel into the game." Make wiring explicit on every UI/system ticket — in the dispatch brief, in the acceptance criteria, in the Done clause.

**Mantra:** components pass tests. Products integrate. Don't conflate them.

---

### Auto-memory: `agent-verify-evidence`

**Rule:** Agents must verify against actual evidence (CI logs, file contents, repro output) before refusing a task or asserting impossibility. Reasoning from training-data priors produces high-confidence wrong answers.

**Why:** On 2026-05-02 Tess discovered a real bug — `_ = body` at `Stratum1BossRoom.gd:204` is rejected by GDScript 4.3's parser, cascading to silently break two test files from loading. A freshly-dispatched Drew agent halted the task, declaring "the premise is incorrect: `_ = body` IS valid GDScript 4.3 syntax." He cited language-design priors and refused the (correct, narrowly-scoped) fix. The orchestrator pulled the actual CI log:
```
SCRIPT ERROR: Parse Error: Expected statement, found "_" instead.
          at: GDScript::reload (res://scripts/levels/Stratum1BossRoom.gd:204)
```
The bug was real. The fix (rename param to `_body`, drop the discard line) landed in PR #69 — previously-skipped tests now run AND pass (531 total, +31 newly visible). Agents (especially fresh ones with no session history) lean heavily on training-data priors. Strong priors + no evidence-checking = high-confidence wrong answers.

**How to apply.**

- When working a bug from a task brief: verify the symptom in the actual evidence (CI logs, file contents, repro output) **before** refusing or asserting impossibility. Include this check in your run-log.
- If you find yourself thinking "this can't be right" / "this isn't a real bug" / "this won't compile" — pull the actual artifact (`gh run view --log`, Read the file, run the repro) and look. Don't reason from priors.
- An agent that says "I see X in the actual file/log" should be trusted more than one that says "I know X about the language." Be the former.

---

## Final-report shape — TIGHT (orchestrator-bound reports)

Every sub-agent's task-completion message back to the orchestrator MUST be tight. ≤200 words. Required content only:

- **PR URL** (1 line)
- **Verdict** (1 line — `APPROVE` / `blocked-on-X` / `partial — see follow-up #...`)
- **Blockers or follow-ups** (1-3 lines max — only what the orchestrator needs to act on this turn)
- **Doc updates** (1 line — `Doc updates: <file> — <one-line>` or `Doc updates: none`)
- **Decision draft** (omit if none — `Decision draft: <1-3 line bullet>` for any architectural or process decision worth logging; Priya batches these into `team/DECISIONS.md` weekly — agents NEVER edit that file directly)

Detailed content goes in artifacts the orchestrator can read on-demand, NOT in the orchestrator-bound message:

| Detail surface | Where it goes |
|---|---|
| Empirical evidence / trace excerpts | PR body |
| Per-AC verification + AC walkthrough | Self-Test Report comment on the PR |
| Non-obvious findings | PR body "Non-obvious findings" section |
| Cross-lane integration check | Self-Test Report on the PR |
| Sponsor-input items | PR body section |
| 8-run sweep evidence (sample-size discipline) | PR body / Self-Test Report |
| Diagnostic trace dumps | PR body or `team/log/` artifact |

**Why this rule exists:** the M2 W3 mid-retro investigation (2026-05-15) found that verbose sub-agent final reports flowing back into the orchestrator's main conversation window was the dominant context-bloat surface — separate from static file loads (`.claude/docs/`, MEMORY.md, etc.). Static loads are actually LARGER in MARIAN-TUTOR than Embergrave (4× docs, 3× memory). The bloat differential is in main-window narrative, not in disk. Tightened reports preserve orchestrator-window context for the work that requires it.

**Enforcement:** Tess flags non-tight reports in PR review by reading the agent's final-report message + comparing against the PR body / Self-Test Report. If detailed content is duplicated in both places, the orchestrator-bound message is over-budget. The persona files in `.claude/agents/{role}.md` reinforce the rule per-role.

Reference: orchestrator memory `tightened-final-report-contract.md`.

---

## What changes for each role

### Tess

- **Promoted from "writer of plans" to "active hammer."** Each heartbeat tick where there's a feature in `ready for qa test`, Tess runs that feature against the test plan and either signs off, files bugs, or dispatches them back to the dev with specific repro steps.
- **Author tests, don't just describe them.** When Devon's scaffold lands, write the GUT smoke tests (`tests/test_*.gd`) yourself — don't wait for the devs to write them.
- **Bug bashes are scheduled work.** At the end of each milestone (M1 in week 4-ish), schedule a 1-tick bug bash where Tess does nothing but exploratory testing. File everything found.
- **Severity discipline**: `blocker` (M1 cannot ship), `major` (M1 ships impaired, must fix in M2), `minor` (M1 ships, fix when convenient). Use the discipline.
- **Milestone-gate journey probe (mandatory at RC boundary).** Before any build is handed to Sponsor for soak, Tess runs ONE complete player journey — boot → Room01 → S1 traverse → boss → loot pickup → save → quit → reload → resume — and logs the result in the soak doc (`team/tess-qa/journey-probe-<date>.md` or appended to the per-RC soak file). Any console `push_warning` is a blocker (per the universal console-warning zero-gate ticket `86c9uf0mm`). Any item-id that doesn't resolve is a blocker. Any missing or un-collectable loot is a blocker. The journey probe is the structural complement to the per-ticket coverage and the only Tess-side journey-scoped gate before Sponsor sees the build. Per-PR gates verify components; this gate verifies the journey. **Backstory:** the M2 RC soak (2026-05-15) returned four user-visible findings (Room 04 Shooter AI, boss-room loot, leather_vest unknown-id warning, squares-fighting-squares cosmetic) on a build that had cleared every per-PR gate cleanly — every gate was PR-scoped, but the bugs were journey-scoped. The 15-minute journey probe is the new structural answer; it replaces ad-hoc bug-bash time at RC boundaries, not additional. See `team/priya-pl/m2-week-2-retro.md` for the meta-finding writeup.

### Devon and Drew

- **Tests-with-features, not after.** Every feature commit includes its tests in the same commit (or a tightly-paired follow-up commit if the test must be in a different file). PRs (or pushes) that introduce logic without tests get reverted by the next dispatched dev or by Tess.
- **Run tests locally before pushing.** If Godot isn't installed locally, write the test code, push, and let CI exercise it — but **don't push and walk away if CI is red**. Watch the workflow result; fix forward in the next push.
- **Save/load is the highest-risk system in M1** — it gets the deepest test coverage. Every save-shape change needs a forward-compat test (old save → new schema → load works or migrates cleanly).

### Uma

- **Design docs are testable.** Every UX surface in Uma's docs gets a test ID in Tess's plan ("does HUD show stratum number when player enters Stratum 1?"). Write design docs precisely enough that Tess can build a yes/no checklist from them.

### Priya

- **Owns the testing-bar enforcement.** If a dev pushes a feature without tests, Priya files a `tech-debt(...)` ClickUp task immediately and parks the feature in `to do` until the test lands. No exceptions for "just this once."
- **Buffer in the schedule.** Week-1 backlog assumed a baseline of testing; with this directive, plan **20% buffer** in week 2's backlog for test backfill, bug bashes, and CI hardening.

### Orchestrator

- **Heartbeat checks `ready for qa test` queue depth.** If 3+ items sit in `ready for qa test` between ticks, dispatch Tess immediately rather than waiting for her normal cadence.
- **Sponsor sign-off gate**: before any sign-off ping reaches the Sponsor, the orchestrator confirms the current build has passed Tess's full M1 test plan with zero `blocker` and zero `major` open bugs.

---

## Test inventory targets for M1

By M1 sign-off candidate, the test inventory should cover:

- **Unit tests (GUT)**: ~20–30 tests covering save/load, combat damage math, loot rolling, level-up math, dodge i-frames, mob AI state transitions.
- **Integration tests (GUT scene tests or HTML5 Playwright if cheap)**: ~10–15 covering M1 acceptance scenarios end-to-end.
- **Manual test cases (Tess's plan)**: ~30–50 cases across all 7 acceptance criteria + regression sweep.
- **CI**: green on every push, build artifact (HTML5 export) attached to every release tag.
- **Soak**: at least one 30-minute uninterrupted play session per release candidate, by Tess. Document what happened in `team/tess-qa/soak-<date>.md`.

If the team is hitting these targets, Sponsor's directive is being honored.

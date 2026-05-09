# HTML5 Export — quirks, gates, and verification rituals

What this doc covers: the constraints that shaped Embergrave's HTML5 / WebGL2 export — the Godot 4.3 `gl_compatibility` renderer's known divergences from desktop, the service-worker cache trap that bites soak iteration, the BuildInfo SHA verification ritual, the visual-verification gate that PR #115/#122 cautioned us about, and the standard release-build / artifact-handoff pattern.

## Renderer

HTML5 export uses the **`gl_compatibility`** renderer (Godot 4.3 default for web). Desktop development uses `forward_plus` or `mobile`. They diverge in several load-bearing ways:

- **HDR modulate clamp.** WebGL2's sRGB pipeline clamps `Color` channels to `[0, 1]`. A modulate value like `Color(1.4, 1.0, 0.7)` becomes `(1.0, 1.0, 0.7)` in HTML5 — against a near-white default modulate, the perceptible delta vanishes. **Rule: keep tween target colors strictly sub-1.0 on every channel.** Codified in test `test_player_swing_flash_tint_is_html5_safe` (asserts all channels in `[0, 1]` AND tint delta vs default `>= 0.20`). The original `SWING_FLASH_TINT = Color(1.4, 1.0, 0.7, 1)` was the load-bearing visibility bug fixed in PR #137. Use sub-1.0 like `Color(1.0, 0.85, 0.6, 1.0)`.
- **Polygon2D rendering quirks.** Polygon2D shapes that render correctly on `forward_plus`/`mobile` may not render in `gl_compatibility` — empirically demonstrated by the swing wedge invisibility bug. **Rule: prefer ColorRect / NinePatchRect for simple shapes** until Godot upstream resolves the Polygon2D divergence. PR #137 swapped the wedge from a 3-vertex Polygon2D to a rotated ColorRect with the bounding rectangle (`size = reach × radius*2`).
- **Z-index sensitivity.** `z_index = -1` in `gl_compatibility` can sink a node below the room background's draw layer in ways that don't reproduce on desktop. The PR #137 wedge fix lifted z_index from `-1` to `+1` as part of the same swap. **Rule: don't rely on negative z_index for "draw above floor, below player body" layering** — use positive z_index above the floor's z_index or factor through CanvasLayer.

## Service-worker cache trap

Godot HTML5 exports register a service worker that aggressively caches `index.js` / `index.wasm` / asset bundle. **Switching between artifacts on the same `localhost:8000` URL serves stale assets even after a normal F5 refresh** — including across browser sessions. This bit Sponsor multiple times during the M1 RC P0 wave: the new build SHA showed in BuildInfo from prior sessions in cache, while the trace data printed values from older code (e.g. `tint=(1.40,1.00,0.70)` from pre-PR-#137 even after PR #137's sub-1.0 fix shipped).

**The cache-clear ritual when handing off a new artifact:**

1. Stop existing `python -m http.server` (Ctrl+C in that terminal)
2. Extract the new zip to a **fresh empty folder** (don't overlay on the previous extract)
3. Restart `python -m http.server 8000` from the new folder
4. **Open in an incognito / private window** (Ctrl+Shift+N in Chrome/Edge) — bypasses the service worker entirely
5. **F12 → Console** to see boot lines

**First diagnostic step on a "doesn't behave as expected" report:** have Sponsor paste the boot lines including `[BuildInfo] build: <sha>`. If the SHA doesn't match the artifact name, Sponsor's on a cached or wrong-zip build. Faster than spawning a Devon investigation into "is the code wrong?". See memory: `html5-service-worker-cache-trap.md`.

## BuildInfo SHA verification

Boot logs include:

```
[BuildInfo] build: <sha>
[DebugFlags] debug_build=false test_mode=false fast_xp=false web=true
```

The SHA is the build's commit. Always cross-reference SHA against the expected artifact name. If you see a constant value in trace output that contradicts the source on the build's commit, distinguish: does the SHA match? If yes, suspect a code regression (or a stale traced literal); if no, suspect cache. Trace constants like `SWING_FLASH_TINT` are useful tells because they print directly from the constant.

## HTML5 visual-verification gate

Per memory rule `html5-visual-verification-gate.md`: any PR touching Tween / modulate / Polygon2D / CPUParticles2D / Area2D-state code requires **explicit HTML5 verification** before merge. Headless tests are insufficient — the panic class doesn't raise GDScript exceptions, and renderer divergences only surface in WebGL2.

**Concretely:** the PR's HTML5 release-build run must complete green, the artifact must be downloaded and inspected (or handed off to Sponsor for soak with the cache-clear ritual above), and the Self-Test Report comment must include **a screenshot or short screen-recording** of the actual feature running in HTML5 / Chromium. PRs #115 and #122 shipped past green CI with un-rendered visuals because the headless tests asserted `tween_valid=true` without asserting renderer-observable change — the precedent that drove the PR #138 test-bar codification.

**A "renderer-safe primitives" argument is NOT a substitute for a screenshot.** Authors who can't run Godot locally have argued their PR is exempt because the primitives they used (ColorRect, Label, modulate-on-leaf-Control, BBCode) are platform-agnostic. This argument is risky precedent — the visual gate exists precisely because primitive-safety analysis didn't catch the PR #115/#122 failures either. PR #160 (M2 W1 UX polish) used this argument; Tess's review caught it and required HTML5 spot-check screenshots before merge. **Default rule:** include screenshot/video evidence even when you believe the primitives are safe. If you genuinely cannot produce HTML5 evidence in your local environment, say so explicitly in the Self-Test Report and route to Tess (or the orchestrator) to verify against the release-build artifact before merge — do not self-claim exemption.

Platform-agnostic fixes (e.g. PR #140's mob hit-flash Sprite color tween, where the tween targets `Sprite.color` which is an engine-level draw property identical across all renderers) are exempt from this gate when the change is mechanically deterministic — but the burden is on the author to demonstrate why the visual gate doesn't apply, not to assert exemption by primitive-class.

## Release-build trigger and artifact handoff

```bash
gh workflow run release-github.yml --ref <branch-or-main>
```

The workflow exports HTML5 via Godot 4.3 headless. Run produces an artifact named `embergrave-html5-<short-sha>.zip` (typically ~8.5 MB) attached to the run page. Direct artifact download URL pattern (use this in Sponsor handoff):

```
https://github.com/<owner>/<repo>/actions/runs/<run_id>/artifacts/<artifact_id>
```

Get the artifact ID from `gh api repos/<owner>/<repo>/actions/runs/<id>/artifacts --jq '.artifacts[]|"\(.id) \(.name)"'`. Memory rule: `sponsor-soak-artifact-links.md` — always include the direct download URL, not just the run page.

## Diagnostic-build pattern

When validation needs a tedious-to-trigger gameplay scenario (e.g. mob death at HP=50 with damage=1 = 50 hits per kill), ship a temporary `diag/<short-purpose>` branch that lowers the friction:

- Branch name: `diag/2-swing-kill`, `diag/p0-verification`, etc.
- Single-line / single-file change ideal — `resources/mobs/grunt.tres:11 hp_base = 2` is the canonical example
- Commit message: `[diag-only]` prefix, `TEMPORARY (DO NOT MERGE)` suffix
- Push branch, trigger release-build directly: `gh workflow run release-github.yml --ref diag/<name>`
- **Never merge to main.** Delete from origin once the parent fix lands: `git push origin --delete diag/<name>`
- For integrated verification, cherry-pick the diag commit onto a fix branch (e.g. `diag/p0-verification = drew/die-physics-flush-fix + 2-swing-kill HP change`)

Memory rule: `diagnostic-build-pattern.md`.

## Sponsor soak ritual

When handing off any new HTML5 artifact for Sponsor verification:

1. Lead with the **direct artifact download link**, not just the run page
2. Walk through the cache-clear ritual (above) explicitly
3. Tell Sponsor what to check in the boot logs (`BuildInfo` SHA matches expected)
4. State the test scenarios with concrete success criteria (e.g. "swing 50 times, watch for absence of `USER ERROR: Can't change this state while flushing queries`")
5. Ask for the trace lines covering at least one full success path

Standard soak duration for M1 RC sign-off is **30 minutes uninterrupted play**. Soak ticket pattern: see `team/uma-ux/sponsor-soak-checklist-v2.md`.

## Cross-references

- Combat system that drives most HTML5-specific bugs: `.claude/docs/combat-architecture.md`
- Test bar codification (Tier 1 / Tier 2 visual-primitive invariants): `team/TESTING_BAR.md`
- Post-mortem of the PR #115 / #122 cautionary tale: `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`
- M1 RC build pipeline details: `team/devon-dev/m1-rc-build.md`

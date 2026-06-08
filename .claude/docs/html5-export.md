# HTML5 Export — quirks, gates, and verification rituals

What this doc covers: the constraints that shaped Embergrave's HTML5 / WebGL2 export — the Godot 4.3 `gl_compatibility` renderer's known divergences from desktop, the service-worker cache trap that bites soak iteration, the BuildInfo SHA verification ritual, the visual-verification gate that PR #115/#122 cautioned us about, and the standard release-build / artifact-handoff pattern.

## Renderer

> **Engine version note (86ca65gyv migration, 2026-06-08):** the project migrated 4.3 → **4.6.3.stable**. HTML5 still uses the **`gl_compatibility`** renderer (it remains the Godot 4.6 web default; `config/features` keeps `"GL Compatibility"`). The renderer-divergence rules below were authored against 4.3-gl_compatibility; they are PRESUMED to still hold under 4.6-gl_compatibility (same renderer family) but the full re-verification (HDR clamp, Polygon2D, z-index, service-worker, head_include injection) is the migration PR's HTML5 render-parity gate — see that PR's Self-Test Report for the as-verified status. The `index.html` head_include (contextmenu suppressor + `?debug=1` overlay) was confirmed to inject correctly under the 4.6 export.

HTML5 export uses the **`gl_compatibility`** renderer (Godot 4.6 default for web; was the 4.3 default pre-migration). Desktop development uses `forward_plus` or `mobile`. They diverge in several load-bearing ways:

- **HDR modulate clamp.** WebGL2's sRGB pipeline clamps `Color` channels to `[0, 1]`. A modulate value like `Color(1.4, 1.0, 0.7)` becomes `(1.0, 1.0, 0.7)` in HTML5 — against a near-white default modulate, the perceptible delta vanishes. **Rule: keep tween target colors strictly sub-1.0 on every channel.** Codified in test `test_player_swing_flash_tint_is_html5_safe` (asserts all channels in `[0, 1]` AND tint delta vs default `>= 0.20`). The original `SWING_FLASH_TINT = Color(1.4, 1.0, 0.7, 1)` was the load-bearing visibility bug fixed in PR #137. Use sub-1.0 like `Color(1.0, 0.85, 0.6, 1.0)`.
- **Polygon2D rendering quirks.** Polygon2D shapes that render correctly on `forward_plus`/`mobile` may not render in `gl_compatibility` — empirically demonstrated by the swing wedge invisibility bug. **Rule: prefer ColorRect / NinePatchRect for simple shapes** until Godot upstream resolves the Polygon2D divergence. PR #137 swapped the wedge from a 3-vertex Polygon2D to a rotated ColorRect with the bounding rectangle (`size = reach × radius*2`).
- **Shape OUTLINES — use `Node2D._draw() + draw_arc()` / `draw_polyline()`, not Polygon2D annulus.** The Polygon2D rule above covers *filled* simple shapes (the PR #137 ColorRect swap). Outlines are a distinct case the ColorRect remedy cannot address: `ColorRect` / `NinePatchRect` cannot draw curves, and `Polygon2D` natively renders **filled** polygons — so a circle outline expressed in Polygon2D would be a multi-vertex annulus (outer ring + inner ring, typically 64+ verts), which is **exactly the filled-Polygon2D-on-`gl_compatibility` invisibility risk class from PR #137**. **Rule: for shape outlines in HTML5 (circle, arc, ring, polyline), use a `Node2D` subclass overriding `_draw()` and call `draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)` or `draw_polyline()`.** These route through the engine's primitive-draw path (same path `Line2D` and engine debug overlays use) and bypass the Polygon2D batching pipeline entirely — they render consistently across `forward_plus` / `mobile` / `gl_compatibility`. Other safe `_draw()` primitives: `draw_line`, `draw_polyline`, `draw_rect`. **Animate via `modulate` tween on the Node2D — no `queue_redraw()` needed for color/alpha**; call `queue_redraw()` only when geometry changes (radius pulse, segment count). **When `_draw()` is overkill:** a single straight outline (horizontal range indicator, screen-edge marker) is simpler as a `Line2D` with `width = N` — same primitive layer, equally renderer-safe. **PR #291 precedent (T5 slam-telegraph circle):** the boss slam danger-zone indicator at `radius=80` is a custom `Node2D` with `_draw()` calling `draw_arc(...)` plus a `modulate.a` pulse tween — ColorRect ruled out (no circles), Polygon2D annulus ruled out (PR #137 risk class), `draw_arc` shipped clean. **Still subject to the visual-verification gate** (§ HTML5 visual-verification gate below) — `draw_arc`'s primitive-safety analysis is not a substitute for a screenshot.
- **Z-index sensitivity.** `z_index = -1` in `gl_compatibility` can sink a node below the room background's draw layer in ways that don't reproduce on desktop. The PR #137 wedge fix lifted z_index from `-1` to `+1` as part of the same swap. **Rule: don't rely on negative z_index for "draw above floor, below player body" layering** — use positive z_index above the floor's z_index or factor through CanvasLayer. **Co-rule for `z_index = 0` collisions (PR #291 T6 precedent):** a CPUParticles2D burst parented to the room at default `z_index = 0` may render *behind* a same-z sprite (e.g. the boss sprite that emitted it) under `gl_compatibility`, even though desktop renderers happen to draw the burst on top. The burst doesn't disappear — it's silently obscured by the larger same-z sprite, which reads visually identical to "the burst never fired." **Rule: any short-lived burst parented to a shared layer (room, world) and intended to read *above* gameplay sprites must explicitly set `z_index = +1` (or higher).** This is part of the larger HTML5 rule: when two nodes share `z_index`, do not rely on draw-order tie-breaks — they differ between renderers. CPUParticles2D and Polygon2D both hit this class; cure is the same.
- **Burst contrast against high-hue-saturation same-z sprites (PR #291 T6 v5 finding, 2026-05-21).** Distinct from the z-index occlusion rule above: a CPUParticles2D burst that renders ON TOP of a high-hue-saturation sprite (e.g. ember-orange particles spawning over a boss in red armor) **may visually blend into the sprite even though the particles are technically drawing correctly**. Drew's PR #291 v3-v4 trace investigation: particles spawning at correct position, correct count, correct z_index=+1, correct lifetime, emitting=true — but the ember-light `#FFB066` → ember-deep `#A02E08` ramp was hue-adjacent enough to the boss's red surcoat (`#4A1019`) that the burst read as "no aftershock" against the sprite background. Reading from a screenshot, the burst was technically present but visually invisible because adjacent-hue desaturated pixels blend perceptually under WebGL2's compositing pipeline. **Rule for burst color ramps over high-saturation sprites: include a high-contrast IMPACT frame in the ramp (white, near-white, or perceptually-opposite-hue) so the burst has at least one perceptually-distinct frame that "pops" above the sprite background.** v5 fix: 12→24 particles + 3-stop ramp with `AFTERSHOCK_FLASH_WHITE` (`#FFF2BF`) at ramp[0] for the impact-frame brightness. Empirically: a single 50ms-bright-white frame is sufficient to break the perceptual blend even when 90% of the burst lifetime is in the same hue family as the underlying sprite. This is a HUMAN-PERCEPTION rule, not a renderer-divergence rule — but the failure mode is invisible to GUT, headless screenshots, and per-frame pixel sampling because the bug is "blend perceptually identical to background," not "pixels missing."
- **Default-font glyph coverage.** The Godot 4.3 `gl_compatibility` HTML5 export's built-in default font covers only a subset of Unicode. Non-ASCII cue glyphs outside that subset — including U+2713 `✓` (checkmark), arrows, box-drawing characters — render as a notdef "tofu" box in HTML5, while passing undetected in headless GUT and desktop builds (those use a wider OS fallback font). PR #179's equipped-item inventory badge shipped `✓` in a Label and hit this in production. **Rule: draw cue glyphs (checkmarks, arrows, indicator icons) as geometry — e.g. two rotated `ColorRect` strokes — not as font characters. Plain ASCII text in `Label` nodes is unaffected.** If a Unicode glyph is essential, import a custom `.ttf`/`.otf` covering the codepoint and assign it as the control's custom font. This divergence is invisible to headless GUT and desktop — only an HTML5 smoke test catches it, so it is subject to the visual-verification gate.

**Surface scope (extended PR #308 world-map direction, 2026-05-22).** The same default-font tofu class hits any UI surface that uses tally-marker glyphs to represent state: world-map zone-state markers (cleared / quest-target / boss-room), HUD badges (equipped indicators), bounty-board completion ticks, future stash-tab "new item" pips. **All affected by the same rule** — draw as geometry, not as Unicode glyph. Secondary framing benefit: the diegetic "two rotated ColorRect strokes scrawled in ember-orange" often reads MORE Embergrave-tonal than a literal Unicode `✓` would, given the parchment+ember palette. The rule isn't a workaround tax — it's an aesthetic win on top of a renderer-safety win.

**Debug-log surface — any string that may flow into a Label (PR #328, pending merge).** The rule is not limited to deliberate cue glyphs. Devon's procgen spike (commit `e900222`, branch `devon/86c9xub9p-procgen-part-bcd`) used U+2194 `↔` as a port-mating separator in `[procgen]` debug-log strings. In `print()` / `push_warning()` output the character is harmless — those calls bypass the font renderer entirely. But if any such debug string is later routed to a `Label` (overlay HUD, in-game debug panel, on-screen log), the tofu box appears and the rule applies. The `ProcgenSpikeScene` HUD Label surfaced `_sweep_port_mating` error strings directly, which is how Devon caught the regression during HTML5 self-soak. **Generalised rule:** treat any string that *may* flow into a Godot `Label` as subject to the glyph-coverage constraint — ASCII-only is safe; non-ASCII cue characters require a geometric-draw alternative or a custom `.ttf`/`.otf`. Plain GDScript `print()` output, `.tres` comments, and editor-only strings are unaffected. This is the third case in the default-font tofu class: PR #179 (equipped-item `✓` badge) → PR #308 (world-map zone-state markers) → PR #328 (debug-log `↔` separator routing into a HUD Label).

## Browser-native event leakage (RMB context menu, etc.)

HTML5 builds run inside a browser tab, and the browser's native event handling fires alongside Godot's input handling unless explicitly suppressed. **Right-click is the most user-visible leak:** RMB heavy-attack triggers the browser's default `contextmenu` event (popup menu over the canvas), and the game loses input focus until the user dismisses it. Reported by Sponsor in the 2026-05-16 M2 W3 soak; fixed in PR #235.

**Fix pattern — `export_presets.cfg` `html/head_include` script injection:**

```ini
[preset.0.options]
html/head_include="<script>
window.addEventListener('DOMContentLoaded', () => {
  const block = e => e.preventDefault();
  document.addEventListener('contextmenu', block);
  document.querySelector('canvas')?.addEventListener('contextmenu', block);
});
</script>"
```

The `head_include` field embeds the script into the generated `index.html` `<head>` at export time. Suppress at both `document` and `canvas` to cover all hit paths. No GDScript change required.

**Register the `document` listener SYNCHRONOUSLY at `<head>`-parse, NOT inside `DOMContentLoaded` — and use capture phase (the re-soak #5 hardening).** The original PR #235 form (snippet above, the DCL-wrapped version) deferred BOTH `addEventListener` calls to `DOMContentLoaded`. That leaves a **head-parse → DCL window with no suppressor at all**: on a real-browser cold load (large WASM, service-worker miss) the canvas can be present and right-clickable before DCL fires, and a right-click in that window leaks the native menu. This is the "RMB *still* triggers the context menu" re-soak finding — the suppressor was present and worked once DCL had fired, but the cold-load race intermittently leaked. Empirically reproduced: a Playwright spec navigating with `waitUntil:"commit"` and dispatching a `contextmenu` the instant `#canvas` is selectable returns `defaultPrevented:false` on the old build (flaky, ~1-in-5) and `true` deterministically on the hardened build.

**Hardened pattern (current `main`):**

```js
<script>(function(){
  var block = function(e){ e.preventDefault(); };
  document.addEventListener('contextmenu', block, true);   // capture — runs before any other handler, no DCL wait
  document.addEventListener('contextmenu', block, false);  // bubble  — belt-and-suspenders
  document.addEventListener('DOMContentLoaded', function(){
    var canvas = document.getElementById('canvas');
    if (canvas) { canvas.addEventListener('contextmenu', block, true); }  // canvas-specific, once it exists
  });
})();</script>
```

Why capture-phase at `document`: the `contextmenu` event traverses capture (document → target) then bubble (target → document). A capture-phase `document` listener fires FIRST in the whole dispatch, before any target-level handler and with no DCL dependency — it is the airtight catch-all for canvas, body/letterbox margins, and any future element. The bubble-phase + canvas listeners are redundant safety. **Godot's own engine glue (`godot_js_display_setup_canvas`) also installs a canvas `contextmenu` preventDefault, but only after the WASM Display driver boots** — the head_include covers the entire pre-boot window the engine cannot.

**Regression guard:** `tests/playwright/specs/contextmenu-suppress.spec.ts` — asserts `event.defaultPrevented === true` (the exact signal that gates the native menu) across a real right-click, synthetic dispatch on canvas/body/document, AND the early-load (canvas-exists) path. The early-load test is the one that catches a regression back to the DCL-deferred form. `defaultPrevented` is the headless proxy for "no native menu appears" — Playwright cannot screenshot OS-drawn menu chrome.

**`window`-capture layer + Shift+RMB (PR #386 follow-up).** A Sponsor re-soak (#5, Brave) reported plain RMB suppressed but **Shift+RMB still leaked** the native menu. Empirical finding against the real Brave binary via CDP: there is NO modifier gate in the suppressor, and Shift+RMB DOES fire `contextmenu` with `shiftKey:true` — both plain and shift right-click reach the suppressor and end `defaultPrevented:true` in Brave AND vanilla Chromium. MDN documents the Shift+RightClick force-show escape hatch as **Firefox-only** (menu shown without firing a suppressible event); Chromium/Brave do not expose it on the automatable path. Hardening: also register on **`window` capture** (`window.addEventListener('contextmenu', block, true)`) — the earliest point in the capture descent, before `document` — so no mid-chain `stopPropagation` can intercept a shift-modified event before our `preventDefault`. **Honest caveat:** the interactive-Brave Shift+RMB leak was NOT reproducible via Playwright CDP input (automation already prevents it pre-fix at the event level), so window-capture is the defensible code-side close but **Sponsor re-soak in real Brave is the gate of record**; if it persists the residual cause is a Brave hardware-gesture escape hatch un-suppressible from JS, and the fallback is a control-rebind discussion (move heavy-attack off Shift+RMB), not a JS hack.

**Heavy-attack passthrough.** `preventDefault()` on `contextmenu` does NOT affect the `mousedown`/`pointerdown` (button 2) events Godot reads for the heavy-attack — they are separate events. Against the real Godot WASM build the engine's own glue calls `preventDefault()` on the canvas `mousedown` it consumes, so `defaultPrevented` is TRUE on the real build by Godot's own choice — that is correct and does NOT mean the input was suppressed. The regression test asserts button-2 mousedown **delivery to the canvas**, not its `defaultPrevented` state.

**Other likely browser-event leaks to watch for in future soak rounds** (none confirmed in the codebase yet, but Uma flagged the class in PR #235's decision draft):

- `dragstart` / `drop` — browser drag-and-drop semantics
- `wheel` — page-scroll while the game tries to consume the wheel
- `selectstart` — text-selection on canvas-adjacent UI
- `touchstart` double-tap zoom on mobile (suppress via `touch-action: manipulation` CSS or `viewport` meta tag)

Each is a small `head_include` addition once it surfaces. The whole class is "browser default behaviour leaks through Godot input handling" — the suppression mechanism is the same.

## Debug-tooling via `head_include` (second use of the script-injection class)

`head_include` is also the lowest-friction surface for **opt-in JS-side debug tooling** that has no GDScript equivalent. The second shipped example is the `?debug=1` Copy-log overlay (Sponsor M2 W3 soak workaround), which sits alongside the contextmenu suppressor in the same preset.

**The problem it solves:** the browser's F12 Console panel truncates copy-paste output at ~50KB (browser-imposed clipboard cap on Console-panel selection). Sponsor's soak workflow involves pasting console traces into chat for diagnosis; the truncation silently cut off the boss-room tail of long traces. Godot has no way to write to the system clipboard from GDScript in HTML5 — but the JS `navigator.clipboard.writeText` API does, and a `<script>` block injected via `head_include` can bridge it.

**Pattern:**

1. **URL-param gate.** Read `new URLSearchParams(window.location.search)` at script entry; bail out if the flag isn't set. Zero overhead on normal play — the IIFE returns immediately.
2. **Hook the console BEFORE Godot boots.** `console.log/warn/error/info` are reassigned to a wrapper that pushes into an in-memory `string[]` buffer AND calls the original. Hooking at `<head>` parse time ensures the boot lines (`[Save]`, `[BuildInfo]`, `[Main]`) land in the buffer too. Cap the buffer (we use 20k lines) so a long soak doesn't OOM the tab.
3. **Floating overlay button.** Append a fixed-position `<button>` to `document.body` on `DOMContentLoaded`. Z-index high enough to sit above the Godot canvas.
4. **Clipboard write.** On click, `navigator.clipboard.writeText(buffer.join('\n'))`. Flash the button label to `Copied (N lines)` on success, `Copy failed` on rejection. Includes a `document.execCommand('copy')` fallback path for browsers without the clipboard API.

**Activation:** append `?debug=1` to the URL. Example: `http://localhost:8000/?debug=1`. Default (no param, or `?debug=0`) → script returns immediately; no overlay, no console hooks.

**Why head_include, not a Godot UI panel:**
- No GDScript change → no `gl_compatibility` renderer-risk gate to clear.
- Works the same on every HTML5 build regardless of which scene is active or whether Godot has even finished booting (the button appears even if Godot crashes during boot — useful for diagnosing boot failures).
- Bypasses the F12 truncation by going around the F12 panel entirely (system clipboard, not console selection).

**Future debug-tooling additions on this surface** should follow the same shape: URL-param-gated IIFE in the `head_include`, single small piece of functionality per script block, no cross-block coupling. Reasonable next candidates (none committed yet):

- `?fps=1` — overlay FPS counter (Godot has one but it lives inside the canvas; an HTML-side counter survives renderer crashes).
- `?bench=1` — log frame-time stats to the same buffer, expose via a "Copy benchmark" button.
- `?dump=<event>=1` — toggle individual `[trace]` categories on/off without rebuilding.

Each is independently gated and independently cuttable — the same composability the contextmenu-suppress block has alongside the copy-log overlay.

### Escape-sequence pitfall — Godot INI parser eats backslash escapes

**The bug (PR #240 finding, Sponsor 2026-05-16 soak):** Godot's INI parser interprets backslash escape sequences in `export_presets.cfg` string values BEFORE writing them into the generated `index.html`. A literal `\n` in the `head_include` JS source becomes a **real newline character** at export time, which splits any JS string literal containing it across two physical lines:

```js
// What the .cfg author wrote:
var text = buf.join('\n');
// What the Godot INI parser produced in index.html:
var text = buf.join('
');
```

This is a SyntaxError. The whole IIFE crashes silently during `<head>` parse — the script-injected feature (copy-log overlay, contextmenu suppressor, future debug tools) is GONE in the export with zero visible error from the Godot build itself. The page just behaves as if the script were never there.

**The fix:** double-escape every intended-for-JS backslash sequence. `\n` → `\\n`, `\t` → `\\t`, `\r` → `\\r`, `\\` → `\\\\`. The INI parser collapses `\\n` to `\n` (a literal two-character backslash-n), and the browser's JS parser then interprets that as the newline escape inside the JS string literal — which is what was intended.

**Other escapes in the same trap class:** `\b`, `\f`, `\v`, `\0`, `\xNN`, `\uNNNN`, `\'`, `\"`. Anything the INI parser recognizes as an escape sequence will be collapsed at export time and bite the JS payload.

**Verification ritual after editing `html/head_include`:**

```bash
# After exporting (gh workflow run release-github.yml ...):
# Download the artifact, extract, then:
grep "buf.join" build/web/index.html
# The call MUST appear on a SINGLE LINE. If it's split across two
# lines, the INI parser ate an unescaped `\n`. Open the .cfg, fix the
# double-escape, re-export.
```

More generally: `grep` any JS string literal that contains a control character and confirm it sits on one physical line in the exported `index.html`. If you don't have a release artifact handy, an open-in-editor visual scan of `index.html` for unexpected newlines inside `<script>` blocks works too.

**Why this is invisible to CI:** Godot's exporter doesn't validate the generated `<head>` JS — it just concatenates strings. The browser console shows a `SyntaxError` at runtime when the page loads, but if no E2E test exercises the JS feature (most Playwright specs don't depend on `?debug=1`), the failure is silent. Sponsor caught the M2 W3 IIFE crash because the Copy-log button stopped appearing — the only test surface was Sponsor's soak workflow itself.

**Author discipline:** any non-trivial `head_include` edit should be paired with a release build + grep verification before merge. The same `head_include` constraint applies to any future Godot `.cfg`-embedded JS surface (custom HTML shell, PWA manifest comments, etc.).

## Godot input handling order: `_input()` vs `_unhandled_input()` for UI shortcuts

A second 2026-05-16 soak finding (PR #235): the inventory's "Tab close" hint did not work — pressing Tab while the inventory was open cycled focus between inventory Buttons instead of closing the panel. The toggle binding was in `_unhandled_input()`, which fires AFTER Godot's GUI system has already consumed Tab for focus-traversal between Control nodes.

**Rule:** any UI shortcut that overlaps with Godot's built-in GUI input semantics (Tab for focus-cycle, Space for button-activate, arrow keys for focus-direction) MUST be handled in `_input()` (which fires BEFORE the GUI system), not `_unhandled_input()`. After handling, call `set_input_as_handled()` to stop propagation.

Esc and most game-only keys do NOT have this conflict and remain fine in `_unhandled_input()`. The InventoryPanel pattern at HEAD is the canonical example: Tab toggle in `_input()`, Esc close in `_unhandled_input()`.

## Resource enumeration on packed `.pck` resources

**`DirAccess.current_is_dir()` returns false on subdirectories of packed `.pck` resources in HTML5.** Recursive `DirAccess` scans that work on desktop (and headless GUT) silently skip subdirs in HTML5 — entries that ARE directories get `current_is_dir() == false` and the recursion never descends. This bit `ContentRegistry.load_all()` in PR #166 (ticket `86c9qah1f`): `iron_sword.tres` lives at `resources/items/weapons/iron_sword.tres`, the recursive scan missed it in HTML5 only, and `Inventory.restore_from_save` push_warning'd `unknown item id 'iron_sword'` on every F5 reload.

**Rule:** any HTML5-shipping content-scanning code that depends on `DirAccess` recursion needs a fallback path. The PR #166 fix is the canonical pattern — see `.claude/docs/combat-architecture.md` § "ContentRegistry.items_resolved" for the full three-pronged fallback:

1. Recursive `DirAccess` scan (works on desktop)
2. Explicit subdir scan of a known-roots constant (HTML5 fallback, quiet on open-fail)
3. Direct `load()` of must-have paths (always works — `load()` reads from the resource cache, not DirAccess)

**Latent surfaces in this codebase:** any future loot table walker, mob-def discovery, level-chunk autoloader, or affix-pool scanner that uses `DirAccess` recursion has the same latent bug class. Always pair with a pinned-paths fallback for save-critical resources, and ship an HTML5-build smoke test (headless GUT and desktop will both pass against the bug).

## Canvas resize / minimize-restore — owned-state clobber

**`html/canvas_resize_policy=2` (adaptive) + `window/stretch/mode="canvas_items"` re-run the viewport stretch on every canvas resize — including browser minimize → restore.** The export ships `canvas_resize_policy=2` (`export_presets.cfg`) so the canvas tracks the browser window; combined with the `canvas_items` stretch (`project.godot [display]`), a restore re-runs the stretch pass that maps the 480×270 logical world onto the live canvas size.

**The trap:** the stretch pass writes engine-level transform/zoom state DIRECTLY. Any autoload or system that *owns* a piece of that engine state via a GDScript mirror (the canonical case: `CameraDirector` owns `Camera2D.zoom` via `_current_normalized_zoom`) gets its engine value reset to the scene default on restore, **without** its mirror being touched. The mirror and the engine then disagree — the owned non-default state (a 0.5× arena zoom, a 1.5× cinematic zoom, a pinned camera anchor) silently reverts to default on the next minimize/restore, while the owning system still believes it holds the non-default value.

**The fix pattern (PR `devon/camera-zoom-restore`):** any single-owner-of-engine-state autoload must **subscribe `get_viewport().size_changed` in `_ready`** and, on the signal, **re-project its retained mirror onto the engine state** — `call_deferred` by one frame so the engine's own stretch recompute settles first. For `CameraDirector` this is `_on_window_size_changed()` → `_reassert_owned_camera_state()` writing `_camera.zoom = BASELINE_ZOOM * _current_normalized_zoom` directly (bypassing any idempotence guard that would no-op a re-request, since the mirror still reads the correct value). State that's re-derived live each `_process` tick (follow-target, deadzone, world-bounds) needs no explicit re-write; only state the system writes once-and-holds (zoom, pinned position) must be re-asserted.

**Detection is HTML5-only + interactive.** Headless GUT can *simulate* the clobber (mutate `_camera.zoom` behind the director's back, emit `size_changed`, assert restore) but the real trigger — a browser minimize/restore re-running the adaptive stretch — only manifests in a real browser tab. This is a **visual-verification-gate** surface: confirm the owned state holds across an actual minimize → restore cycle in the release build. Other autoloads that own engine transform state (a future parallax/background-scroll director, any direct `Viewport.canvas_transform` writer) inherit the same latent bug class and need the same `size_changed` re-assert.

**Full Camera2D treatment:** [`camera-layer.md` § "HTML5 — minimize/restore zoom re-assert"](camera-layer.md).

## Service-worker cache trap

Godot HTML5 exports register a service worker that aggressively caches `index.js` / `index.wasm` / asset bundle. **Switching between artifacts on the same `localhost:8000` URL serves stale assets even after a normal F5 refresh** — including across browser sessions. This bit Sponsor multiple times during the M1 RC P0 wave: the new build SHA showed in BuildInfo from prior sessions in cache, while the trace data printed values from older code (e.g. `tint=(1.40,1.00,0.70)` from pre-PR-#137 even after PR #137's sub-1.0 fix shipped).

**The cache-clear ritual when handing off a new artifact:**

1. Stop existing `python -m http.server` (Ctrl+C in that terminal)
2. Extract the new zip to a **fresh empty folder** (don't overlay on the previous extract)
3. Restart `python -m http.server 8000` from the new folder
4. **Open in an incognito / private window** (Ctrl+Shift+N in Chrome/Edge) — bypasses the service worker entirely
5. **F12 → Console** to see boot lines

**First diagnostic step on a "doesn't behave as expected" report:** have Sponsor paste the boot lines including `[BuildInfo] build: <sha>`. If the SHA doesn't match the artifact name, Sponsor's on a cached or wrong-zip build. Faster than spawning a Devon investigation into "is the code wrong?". See memory: `html5-service-worker-cache-trap.md`.

## CLI-agent HTML5 self-soak — COOP/COEP headers required

The `python -m http.server` path above is for **Sponsor's manual soak** — interactive `localhost:8000` in a browser. **Sub-agents running an HTML5 author-self-soak from a CLI session need a different server.** Discovered empirically during PR #351 (W2-T1 camera-scroll production wiring, Drew, 2026-05-23): Python's `http.server` silently boot-hangs the Godot artifact when the agent's automation drives it headlessly. The artifact loads, but no boot lines are emitted — Godot is waiting on a `SharedArrayBuffer` reference that the browser refuses to instantiate.

**Root cause.** Modern browsers gate `SharedArrayBuffer` behind a **cross-origin isolation** policy. The serving page must respond with **both**:

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

Python's stdlib `http.server` emits neither. Sponsor's interactive browser-soak coincidentally tolerates the absence (the engine falls back to non-SAB rendering for the simple `Main.tscn` path), but headless Playwright / automation reads the boot hang as silent failure.

**The fix.** Reuse `tests/playwright/fixtures/artifact-server.ts` — Playwright's harness already encodes the COOP/COEP headers as a Node HTTP server fixture. Any new CLI-agent self-soak tooling should consume that fixture or replicate its header pattern, **not roll a fresh `python -m http.server` wrapper**.

**Distinction summary:**

| Soak surface | Server | Headers | Tolerates missing COOP/COEP? |
|---|---|---|---|
| Sponsor manual (browser) | `python -m http.server 8000` | none | yes (most surfaces) |
| Sub-agent CLI self-soak | Node HTTP server (artifact-server.ts) | COOP + COEP | no — boot hangs |
| Playwright CI | artifact-server.ts (already wired) | COOP + COEP | no — boot hangs |

Apply this whenever a sub-agent's brief includes an HTML5 author-self-soak step. Cite of record: Drew's W2-T1 final report on PR #351, 2026-05-23.

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

**What this gate does NOT catch — the bare-Hitbox-no-visual class.** The visual-verification gate is for nodes that exist and may render incorrectly in WebGL2. It does NOT catch an attack that spawns a damage `Hitbox` with no visual child at all (player takes damage with zero telegraph). That's a distinct combat-authoring bug class — see [`combat-architecture.md`](combat-architecture.md) § "Invisible-attack bug class — bare damage-Hitbox with no visual child" (PR #380). Only interactive soak catches the raw symptom; the structural defense is the attack-visual `_ready()` trace-bridge documented there.

### Visual-verification escape clause — honest-disclose + Sponsor-soak routing

When **both the PR author and the reviewing agent** cannot launch a browser interactively in their environments (VM / container / headless agent context), the gate has an established escape-clause workflow rather than a blanket block:

1. **Author honest-discloses** in the Self-Test Report that HTML5 visual verification was not performed in the author environment, and lists specific visual probe targets (e.g. "confirm modulate fade-in over darkened room", "confirm HDR-clamp compliance — no channel > 1.0", "confirm tween pauses during hit-pause freeze").
2. **Reviewer concurs** in the QA review comment and echoes the probe targets.
3. **Sponsor-soak is designated the visual verification of record** — the PR is not blocked, but the Sponsor handoff message must call out the specific probe targets explicitly.
4. The Self-Test Report and QA comment together constitute the paper trail; neither party self-claims exemption — they document the deferral and route it.

**Precedent PRs:** this escape clause has been applied on PRs #285 (Engine.time_scale smoke), #288 (audio HTML5 audible probes), and #289 (title card HDR-clamp / tween / modulate). It is now a project convention, not a one-off.

**What this does NOT permit:** silent omission of the gate, self-claiming "renderer-safe primitives" exemption without documentation, or routing to Sponsor without the explicit probe target list. The probes are load-bearing — without them, Sponsor's soak is unguided and the visual bugs that drove the original gate (PR #115/#122) can slip through again.

**When this escape clause does NOT apply:** if the change touches Polygon2D, CPUParticles2D, or Area2D-state mutations — the failure modes for these are empirically demonstrated (PR #115/#122) and subtle enough that renderer-safety analysis is insufficient even as pre-work. Those require a screenshot from someone who can run Godot locally (Sponsor or a local build) before merge, not after.

**When a PR bundles eligible + ineligible surfaces — invoke the clause per-surface, not per-PR.** A single PR may mix escape-clause-eligible visual work (renderer-safe primitives like `_draw()` + `draw_arc()`) with ineligible work (Polygon2D / CPUParticles2D / Area2D-state). The Self-Test Report must enumerate each visual surface separately and state per-surface eligibility: for eligible surfaces, invoke the escape clause with probe targets; for ineligible surfaces, withdraw the clause and route to **pre-merge Sponsor-soak** (not post-merge) with concrete probe targets. The reviewing agent likewise concurs per-surface, not globally — a narrow REQUEST CHANGES on the ineligible portion is the correct outcome when an author has invoked the clause globally over a mixed PR.

**Precedent:** PR #291 (T5 slam-telegraph `draw_arc()` + T6 slam-aftershock CPUParticles2D burst). The first Self-Test Report invoked the clause globally; Tess REQUEST CHANGES narrowly on T6; respun report retained the clause for T5 and routed T6 to pre-merge Sponsor-soak. Wave 2 bundling-PRs (T9 / T13 / T16) are expected to repeat this shape — apply per-surface enumeration up front.

### Playwright headless ≠ real-browser perception (PR #291 v6→v7 finding)

**Playwright headless screenshot captures are NOT a substitute for Sponsor's interactive visual gate.** They prove "particles spawned at the right position with the right config," not "a human will see them in real-time motion." PR #291 v6 had Tess APPROVE on 4 Playwright headless screenshots showing the slam aftershock burst; Sponsor then soaked the same build interactively and reported the effect was invisible. Three plausible failure modes (any combination): sub-perceptual frames captured at timing windows the human eye never resolves (~60Hz sampling + motion-blur + attention drift), headless-vs-interactive `gl_compatibility` rendering divergence (headless Chromium has no full GPU compositor), and sprite-occlusion + dispersion timing (particles spawned at boss-center hidden by sprite at t=0; by the time they disperse out, the bright ramp[0] flash has decayed).

**Rule:** Playwright headless is for trace + config verification, NOT for "this is visible" claims. Sponsor's interactive soak remains the gate of record for CPUParticles2D / tween modulate / Polygon2D class. Full coverage of the implication for Self-Test Report claim-shape + design-iteration guidance lives in [`test-conventions.md` § "Playwright headless ≠ real-browser perception"](test-conventions.md#playwright-headless--real-browser-perception-pr-291-v6v7-finding). The design-fix shape for "captured but imperceptible" is: longer (≥50ms sustained bright dwell), wider (more particles, larger scale, outward velocity to clear sprite occlusion), or louder (brighter contrast or supplemental sprite-modulate flash) — iteration is in the design, not the Playwright cadence.

**Validated by PR #291 v7** (the iteration that addressed the v6 soak failure): particle count 24→56, scale 1.5→2.5, ramp[0] FLAT HOLD at pure-white #FFFFFF for ~105ms (vs v6's effective sub-1ms decay from #FFF2BF), plus a supplemental boss sprite-modulate flash at slam-fire. Pending Sponsor visual gate as of 2026-05-21.

## Release-build trigger and artifact handoff

```bash
gh workflow run release-github.yml --ref <branch-or-main>
```

The workflow exports HTML5 via Godot 4.6 headless (4.6.3.stable; was 4.3 pre-86ca65gyv migration). Run produces an artifact named `embergrave-html5-<short-sha>.zip` (typically ~8.5 MB) attached to the run page. Direct artifact download URL pattern (use this in Sponsor handoff):

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

**Variant — `diag/<topic>-soak` for spike PR Sponsor visual gates (PR #328 procgen, 2026-05-23).** When a spike PR ships a proof scene (e.g. `scenes/spike/ProcgenSpikeScene.tscn`) and the production PR keeps `main_scene = Main.tscn` (so production behavior is unchanged), the spike feature is INERT in production builds — main_scene drives normal gameplay, the proof scene only loads when explicitly activated. The diag-build variant for this case is `diag/<topic>-soak`: a single-commit branch that swaps `application/run/main_scene` in `project.godot` to the proof scene, so the artifact boots directly into the spike for Sponsor visual verification. **Sponsor soak link MUST be the diag-build artifact, NEVER the production PR's release-build artifact** — the production artifact ships the spike code but does not activate it. Empirical case: PR #328 procgen spike → `diag/procgen-spike-soak` at SHA `e900222`. Memory rule: `spike-soak-uses-diag-artifact-not-production.md`. The production artifact still has a valid signal — proves the spike code merges cleanly without breaking normal play — but is NOT the visual-gate artifact.

Memory rule: `diagnostic-build-pattern.md`.

### New-boss soak acceleration — `boss_hp_mult` parity gap

The `?boss_hp_mult=N` URL soak param is honored by `Stratum1Boss` but is **NOT inherited by new boss classes** — `ArchiveSentinel` (S2 boss, merged PR #374) reads `hp_base` from its `.tres` without consulting the param. Consequence: a phase-2 soak for a new boss that relies on the param silently does nothing, forcing a `diag/*` `hp_base`-nerf branch to reach phase-2 mechanics (Drew hit this on PR #380 — had to diag-build to reach ArchiveSentinel's phase-2 slam telegraph).

**Rule for every new boss class:** wire `?boss_hp_mult=N` in the boss's `_ready` at authoring time (mirror `Stratum1Boss`), not as a post-ship follow-up. Until parity lands for a given boss, any Self-Test Report / Sponsor-soak handoff for that boss MUST note `boss_hp_mult` is unwired + route phase-2 verification to a `diag/*` nerf artifact. `boss_hp_mult` parity for ArchiveSentinel is a standing follow-up from PR #380.

### DebugFlags URL params — S2 traversal vs boss-only, and the mutual-exclusivity gotcha

`scripts/debug/DebugFlags.gd` exposes three HTML5 URL query params for S2 soak iteration (call sites confirmed at PR #391, merge `9a6b479`):

| Param | Type | Effect |
|---|---|---|
| `?boss_hp_mult=N` | float, clamped `[0.05, 5.0]` | Scales boss HP. Values below 0.05 emit a benign `USER WARNING` clamp message — expected, not a test failure. (Caveat: not honored by every boss class — see parity-gap note above.) |
| `?start_room=N` | int `0–9` | Drops directly into room index N. `9 = S2_BOSS_ROOM_INDEX` — loads the ArchiveSentinel arena directly, **bypassing S2 traversal**. |
| `?force_descend=1` | flag | Opens the DescendScreen at boot; descending from it **enters the S2 traversal** via `Main._begin_stratum_2()`. |

**GOTCHA — never combine `start_room=9` with `force_descend=1`.** `start_room=9` loads the boss room directly in the background AND `force_descend=1` layers the DescendScreen overlay on top. The player observes neither a clean traversal nor a clean boss test — the boss loaded underneath aggros and kills an idle player through the overlay. This produced a wasted soak cycle on PR #391 Sponsor verification. The params are individually documented in `DebugFlags.gd` but the interaction is not guarded in code — it is a caller-discipline rule.

**Rule for soak handoffs:**
- **S2-traversal soak** (z1→z2→z3→boss): `?force_descend=1` **alone**.
- **Boss-arena soak** (skip traversal): `?start_room=9` **alone** (pair with `?boss_hp_mult=0.2` for phase-2 reach, subject to the parity gap above).
- Never combine both in one soak URL.

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

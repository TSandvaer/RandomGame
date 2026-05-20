# Camera Layer — CameraDirector autoload + zoom API

> **STATUS — Landed on `main` via PR for ticket `86c9wjyf3` (M3 Tier 2 Wave 2 T9).** This doc captures the Camera2D contract semantically; for exact GDScript signatures verify against `scripts/camera/CameraDirector.gd`.

## What this is

`CameraDirector` is an **autoload Node** that owns the M1 play-loop's `Camera2D`. It is the single writer of `Camera2D.zoom` and `Camera2D.global_position` after T9. Same Director pattern as `AudioDirector` ([`audio-architecture.md`](audio-architecture.md)) and `TimeScaleDirector` ([`time-scale-director.md`](time-scale-director.md)) — the autoload exposes the API; an internal puppet Node does the engine work.

Foundation ticket: **T9** (Wave 2). Wave 3 consumers: **T13** (boss nameplate context — no camera dep but coexists), **T16** (sustained ember-rise + camera ease-in to 1.5×).

## Why the camera arrived this late

Pre-T9, the M1 play loop ran with **no Camera2D**. The viewport's `stretch/mode="canvas_items"` setting stretched the 480×270 logical room to fill the 1280×720 viewport — an implicit ~2.667× zoom that did the work a Camera2D would normally do. This worked because every M1 scene authored coordinates at the 480×270 logical scale.

The cinematic-layer surfaces in M3 Tier 2 (boss intro nameplate zoom-in, ember-rise zoom-out, future shake) need a single owner of viewport zoom. T9 is that single-owner landing.

## Default-zoom calibration (load-bearing)

**The pre-T9 effective zoom is the viewport-stretch ratio, NOT `Vector2(1, 1)`.**

| Surface | Value |
|---|---|
| Viewport size (`project.godot [display]`) | `1280 × 720` |
| Logical world size (room ColorRect bounds) | `480 × 270` |
| Implicit pre-T9 zoom (canvas_items stretch) | `1280 / 480 = 2.6667` |
| `CameraDirector.BASELINE_ZOOM` constant | `Vector2(2.6667, 2.6667)` |
| Default `_camera.zoom` value at boot | `BASELINE_ZOOM` |

A naive `Camera2D` with `zoom = Vector2(1, 1)` would be **pixel-1:1**, producing a dramatic zoom-in on boot vs the pre-T9 rendering. T9's calibration target was zero observable change: `BASELINE_ZOOM` matches the viewport-stretch ratio exactly.

**Normalized API:** callers don't reach for `BASELINE_ZOOM`. The `request_zoom(target_normalized_scale, duration, anchor)` API takes a **normalized** scale where `1.0` means "default pre-T9 rendering." Internally, `_camera.zoom = BASELINE_ZOOM * normalized`. So:

- `request_zoom(1.0, 0.0)` → `_camera.zoom = (2.6667, 2.6667)` (pre-T9 visual)
- `request_zoom(1.5, 0.9)` → tweens to `_camera.zoom = (4.0, 4.0)` over 0.9 s
- `request_zoom(0.75, 0.4)` → tweens to `_camera.zoom = (2.0, 2.0)` (wider view)

**Why normalized:** if the M1 viewport size ever changes (Sponsor: "let's bump to 1920×1080 for higher screenshot fidelity"), `BASELINE_ZOOM` updates in one place + every caller's normalized value still has the same visual meaning. T13 + T16's design-language scales (1.25×, 1.5×) don't ripple.

## Public API — semantic description

```gdscript
# Idempotent zoom request. anchor == Vector2.ZERO follows player; non-zero pins.
CameraDirector.request_zoom(target_normalized_scale: float, duration: float, anchor: Vector2 = Vector2.ZERO) -> void

# Return to default zoom + player-follow.
CameraDirector.reset_to_player(duration: float = 0.2) -> void

# Live state.
CameraDirector.current_zoom() -> float          # normalized (1.0 == default)
CameraDirector.current_anchor() -> Vector2      # world-space, or player pos in follow mode
CameraDirector.is_following_player() -> bool

# For tests + debug. Callers MUST NOT mutate the Camera2D directly.
CameraDirector.get_camera() -> Camera2D
```

**Idempotence semantics:** `request_zoom(1.5, 0.9, ...)` called twice with identical params while already-at-target is a **no-op** (signal emission suppressed). Different params kill the in-flight tween and start a new one — most-recent call wins. This is the contract T16's ember-rise sequencer relies on for safe re-trigger if the boss-died event fires twice.

**Clamping:** `target_normalized_scale` is clamped to `[MIN_NORMALIZED_ZOOM, MAX_NORMALIZED_ZOOM]` (`[0.5, 4.0]`). Out-of-range values clamp + emit a `WarningBus` warning. `NaN` / `Inf` are explicitly refused.

## HUD-not-zoom guarantee — Godot CanvasLayer immunity

**All M1 UI mounts on `CanvasLayer` nodes** — HUD layer 10, InventoryPanel layer 80, BossDefeatedTitleCard layer 50, DescendScreen layer 100, StatAllocationPanel. Godot `CanvasLayer` is **by definition** immune to `Camera2D` zoom + scroll — it renders directly to the Viewport via its own canvas_transform, not the world's.

This means the "HUD doesn't zoom with camera" requirement is **automatic, not engineered**. No HUD code needs special-casing for the camera. The risk is purely "what if a future engine version changes CanvasLayer semantics?" — pinned by `test_hud_canvaslayer_unaffected_by_camera_zoom` in `tests/test_camera_director.gd`.

**Practical implication:** any future world-space UI (boss healthbars rendered above the boss sprite, damage-number popups, in-world cue rings) must **either**:

1. Live on `CanvasLayer` if it should stay screen-fixed regardless of camera zoom, OR
2. Live in the world (Node2D parented to the room or a mob) if it should follow + zoom with the camera.

There is no "stay world-anchored but don't zoom" intermediate — that's a manual scale-inverse-of-camera-zoom hack and it's been a sharp edge in other Godot projects. Choose one bucket at design time.

## Room-cycle preservation

`Main._load_room_at_index` queue_frees the old room, instantiates the new room, and re-parents the player at `DEFAULT_PLAYER_SPAWN (240, 200)`. The `CameraDirector` autoload:

- **Survives the room swap.** Autoload-scoped; the SceneTree doesn't free it.
- **Re-resolves the player target per-tick.** `_process` checks `is_instance_valid(_target_player)`; if the cached player was freed, it falls back to `get_tree().get_first_node_in_group("player")`. The new player (in the same `"player"` group) is picked up on the next tick.

**No `Main.room_changed` subscription required.** The per-tick fallback handles room-swap, player respawn, and any other reparenting path uniformly. Costs one Dictionary lookup per tick when the cache is stale — cheap.

**Defensive guard:** if the player is freed mid-zoom-tween, the camera holds last-known position. No null-deref, no panic. Pinned by `test_in_flight_zoom_survives_player_node_freed`.

## HTML5 + `gl_compatibility` risk surface

Per [`html5-export.md`](html5-export.md), the WebGL2 renderer diverges from desktop on several axes. For Camera2D specifically:

| `html5-export.md` class | Camera2D risk |
|---|---|
| HDR modulate clamp | None — Camera2D doesn't touch Color values |
| Polygon2D rendering quirks | None direct — Camera2D is a Transform2D write to canvas_transform; doesn't change Polygon2D fragment shading |
| Z-index sensitivity at gl_compatibility | **POSSIBLE at zoom > 1.0×.** Higher zoom may expose z-index ordering bugs the wider native-stretch view masked — neighboring sprites with z-index ties on the same logical layer can flicker / swap order |
| Default-font glyph coverage | None — Camera2D doesn't touch Labels |
| Service-worker cache | None — Camera2D code bundled into the same `.wasm`; cache trap is artifact-swap, not behavior |

**Highest residual risk = z-index ordering at zoom > 1.0×** — most relevant to T16's 1.5× ember-rise. T9 ships at default 1.0× which preserves the pre-T9 stretch behavior exactly; T9's Self-Test Report is the 1.0× baseline. T16's Self-Test Report is the 1.5× gate.

**Visual-verification gate (per `html5-export.md`):** any PR touching Camera2D requires release-build verification. T9 falls within the **escape-clause** workflow when the author can't run Chromium interactively — honest-disclose + Sponsor-soak with explicit probe targets. T16 (Polygon2D + CPUParticles2D + camera zoom > 1.0×) does NOT qualify for the escape clause and requires a local-Godot screenshot before merge.

## `[combat-trace]` observability — Playwright-visible

CameraDirector emits two `[combat-trace]` line shapes in HTML5 (both gated on `DebugFlags.combat_trace_enabled() == OS.has_feature("web")`):

```
[combat-trace] CameraDirector.request_zoom | target=1.500 duration=0.900 anchor=(0.0,0.0)
[combat-trace] CameraDirector.state | zoom=2.6667 pos=(240,200)
```

The `request_zoom` line fires inside the `request_zoom()` API itself — Playwright specs subscribe to assert request firing without poking at GDScript internals. **Today no production code path calls `request_zoom` on boot or during normal play** — only T13 + T16 (Wave 3) will fire it. T9's smoke spec asserts ABSENCE of the trace at boot.

The `CameraDirector.state` line emits every `STATE_TRACE_INTERVAL = 0.25 s` from `_process` (same cadence as `Player.pos`). Payload carries the live engine-units `Camera2D.zoom` and `global_position`. This trace is the canonical Playwright-fixture observability surface for the world↔canvas transform (see § "Playwright-harness implication" below).

If a future caller writes `_camera.zoom = X` directly bypassing the director (and bypassing the migration policy below), the `request_zoom` trace goes silent + the Playwright spec passes vacuously. PR review must flag any direct `Camera2D.zoom` mutation. The `CameraDirector.state` trace would still emit the new live value (since it reads `_camera.zoom` directly), but the bypass would still break the request-side audit.

## Playwright-harness implication — world↔canvas transform

**The pre-T9 assumption that broke.** Before T9 the M1 build had no Camera2D — `viewport.stretch=canvas_items` + `aspect=keep` mapped world coords to canvas pixels 1:1. `tests/playwright/fixtures/mouse-facing.ts` baked this into every helper: `clickAimedAtSpawn`, `clickAtWorldPos`, and the comment "No camera in M1 — world coord == canvas pixel coord." Spec-side mouse-facing tests passed canvas-pixel coords identical to world coords with no translation.

**The post-T9 reality.** `CameraDirector` owns a `Camera2D` snap-following the player at engine zoom `2.6667`. The Camera2D writes `Viewport.canvas_transform` such that:

```
world      = camera.global_position + (canvas_pixel - viewport_center) / camera.zoom
canvas_pixel = (world - camera.global_position) * camera.zoom + viewport_center
```

with `viewport_center = (640, 360)` and `camera.zoom = BASELINE_ZOOM * normalized_request`.

**PR #293 regression (Tess CHANGES_REQUESTED, 2026-05-20).** Three specs in `mouse-direction-attacks.spec.ts` regressed because they computed `targetX = playerX + 200` (a WORLD delta) and passed that directly to `canvas.click({position: {x: targetX, y: targetY}})`. With camera at player (240, 200), canvas click (440, 200) maps back to world (165, 140) — `facing=(-0.8, -0.6)` instead of the expected (+1.0, 0.0). Tess's empirical trace: spec was ✓ on main pre-T9 (run 26099336967); ✘ on PR #293 (run 26182569457).

**The fixture pattern (post-PR-#293).** Every helper in `mouse-facing.ts` now:

1. Computes the desired click position in WORLD coords.
2. Reads the live `[combat-trace] CameraDirector.state` line via `latestCameraState(capture)`.
3. Translates world → canvas via `worldToCanvas(worldX, worldY, cameraState)`.
4. Issues `canvas.click({position: <canvasPixel>})` with the translated coord.

Helpers (`clickAimedAtSpawn`, `clickAtWorldPos`, `clickAimedFromPlayer`, `aimAtWorldPos`) all take a `ConsoleCapture` argument. Pre-PR-#293 call sites without `capture` no longer compile.

Fallback safety: if no `CameraDirector.state` trace has been observed yet (helper called pre-boot or in a build with `combat_trace` disabled), `worldToCanvas` falls back to assuming the camera is at `DEFAULT_PLAYER_SPAWN` with `DEFAULT_ENGINE_ZOOM = 2.6667` — the boot defaults. This is correct on a fresh room load before the player has moved.

**Checklist for new mouse-input Playwright specs.**

1. **Aim in WORLD coords.** Compute the click position relative to spawn, the player's live position (`latestPlayerPos`), or a known mob's world position. NEVER pass canvas-pixel coords expecting them to be world coords.
2. **Use a helper from `mouse-facing.ts`.** The helper handles the world→canvas transform internally. Direct `canvas.click({position: ...})` with raw world coords is a regression.
3. **Pass `ConsoleCapture` to the helper.** The helper reads the live camera state from the capture buffer.
4. **Allow ~500 ms of settle time post canvas-focus.** The `CameraDirector.state` trace emits at 0.25 s cadence — half a second gives one fresh datapoint with margin.
5. **For low-level / custom-aim specs** that compute their own world target, import `worldToCanvas` directly from `mouse-facing.ts` and pass its result to `canvas.click({position: ...})`.

**Pinned by:** `test_camera_state_observable_for_playwright_fixture` in `tests/test_camera_director.gd` — asserts `get_camera().zoom` + `get_camera().global_position` reflect snap-follow state, and the `STATE_TRACE_INTERVAL` cadence constant stays within fixture-expected bounds (≤ 0.5 s).

## Migration policy — what stays, what moves

**Pre-T9 direct camera-position writers (NONE — there was no Camera2D)** are already fully consolidated under `CameraDirector` because the migration is from "no camera" → "single owner," not "many writers" → "one writer."

**Boss self-shake — intentional non-migration in T9:**

`Stratum1Boss._play_climax_shake` tweens the boss's own `position` ±4 px because no Camera2D existed pre-T9. The shake reads as a screen-jolt against the static background — shape-correct, mechanically wrong. T9 does NOT redirect this for three reasons:

1. T9 is a foundational landing — adding a `CameraDirector.shake(...)` API + boss rewire is a second risk surface.
2. Self-shake still reads as a screen-jolt at the cinematic moment. Not broken-broken, just architecturally misplaced.
3. T16 (Wave 3) needs `request_zoom`, NOT `shake`. The shake API is unscoped for M3 Tier 2.

**Follow-up ticket:** `86c9wvh8e` — `feat(camera): CameraDirector.shake(magnitude, duration) — redirect Stratum1Boss._play_climax_shake`. Low priority. The current self-shake stays as a placeholder; the boss-side comment at `Stratum1Boss.gd:1166` references this redirect intention.

**Future writers MUST route through `CameraDirector`.** A direct `Camera2D.zoom = X` or `Camera2D.global_position = Y` write should be flagged in PR review.

## Time-scale interaction (zoom tweens slow with `Engine.time_scale`)

Camera tweens are created via `create_tween()` with no `ignore_time_scale` override — they advance on **scaled `_process` delta**. This means:

- A zoom-in tween fired during a `TimeScaleDirector.freeze(...)` PAUSES until the freeze releases. Resumes from where it stopped.
- A zoom-in tween fired during a `phase_transition` slow (0.3× scale) takes ~3× the wall-clock time to complete.

**This is the intended behavior** for cinematic synchronisation — the camera ease-in to 1.5× during the boss-died freeze (T16) should feel-with the freeze, not race past it. Matches the [`time-scale-director.md` § "Scaled tweens — intentional pause during freeze"](time-scale-director.md) rule.

**If a future cue needs camera motion that ignores time-scale** (e.g. a panic-shake during a freeze for emphasis), it would need to construct its tween with explicit `set_ignore_time_scale(true)`. T9 ships no such surface.

## Cross-references

- [Audio Architecture](audio-architecture.md) — `AudioDirector` autoload + child-puppet pattern (parallel structure)
- [TimeScaleDirector](time-scale-director.md) — sister Director; scaled vs ignored time-scale tween rule
- [HTML5 Export](html5-export.md) — visual-verification gate + gl_compatibility z-index sensitivity
- [Combat Architecture](combat-architecture.md) — boss self-shake current site (`Stratum1Boss._play_climax_shake`)
- `team/devon-dev/camera2d-spike.md` — full spike notes + design rationale (T9 PR landing artifact)
- `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T9 — ticket AC + scope
- `team/uma-ux/boss-intro.md` BI-05 (intro 1.25×) + F2 (1.5× ease-in) — Wave 3 consumers
- `scripts/camera/CameraDirector.gd` — authoritative source for exact signatures
- `tests/test_camera_director.gd` + `tests/playwright/specs/camera-director-smoke.spec.ts` — paired tests

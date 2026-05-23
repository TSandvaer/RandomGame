# Camera Scroll — continuous-scroll follow + world-bounds clamp

> **STATUS — Spike landed on `main` via PR for ticket `86c9xu9yt` (M3 Tier 3 W1 spike). Production wiring landed via PR for ticket `86c9y0zmg` (M3 Tier 3 W2-T1 — S1 light retrofit).** This doc captures the continuous-scroll API contracts + design rationale + production-wiring shape.

## What this is

The **continuous-scroll** feature on `CameraDirector` lets the camera follow a target node smoothly across wider-than-screen volumes — the Diablo / Crystal Project / Hyper Light Drifter pattern Sponsor signed via SI-1 (2026-05-22). It is **additive** on top of T9's snap-follow + zoom (per [`camera-layer.md`](camera-layer.md)) — no T9 behavior is replaced.

Two new pieces of API on the existing `CameraDirector` autoload:

```gdscript
# Engage continuous-scroll follow with a deadzone (half-extents, WORLD pixels).
CameraDirector.follow_target(target: Node2D, deadzone_px: Vector2) -> void

# Set the world-edge clamp rect (WORLD pixels). Camera position is clamped so
# the visible viewport never shows beyond `bounds`.
CameraDirector.set_world_bounds(bounds: Rect2) -> void
```

Plus the symmetric `clear_follow_target()` / `clear_world_bounds()` and getter / live-state accessors. Two new signals: `follow_target_changed(engaged: bool)` and `world_bounds_changed(bounds: Rect2)`.

## Why this arrived in W1 as a spike, not a feature

Per Priya's post-Wave-3 sequencing v1.1 §1 Commitment 1: continuous-scroll camera is the foundation Track 1 — every other Tier 3 surface (S1 retrofit, procgen `assemble_floor`, S2 content authoring) consumes the API. The W1 spike proves the API + math + HTML5 rendering surface before W2 commits to a single design for S1 retrofit + procgen integration.

The spike intentionally:
- Does NOT retrofit S1 (W2 ticket).
- Does NOT touch the procgen `assemble_floor` codepath (Track 1.5 spike + W2 impl).
- Does NOT replace T9's snap-follow as the default — callers opt in.
- Authors a **hand-stitched 3-chunk test scene** (`scenes/spike/CameraScrollSpike.tscn`) for HTML5 visual-verification instead of wiring into the production play loop.

## Public API — semantic description

### `follow_target(target, deadzone_px)` — engage continuous-scroll

Establishes `target` as the camera's per-tick follow source. The camera moves **only** when `target` crosses outside the deadzone rectangle relative to the camera center. Crossings shift the camera so `target` lands AT the deadzone edge in the axis it has crossed — the camera then "catches up" smoothly per tick.

**Per-axis behavior:**
- `abs(target.x - camera.x) <= deadzone_px.x` → camera holds X (target inside X deadzone).
- Crossing right (target.x > camera.x + deadzone_px.x) → camera shifts to `target.x - deadzone_px.x` (target lands AT right edge).
- Crossing left (target.x < camera.x - deadzone_px.x) → camera shifts to `target.x + deadzone_px.x`.
- Y axis is independent of X (same logic; no diagonal coupling).

**Deadzone semantics:** `Vector2(40, 24)` is HALF-extents = an 80×48 freely-moveable WORLD-pixel rectangle. `Vector2.ZERO` collapses to snap-follow on that axis (every target pixel of motion = one camera pixel of motion).

**Validation:**
- `target = null` is treated as `clear_follow_target()`.
- Negative deadzone components are clamped to 0.0 with a `WarningBus` warning.
- `NaN` / `Inf` deadzone components are refused (follow not engaged) with a warning.

**Idempotence:** re-engaging with same target + same deadzone does not emit `follow_target_changed` (avoids signal-spam on per-frame callers).

**Trace surface:** HTML5-only `[combat-trace] CameraDirector.follow_target | target=<Name> deadzone=(X,Y)` per the established trace pattern.

### `set_world_bounds(bounds)` — engage edge-clamp

Constrains the camera position so the **visible viewport** (computed from current engine zoom — `LOGICAL_VIEWPORT_BASE / camera.zoom`) does not show beyond `bounds`.

**Per-axis behavior:**
- `bounds.size.axis <= viewport_world.axis` (bounds narrower than viewport on this axis) → camera centers on the bounds center (target still moves; camera holds — no scrolling past authored content).
- Else → camera position clamped to `[bounds.position + half_viewport, bounds.end - half_viewport]` so the viewport edges align with the bounds edges at the extremes.

**Viewport size derivation:** at `BASELINE_ZOOM = (2.6667, 2.6667)`, viewport is `1280/2.6667 × 720/2.6667 = 480×270` world pixels. At a 1.5× zoom (T16's ember-rise target), viewport shrinks to `320×180`. The clamp recomputes against `_camera.zoom` each tick — a zoom tween in flight does NOT desync the clamp.

**Validation:** negative-size `bounds` is refused with a `WarningBus` warning (no clamp set). Zero-size `Rect2()` is the canonical "disabled" sentinel.

### Composition with T9 zoom + anchor + snap-follow

The per-tick precedence in `_process` (highest → lowest):

1. **Pinned anchor** (`request_zoom(anchor != Vector2.ZERO)`) — holds at world coord. T9 cinematic overrides supersede scroll.
2. **`follow_target`** — deadzone follow; optionally bounds-clamped.
3. **T9 snap-follow** on the `"player"` group — backward-compat default. Also bounds-clamped if `set_world_bounds` is active (the clamp is orthogonal to follow mode).

**Why this order:** a T16-style boss cinematic (`request_zoom(1.5, 0.9, boss_pos)`) should pin the camera to the boss for the duration — overriding any continuous-scroll follow. After `reset_to_player(...)`, the anchor clears and the prior `follow_target` resumes.

## Spike scene — `scenes/spike/CameraScrollSpike.tscn`

Hand-stitched 3-chunk test scene used as the HTML5 visual-verification surface. Demonstrates:

- 3× canvas-width tilemap: three 480×270 ColorRect "floor" chunks at x=0 / 480 / 960. Distinct warm-sandstone tones so chunk seams are visible.
- 2-px-wide ember-orange seam markers at x=479 and x=959 — visible regression-tells for chunk-seam z-index ordering.
- A `PlayerMarker` (CharacterBody2D + 12×16 ColorRect sprite) that WASD-walks at 180 px/s.
- `CameraDirector.follow_target(marker, Vector2(40, 24))` + `set_world_bounds(Rect2(0, 0, 1440, 270))` engaged on `_ready`.
- HUD CanvasLayer (layer 10, matching `Main.gd::_build_hud()`) showing live marker pos / camera pos / mode label — drift-tells for HUD-anchoring regression.

**How to soak it manually** (diag-build pattern per [`html5-export.md`](html5-export.md) § "Diagnostic-build pattern"):

```bash
# 1. Branch off the spike merge SHA.
git checkout -b diag/camera-scroll-spike-soak

# 2. Edit project.godot:
#    run/main_scene="res://scenes/spike/CameraScrollSpike.tscn"
git commit -m "[diag-only] swap main_scene to camera-scroll-spike — TEMPORARY (DO NOT MERGE)"

# 3. Trigger release-build for the diag SHA.
gh workflow run release-github.yml --ref diag/camera-scroll-spike-soak

# 4. Download artifact + extract to a fresh folder; serve via
#    `python -m http.server 8000`; open in incognito with DevTools.

# 5. Walk the marker left → right → left across the full 1440-pixel world.
#    Observe:
#      - Camera follows smoothly through chunks 1→2→3.
#      - Camera clamps visibly at left edge (cam.x ≈ 240) and right edge (cam.x ≈ 1200).
#      - HUD labels in top-left remain pixel-anchored (no drift).
#      - Chunk floors crisp at seams (no z-fight, no gap, no flicker).

# 6. When done: delete the diag branch.
git push origin --delete diag/camera-scroll-spike-soak
```

The Playwright spec `tests/playwright/specs/camera-scroll-spike.spec.ts` activates against the same diag artifact (auto-detects via boot lines; skips cleanly against the production artifact).

## HTML5 + `gl_compatibility` risk surface

| `html5-export.md` class | Camera-scroll risk |
|---|---|
| HDR modulate clamp | None — camera position is a `Transform2D` write |
| Polygon2D rendering quirks | None direct — camera is renderer-agnostic |
| **Z-index sensitivity** | **Highest risk class.** Multi-chunk floor ColorRects all at `z_index = 0` may exhibit draw-order divergence at chunk seams under `gl_compatibility` vs desktop, exposed by the wider camera-scroll viewport that the pre-T9 native-stretch view masked. Same risk-class as PR #137 wedge / PR #291 T6 aftershock. **Mitigated by:** spike scene's seam-marker ColorRects act as a visual regression-tell; Sponsor / author HTML5 soak per the escape clause is the gate of record |
| Default-font glyph coverage | None — no `Label` glyphs in scroll path |
| Service-worker cache | None direct — but cache trap applies to diag-artifact iteration; cache-clear ritual per `html5-export.md` § "Service-worker cache trap" |

**HTML5-specific quirks empirically discovered during spike-time soak:** TBD — to be appended by the W2 S1-retrofit impl PR once Sponsor-soak reports on the spike build. If no quirks surface during the W2 soak, this section will be marked "no HTML5 divergence observed at spike scope."

## Bounds-clamp math — viewport-aware

The clamp is intentionally viewport-aware so a future zoom change (T16's 1.5×, a Sponsor soak `?camera_zoom=...` hook) automatically maintains the "viewport edge aligns with bounds edge" invariant. The math:

```
viewport_world.x = LOGICAL_VIEWPORT_BASE.x / camera.zoom.x  # 480 at baseline, 320 at 1.5×
half_vp.x = viewport_world.x * 0.5

if bounds.size.x <= viewport_world.x:
    camera.x = bounds.position.x + bounds.size.x * 0.5  # center on bounds
else:
    camera.x = clamp(candidate.x,
        bounds.position.x + half_vp.x,
        bounds.end.x - half_vp.x)
```

The pure-function helper `_clamp_to_world_bounds(camera_pos, bounds)` is callable from tests without requiring a live `_camera` (falls back to `BASELINE_ZOOM` when `_camera == null`, defensively). Pinned by `test_clamp_inside_bounds_position_unchanged` + `test_clamp_pushes_camera_off_*_edge` + `test_clamp_bounds_narrower_than_viewport_centers_camera` + `test_clamp_bounds_with_non_zero_origin`.

**Subtle case — bounds.size == viewport.size:** the comparison uses `<=`, so `bounds.size.y == viewport_world.y` (i.e., a `Rect2(0, 0, 1440, 270)` at default zoom — 270 == 270 on Y) takes the "narrower than viewport" branch and centers the camera on `bounds.y center`. This is the spike scene's exact Y-axis case. For a future 2-chunk-tall scene (1440 × 540), the Y axis would take the clamp branch.

## Deadzone math — independent axes

Pure function `_compute_deadzone_follow_position(camera_pos, target_pos, deadzone)` returns the new camera position given the current camera, the target, and the deadzone half-extents. Per-axis independence is the load-bearing property: a target moving diagonally past the X deadzone but still inside the Y deadzone shifts the camera on X only.

```
dx = target.x - camera.x
if abs(dx) > deadzone.x:
    result.x = target.x - sign(dx) * deadzone.x  # target lands AT edge
# Y axis runs the same logic, independently.
```

**Strict-greater comparison:** target exactly AT deadzone edge (dx == deadzone.x) → camera holds. This avoids per-frame jitter when the target oscillates around the edge by sub-pixel amounts.

Pinned by `test_deadzone_inside_box_camera_holds_x_and_y`, `test_deadzone_target_at_edge_camera_holds`, `test_deadzone_target_crosses_x_camera_shifts_to_pin_target_at_edge`, `test_deadzone_target_crosses_negative_x_camera_shifts_left`, `test_deadzone_axes_independent_x_only_y_held`, `test_deadzone_zero_collapses_to_snap_follow`.

## HUD-immunity invariant preserved

CanvasLayer-anchored HUD remains immune to the continuous-scroll path — the W1 spike adds a new path that writes `_camera.global_position`, which is the same engine-level mutation T9 already does. Godot `CanvasLayer` semantics make the immunity automatic, not engineered.

**New paired pin:** `test_hud_canvaslayer_unaffected_by_continuous_scroll` — exercises the `follow_target` + `set_world_bounds` path (rather than the T9 zoom path the existing `test_hud_canvaslayer_unaffected_by_camera_zoom` covers) and asserts the HUD label's screen-space position is unchanged. If a future refactor reaches up to mutate CanvasLayer transforms via the camera, this catches it.

## Production wiring (M3 Tier 3 W2-T1, ticket `86c9y0zmg`)

The W1 spike landed the API + math + HTML5 rendering surface. **W2-T1 wires the production play loop (`Main.tscn` + `Stratum1BossRoom.tscn`) to engage the API on every room load.** "Light retrofit" means engaging follow-target + bounds-clamp without widening rooms to multi-chunk — current S1 rooms are 480×270 viewport-native, so the bounds-clamp's "narrower than viewport" branch holds the camera at bounds-center every tick (zero visual change vs the pre-T9 viewport-stretch shape, with the production code path now ready to consume `AssembledFloor.bounding_box_px` from the procgen impl W2-T3+).

### Main.gd — `_engage_camera_for_room()` helper

`Main.gd` declares two constants near `DEFAULT_PLAYER_SPAWN`:

| Constant | Value | Purpose |
|---|---|---|
| `S1_ROOM_BOUNDS` | `Rect2(0, 0, 480, 270)` | Viewport-native bounds for current S1 authored rooms |
| `CAMERA_FOLLOW_DEADZONE` | `Vector2(40, 24)` | Half-extents — matches the W1 spike scene's authored deadzone |

`_load_room_at_index(idx)` calls `_engage_camera_for_room()` **after** the player has been re-parented into the new room (so the closure target is alive) and **before** `_wire_room_signals` (so signal-ordering coupling is impossible). The helper soft-resolves `CameraDirector` and bails cleanly in bare-test surfaces without the autoload.

```gdscript
func _engage_camera_for_room() -> void:
    if _player == null:
        return
    var cd: Node = _camera_director()
    if cd == null:
        return
    if cd.has_method("follow_target"):
        cd.follow_target(_player, CAMERA_FOLLOW_DEADZONE)
    if cd.has_method("set_world_bounds"):
        cd.set_world_bounds(S1_ROOM_BOUNDS)
```

**Idempotence on room-cycle.** Per the spike's idempotence semantics, re-engaging with the same target + same deadzone emits no `follow_target_changed` signal; re-setting the same `Rect2` bounds is a no-op. So a player traversing Room 01 → Room 02 → Room 01 → Room 02 receives 4 engage calls and exactly ONE `follow_target_changed(true)` emission (at boot). Pinned by `test_main_engage_camera_idempotent_on_room_swap` in `tests/test_main_camera_wiring.gd`.

### Stratum1BossRoom.gd — `_engage_camera_for_boss_room()` helper

The boss room has its own engage path inside `_assemble_room_fixtures` (the deferred fixture pass that runs one frame after `_ready`, OUTSIDE the physics-flush window). Two constants:

| Constant | Value | Purpose |
|---|---|---|
| `BOSS_ROOM_BOUNDS` | `Rect2(0, 0, 480, 270)` | Today identical to S1 rooms; a future widened-boss-room ticket updates here |
| `BOSS_ROOM_FOLLOW_DEADZONE` | `Vector2(40, 24)` | Matches Main's authored deadzone |

The boss room's `_engage_camera_for_boss_room()` fires at the **tail** of `_assemble_room_fixtures` (after `trigger_entry_sequence()`), so a future ticket can add bounds-overriding work inside the entry-sequence trigger without conflicting with the room's authored bounds. The player is resolved via `get_tree().get_first_node_in_group("player")` (matches `CameraDirector._process`'s per-tick fallback).

**Why the boss room has its own engage when Main already engages on `_load_room_at_index(BOSS_ROOM_INDEX)`:** symmetry + defensive-in-depth. Main's call covers the production room-load path; the boss room's own call:

1. Self-contains the boss-room engage for tests that bare-instantiate the controller (e.g. `test_room_advance_only_on_door_walk`).
2. Provides the hook for future widened-boss-room work without requiring a Main.gd edit.
3. Re-asserts the contract AFTER the deferred fixture pass drains — `_build_door_trigger` + `_spawn_stratum_exit` + `_spawn_boss_nameplate` all run from the deferred pass; if any of those ever mutate camera state (none do today), the engage call here is the final word.

The double-engage is benign per idempotence.

### Wiring sites — quick reference

| File | Line | Call site |
|---|---|---|
| `scenes/Main.gd` | `_load_room_at_index` | `_engage_camera_for_room()` after `room.add_child(_player)` |
| `scenes/Main.gd` | `_engage_camera_for_room` | Helper near bottom of file (alongside `_camera_director`) |
| `scripts/levels/Stratum1BossRoom.gd` | `_assemble_room_fixtures` | `_engage_camera_for_boss_room()` after `trigger_entry_sequence()` |
| `scripts/levels/Stratum1BossRoom.gd` | `_engage_camera_for_boss_room` | Helper near bottom of file (alongside `_resolve_camera_director`) |

### Tests pinning the wiring

| Test | Surface | Bug class caught |
|---|---|---|
| `tests/test_main_camera_wiring.gd::test_main_load_room_calls_engage_camera_after_player_reparent` | Source-scan structural | Ordering refactor that moves engage before player re-parent |
| `tests/test_main_camera_wiring.gd::test_main_engage_camera_helper_calls_follow_target_and_set_world_bounds` | Source-scan structural | Refactor that drops one of the two API calls (e.g. follow_target only) |
| `tests/test_main_camera_wiring.gd::test_boss_room_assemble_fixtures_calls_engage_camera_at_tail` | Source-scan structural | Boss-room ordering refactor that fires engage before entry-sequence trigger |
| `tests/test_main_camera_wiring.gd::test_main_boot_engages_camera_against_player_with_authored_constants` | Behavioural (bare-instance Main) | Wiring drift (different deadzone, different bounds, different target) |
| `tests/test_main_camera_wiring.gd::test_main_engage_camera_idempotent_on_room_swap` | Behavioural | Per-room signal-spam regression |
| `tests/playwright/specs/camera-scroll-production.spec.ts` | HTML5 release-build | Production-artifact wiring regression (Self-Test Report gate satisfaction surface) |

### Forward-compat — AssembledFloor.bounding_box_px swap (W2-T3+)

PR #344 (W2-T3, ticket `86c9xub9p`) landed `FloorAssembler.assemble_floor(zone_def, seed) -> AssembledFloor` with `bounding_box_px: Rect2`. Main.gd does NOT consume this yet — room loads still go through `ROOM_SCENE_PATHS` + authored `.tscn` instantiation. When the procgen W2-T3-impl PR swaps `_load_room_at_index` to consume `AssembledFloor`, `_engage_camera_for_room()` should switch its source from `S1_ROOM_BOUNDS` to `assembled.bounding_box_px`. Per `procgen-pipeline.md` § "AssembledFloor output shape", this is the planned downstream-consumer integration point.

Until that swap lands, the authored `Rect2(0, 0, 480, 270)` is the source of truth. The bounds value is centralised in ONE place (`Main.S1_ROOM_BOUNDS`) so the swap is a single-file edit.

## Open follow-ups (NOT in the spike PR)

- **W2 S1 retrofit ticket** — wire `CameraDirector.follow_target(player, ...)` into `Main.gd` / room scripts; widen Stratum-1 rooms to multi-chunk wherever the scrolling shape demands; set per-room `set_world_bounds` based on chunk-assembled room bounds. **PARTIAL LANDED PR for ticket `86c9y0zmg` (W2-T1 light retrofit)** — wires the API on every room load with authored 480×270 bounds; widening + procgen-bounds swap is the W2-T3+ work that consumes this wiring. See § "Production wiring" above.
- **W2 procgen integration** — `assemble_floor` produces multi-chunk room compositions; `Main._load_room_at_index` calls `set_world_bounds(assembled_bounds)` after assembly.
- **Soft-lerp follow** — current design is deadzone-edge snap (within deadzone: hold; crossing: shift target to edge). A future tuning ticket may add a per-tick lerp (~0.1 s catch-up) for "feel." Default snap is zero feel-change vs T9 within the deadzone; the spike's `Vector2(40, 24)` deadzone is large enough that single-frame snap is imperceptible. Sponsor decision; tag for Uma direction after W2 retrofit.
- **Camera-shake redirect** (`86c9wvh8e`) — unchanged from T9's open follow-up. Independent surface.
- **Spike URL-param hook** — a future `?spike=camera-scroll` URL param in Main.gd could replace the diag-build-pattern soak with a one-click incognito-tab activation. Out of scope for spike PR (touches production Main.gd).

## Cross-references

- [Camera Layer](camera-layer.md) — T9 zoom + HUD-immunity reference doc
- [HTML5 Export](html5-export.md) — visual-verification gate + diagnostic-build pattern
- [Audio Architecture](audio-architecture.md) — sister Director pattern
- [TimeScaleDirector](time-scale-director.md) — sister Director; scaled-tween interaction
- `scripts/camera/CameraDirector.gd` — authoritative source for exact signatures
- `scripts/spike/CameraScrollSpike.gd` + `scenes/spike/CameraScrollSpike.tscn` — spike scene
- `tests/test_camera_director.gd` — paired GUT pins (W1 additions in the "M3 Tier 3 W1" section)
- `tests/playwright/specs/camera-scroll-spike.spec.ts` — HTML5 spec (diag-build-gated)
- `team/priya-pl/post-wave3-sequencing.md` §1 Commitment 1 + §4 W1 — W1 brief
- ClickUp `86c9xu9yt` — W1 spike ticket

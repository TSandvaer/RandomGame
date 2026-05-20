# Camera2D Spike — M3 Tier 2 Wave 2 T9 (`86c9wjyf3`)

**Question:** Can a Camera2D autoload land in the M1 play loop without breaking HTML5 export, room-load pipeline, or HUD anchoring?

**Answer:** Yes — with a constrained design that lands in this PR. Detail below.

---

## §1. Current state survey

| Surface | Today | Implication |
|---|---|---|
| **Viewport** | `1280×720` from `project.godot [display]`; `stretch/mode="canvas_items"`, `stretch/aspect="keep"`. Room ColorRects + walls live at `(0,0)→(480,270)` per `Stratum1BossRoom.tscn` etc. | The viewport stretches a 480×270 logical room to fill 1280×720 — that scale (~2.67×) is the implicit "1.0× zoom" pre-Camera2D. A Camera2D with `zoom = Vector2(1, 1)` overrides this and shows pixel-1:1 (much closer-in). Default zoom MUST account for this delta or every player sees a sudden zoom-in on boot. |
| **Camera2D presence** | **Zero** Camera2D nodes in any `.tscn` (grep'd `scenes/`). The viewport's native stretch is doing the camera's job. | Adding ANY Camera2D triggers Godot's "make_current" path the first time it processes — once added, this is the new default. No partial / per-scene rollout. |
| **Renderer** | `gl_compatibility` (WebGL2) per `project.godot [rendering]`. HTML5 export uses the same. | `.claude/docs/html5-export.md` flags Polygon2D + z-index + HDR-clamp sharp edges. Camera2D itself is renderer-agnostic — it's a `Transform2D` write to the viewport's canvas_transform. Empirically Godot 4.3's `gl_compatibility` handles Camera2D fine; the risk is in what Camera2D's zoom EXPOSES (mob/floor edge clipping that didn't reproduce at the wider native-stretch view). |
| **HUD layering** | Every UI surface mounts on `CanvasLayer` — HUD layer 10, InventoryPanel 80, BossDefeatedTitleCard 50, DescendScreen 100. Built in `scenes/Main.gd::_build_hud()`. | **Godot CanvasLayer is intrinsically immune to Camera2D transforms.** This is the architectural lock — the HUD-doesn't-zoom requirement is automatically satisfied, not something the camera code engineers. Pinned by `test_hud_does_not_zoom_with_camera`. |
| **Room handoff** | `Main._load_room_at_index` `queue_free`s old room, instantiates new room, re-parents Player into the new room, sets `Player.position = DEFAULT_PLAYER_SPAWN (240, 200)`. Player is in the `"player"` group; rooms read group at room-script `_ready`. | Camera2D MUST follow player through room swaps. Autoload survives — but it must re-resolve its target after each `room_changed`. Drives the design choice in §2. |
| **Self-shake** | `Stratum1Boss._play_climax_shake` tweens the boss's own `position` ±4 px because no Camera2D existed. Comments explicitly call out: "When Devon adds a real Camera2D in M2, this can be re-routed to a CameraShake autoload without changing the cue shape." | T9 does NOT redirect this. Decision in §4. |

---

## §2. Design decision — autoload + Camera2D-as-child

**Picked shape:** `CameraDirector` is registered as an **autoload `Node`** (not the Camera2D itself). Internally, `CameraDirector` owns a single `Camera2D` child that gets re-parented to the active `Viewport`'s root each time the room cycles. Public API is on the autoload node; the Camera2D is implementation detail.

**Why autoload-with-internal-Camera2D, not Camera2D-as-direct-autoload:**

1. **Autoload Camera2D directly is a `Node2D` parented to the SceneTree root.** Godot 4.3's Camera2D walks UP its parent chain to find the Viewport it should drive. With the root SceneTree as parent, the Camera2D becomes "current" on the root Viewport — works in practice, but mixes "global service" with "node-in-the-world" semantics. The same pattern bit us in the AudioDirector→AudioStreamPlayer scaffold (two-child slot pattern, see `audio-architecture.md`).
2. **Autoload Node + child Camera2D mirrors the AudioDirector + TimeScaleDirector pattern.** Single owner, child does the engine work, autoload exposes the API. Consistent with prior architecture decisions.
3. **The Camera2D needs to follow the player across room swaps.** Position is read each `_process` from `_target_node.global_position` if set, else stays at `_anchor_override`. The autoload survives `room_changed`; the Camera2D node is just the engine-facing puppet.

**Public API (minimal — Wave 2 floor):**

```gdscript
# Idempotent zoom request. anchor == Vector2.ZERO means "follow player" (default).
# Non-zero anchor pins the camera to that world coord for the duration.
CameraDirector.request_zoom(target_scale: float, duration: float, anchor: Vector2 = Vector2.ZERO) -> void

# Drop the active zoom + return to player-anchored 1.0× over `duration` seconds.
CameraDirector.reset_to_player(duration: float = 0.2) -> void

# Live state read (for tests + future debug overlay).
CameraDirector.current_zoom() -> float
CameraDirector.current_anchor() -> Vector2
CameraDirector.is_following_player() -> bool
```

**Idempotence semantics:** `request_zoom(1.5, 0.9, ...)` called twice in the same frame replaces the in-flight tween — the second call wins, tweening from current-state to new-target. Same pattern as `TimeScaleDirector.request` (re-request replaces). This is the contract T16 (Wave 3 ember-rise + camera ease-in to 1.5×) needs.

---

## §3. Default-zoom calibration (load-bearing)

**The pre-Camera2D effective zoom is the viewport-stretch ratio**, NOT `Vector2(1, 1)` on a Camera2D. The viewport is `1280×720` and the world is `480×270` → effective scale ~2.67×. A Camera2D with `zoom = Vector2(1, 1)` is **pixel-1:1**, which would zoom IN dramatically vs the pre-Camera2D state.

**Camera2D zoom semantics in Godot 4.3:** higher `zoom` = closer in. `zoom = Vector2(2, 2)` doubles the apparent size. `zoom = Vector2(0.5, 0.5)` zooms out (more world visible).

**Calibration target — default zoom = `Vector2(2.667, 2.667)` (approximately):** matches the `1280/480 = 2.6667` viewport stretch ratio. Result: pixel-perfect match to pre-Camera2D rendering, zero observable change on boot.

**Implementation detail — `request_zoom(target_scale: float, ...)`:** the `target_scale` parameter is the **normalized** scale (1.0 = default, 1.5 = T16's ease-in target). Internally, the autoload multiplies by the calibrated baseline so `request_zoom(1.0, 0.0)` produces `Vector2(2.667, 2.667)` and `request_zoom(1.5, 0.9)` produces `Vector2(4.0, 4.0)`. Callers think in design-language scales, not engine units.

**Why a normalized API:** if a future refactor changes the viewport size (Sponsor: "let's bump the M1 viewport to 1920×1080 for screenshot quality"), the baseline updates in one place — the Camera2D math doesn't ripple. Callers stating `request_zoom(1.5)` get the SAME visual result.

---

## §4. Boss self-shake — stays boss-side for T9

**Decision: do NOT redirect `_play_climax_shake` in T9.** Three reasons:

1. **T9 is foundational, not consuming.** This PR's risk surface is "does Camera2D-in-HTML5 work cleanly without regressing M1 play loop?" Adding a CameraShake autoload + re-wiring the boss adds a second test surface (a CameraShake API + boss integration) and stacks unknowns. Cut.
2. **Self-shake reads as a screen-shake against the static background today.** Per the boss-side comment: the cue is shape-correct (±4 logical px) but mechanically wrong (shakes the boss, not the camera). Once Camera2D is in, a follow-up ticket can introduce `CameraDirector.shake(magnitude, duration)` and the boss subscribes. Not blocking M3-Tier-2.
3. **Wave 3 T16 doesn't need `shake` — it needs `request_zoom` (ease-in to 1.5×).** Both T13 and T16 explicitly call out `request_zoom` as the API surface. Shake is unscoped for M3 Tier 2.

**Future ticket:** `feat(camera): CameraDirector.shake() — redirect Stratum1Boss._play_climax_shake`. Low priority. Filed mentally; not raised as a separate ClickUp ticket until T13/T16 land and the shape settles.

---

## §5. HTML5 risk surface enumeration

`.claude/docs/html5-export.md` flags four known classes — for each, the Camera2D effect:

| Class | Risk for Camera2D? | Verification |
|---|---|---|
| **HDR modulate clamp** | No. Camera2D doesn't touch `Color` values. | n/a |
| **Polygon2D rendering quirks** | No direct interaction; Camera2D zoom does NOT change how Polygon2D fragments are rendered — it changes the canvas_transform. Empirically: no Polygon2D nodes exist in M1 rendering paths post-PR-#137 (Polygon2D wedge swapped for ColorRect). | n/a |
| **Z-index sensitivity (gl_compatibility)** | **Possible.** Camera2D zoom-in MAY expose z-index ordering bugs that the wider native-stretch view masked. Specifically: at higher zoom, neighboring sprites with z-index ties on the SAME logical-z can flicker / swap order in gl_compatibility. | Playwright spec `camera-zoom-smoke.spec.ts` exercises Room 01 → Room 02 → boss-room cycle at default zoom + asserts no `USER WARNING:` or panic lines. Sponsor-soak the release build for visual z-index sanity. |
| **Default-font glyph coverage** | No. Camera2D doesn't touch Labels. | n/a |
| **Service-worker cache** | No. Camera2D code is bundled into the same `.wasm` blob; the cache trap is about artifact-swap, not Camera2D behavior. | n/a |

**Highest residual risk:** z-index ordering at zoom levels > 1.0× (T16's 1.5×) when ember particles + boss death-sprite + room floor overlap in z. **Mitigation:** T16 (Wave 3) is the layer that exercises this — its Self-Test Report is the gate. T9 ships at 1.0× default and surfaces the API shape; Sponsor-soak of THIS PR is the 1.0× baseline. If T9 boot-soak shows zero z-index flicker, T16 inherits a clean baseline.

**Visual-verification gate (per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate"):** PR touches Camera2D — gate applies. Self-Test Report attaches release-build evidence; no `Polygon2D` / `CPUParticles2D` / `Area2D-state` mutations on this PR (the gate's "MUST require screenshot from local-Godot" sub-clause does NOT apply), but tween + modulate are touched (zoom-tween) — the **escape clause** workflow applies if author can't run Chromium interactively. See PR Self-Test Report.

---

## §6. Room-load pipeline interaction

**Today:** `Main._load_room_at_index` queue_frees the old room, instantiates the new room, re-parents Player. Player.position resets to `DEFAULT_PLAYER_SPAWN (240, 200)`.

**With CameraDirector:** the autoload survives the room swap (autoload-scoped). The Camera2D child needs to:

1. **Stay parented to the SceneTree** (specifically, to the Viewport's root, via the autoload's own `_ready` add-to-scene). Not parented to the room, not parented to the player.
2. **Re-resolve its player target on `Main.room_changed`** — Player is re-parented into the new room and stays in the `"player"` group; the autoload subscribes to `room_changed` (or polls the group on each `_process`) and re-grabs the player reference.

**Picked: subscribe to `Main.room_changed` IF Main is reachable, else fall back to per-frame group-lookup.** The autoload's `_ready` enqueues a deferred `_late_wire()` that scans `get_tree().root` for a `Main` instance and connects. If `Main` is not a parent (test contexts, future menu scenes), the autoload still works via group-lookup polling — it just costs a `get_tree().get_first_node_in_group("player")` call per `_process` (cheap; one Dictionary lookup).

**Defensive pattern:** the autoload tracks `_target_player: Player` as a `WeakRef`-equivalent (just a Node reference + `is_instance_valid` check before each `global_position` read). If the player was freed and the autoload didn't yet re-resolve, it falls back to the last-known anchor and the camera holds position until the next room is wired. No null-deref, no crash.

---

## §7. Testing plan

### GUT (headless engine)

`tests/test_camera_director.gd` covers:

1. Autoload registration + boot-time state (zoom=1.0 normalized, following-player=true).
2. `request_zoom(target, duration, anchor)` applies — `current_zoom()` reflects the request after the duration.
3. `request_zoom` is idempotent — second call with same params is a no-op (no re-fire of tween if state is already-at-target).
4. `request_zoom` with new params replaces in-flight tween.
5. Anchor handling — `Vector2.ZERO` follows player; non-zero pins to world coord.
6. `reset_to_player(duration)` returns to default zoom + player-follow.
7. Room-cycle preservation — across a `Main.room_changed` emission the autoload re-resolves player + camera follows new player position.
8. **HUD-not-zoom invariant** — assert that a HUD child Control's `global_position` is unchanged after a 1.5× zoom request applies. This is the load-bearing test; if Godot ever changes CanvasLayer semantics, this catches it.
9. Boot-state sanity — `Engine.time_scale = 1.0`, zoom = default, no leaked tween.

### Playwright (HTML5 release-build)

`tests/playwright/specs/camera-zoom-smoke.spec.ts` covers:

1. Build boots with `[CameraDirector] ready` line in console.
2. No `USER WARNING:` or `USER ERROR:` during boot or during the first room-cycle.
3. Camera2D-instrumentation `[combat-trace]` line emitted on `request_zoom` (HTML5-only gate per `DebugFlags.combat_trace`).
4. Boot → first room cycle → no panic, no z-index regression-warning.

### Self-Test Report

Per `html5-visual-verification-gate`: release-build artifact + visual screenshots / boot-line evidence. Probes:

- **Probe A: default-zoom matches pre-Camera2D rendering** — pixel-1:1 comparison of Room01 floor + player position before/after the PR. Net delta should be zero.
- **Probe B: HUD anchored at screen-space** — HP bar top-left, room label top-right, build-SHA bottom-left position unchanged.
- **Probe C: room-cycle (Room01 → Room02 → ... → BossRoom) doesn't leak camera state** — player remains centered each room.
- **Probe D: `request_zoom(1.5, 0.9, Vector2.ZERO)` triggered via a temporary `?camera=1.5` URL-param debug hook (added to head_include + gated)** — visual confirmation that zoom-in happens + HUD does NOT zoom. (Optional probe; if I can't add the URL hook in scope, defer to T13/T16 integration verification.)

Per the escape clause: if I can't run Chromium interactively, honest-disclose + route to Sponsor with the explicit probe list above.

---

## §8. Open follow-ups (NOT in this PR)

- **CameraShake API** — when `Stratum1Boss._play_climax_shake` redirects. Filed for follow-up after T13/T16.
- **`?camera=<scale>` URL-param probe hook** — debug-tooling addition via `head_include` pattern from `html5-export.md`. Useful for Sponsor-soak of T13/T16; defer until those tickets are in flight.
- **Smoothing / lerp on follow** — current design snaps to player position each `_process`. Sponsor may want a soft-lerp follow (~0.1 s catch-up) for "feel." Default is snap (zero feel-change vs pre-Camera2D). Tag for Uma direction post-T9.
- **`InventoryPanel` time-slow + camera interaction** — InventoryPanel still pokes `Engine.time_scale` directly (per `time-scale-director.md` § "Migration policy"). Camera tweens use scaled delta by default — if InventoryPanel slows time while a zoom is in flight, the zoom slows too. ACCEPTABLE for M3 Tier 2 (the inventory pause is a cinematic moment; the zoom feels-with-it like the title card). Document; do not engineer around.

---

## §9. Cross-references

- [`.claude/docs/html5-export.md`](../../.claude/docs/html5-export.md) — visual-verification gate + escape clause
- [`.claude/docs/audio-architecture.md`](../../.claude/docs/audio-architecture.md) — autoload + child puppet pattern (AudioDirector)
- [`.claude/docs/time-scale-director.md`](../../.claude/docs/time-scale-director.md) — director pattern + idempotent-request shape
- `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T9 (lines ~324–338) — AC + ticket scope
- `team/uma-ux/boss-intro.md` BI-05 (intro camera 1.25×) + F2 (ember-rise + camera 1.5×) — Wave 3 consumers
- `scripts/mobs/Stratum1Boss.gd::_play_climax_shake` — current placeholder self-shake (lines 1162–1187)

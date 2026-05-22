extends Node
## CameraDirector autoload — single owner of the M1 play-loop Camera2D + zoom API.
##
## **Ticket 86c9wjyf3 — M3 Tier 2 Wave 2 T9.**
##
## ## Why this exists
##
## Pre-T9, the M1 play loop had NO Camera2D — the 1280×720 viewport stretched
## the 480×270 logical world to fill the screen via `stretch/mode="canvas_items"`.
## Wave 3 cinematic work (T16 sustained ember-rise + camera ease-in to 1.5×;
## T13 intro nameplate camera context; future CameraShake) needs a single owner
## of viewport zoom + anchor. This director is that owner.
##
## ## Design pattern
##
## Mirrors `AudioDirector` + `TimeScaleDirector`: an autoload Node owns a single
## engine-facing puppet (here, a Camera2D added as a child of the autoload at
## `_ready`). The autoload exposes the API; the Camera2D itself is implementation
## detail. Callers never reach for the Camera2D directly.
##
## ## API
##
##   request_zoom(target_scale, duration, anchor) -> void
##       Tween the camera zoom to `target_scale` (normalized — 1.0 == default
##       pre-Camera2D rendering, 1.5 == T16's ease-in target) over `duration`
##       seconds. `anchor == Vector2.ZERO` means "follow player" (default);
##       a non-zero anchor pins the camera to that world coordinate for the
##       duration of the zoom request. Idempotent — re-requesting with the
##       same {scale, duration, anchor} while already in-flight is a no-op;
##       different params replace the in-flight tween (the new call wins).
##
##   reset_to_player(duration) -> void
##       Tween back to default zoom (normalized 1.0×) and re-attach to player-
##       follow. Equivalent to `request_zoom(1.0, duration, Vector2.ZERO)`.
##
##   current_zoom() -> float
##       Live normalized zoom (1.0 == default). For tests + debug overlays.
##
##   current_anchor() -> Vector2
##       Live world-space camera anchor. If following player, returns the
##       player's last-known position; if pinned, returns the override.
##
##   is_following_player() -> bool
##       True iff the camera is currently in player-follow mode (anchor zero).
##
## ## Default-zoom calibration (load-bearing)
##
## The viewport stretches 480×270 → 1280×720 via `canvas_items` mode, an
## effective ~2.667× zoom. A Camera2D with `zoom = Vector2(1, 1)` is pixel-1:1
## (no stretch) which would look like a dramatic zoom-IN. To preserve the
## pre-T9 visual exactly, the Camera2D's actual zoom property is set to
## `BASELINE_ZOOM = Vector2(2.667, 2.667)` (1280/480) when callers request
## normalized 1.0×.
##
## Internally: `actual_zoom = BASELINE_ZOOM * normalized_target`. So
## `request_zoom(1.5, ...)` produces `Vector2(4.0, 4.0)` on the Camera2D.
## Callers think in design-language scales (1.0 / 1.25 / 1.5); engine units
## are this module's concern.
##
## ## HUD-not-zoom guarantee
##
## All UI in M1 mounts on `CanvasLayer` nodes (HUD layer 10, InventoryPanel
## layer 80, BossDefeatedTitleCard layer 50, DescendScreen layer 100). Godot
## CanvasLayer is BY DEFINITION immune to Camera2D zoom + scroll — that's
## the architectural lock that makes the HUD-anchoring AC automatic, not
## something this director engineers. Pinned by
## `test_hud_does_not_zoom_with_camera`.
##
## ## Room-cycle preservation
##
## The autoload survives `_load_room_at_index`'s `queue_free` of the old room.
## The Camera2D is parented to the autoload (which is parented to the root
## SceneTree), not to the room. Player-follow re-resolves the player target
## via the `"player"` group each tick — survives any room swap that re-parents
## the player.
##
## ## HTML5 + gl_compatibility
##
## Camera2D is a Transform2D write to `Viewport.canvas_transform`; the renderer
## is unchanged. Empirical risk is z-index ordering at higher zoom levels (T16's
## 1.5×) — addressed by per-PR HTML5 Self-Test Report. T9 ships at default
## zoom; T16 is the gate for non-1.0 zoom visual verification.
##
## ## Open follow-ups (NOT in this PR)
##
##   - `CameraDirector.shake(magnitude, duration)` — redirect target for
##     `Stratum1Boss._play_climax_shake`. ClickUp `86c9wvh8e` (low priority).
##   - `?camera=<scale>` URL-param debug hook for Sponsor-soak of T13/T16.
##
## ## M3 Tier 3 W1 — continuous-scroll follow-target + world-bounds clamp
##   (ticket `86c9xu9yt`, additive on top of T9)
##
## **What's new** — Sponsor signed SI-1 (continuous-scroll camera) 2026-05-22.
## Rooms become wider-than-screen volumes; camera follows the player smoothly
## within a deadzone and clamps at world edges so the player never sees beyond
## authored content. Per-tick snap-follow (the T9 default) is preserved for
## backward compatibility; the new path is opt-in via `follow_target()`.
##
##   follow_target(target: Node2D, deadzone_px: Vector2) -> void
##       Engage continuous-scroll follow mode. Camera tracks `target` but only
##       moves on an axis if the target has crossed outside the deadzone
##       relative to the camera center. The deadzone is HALF-extents in world
##       pixels — `Vector2(40, 24)` means an 80-px-wide × 48-px-tall rectangle
##       around the camera within which the target can roam freely.
##       When the target crosses the deadzone edge, the camera shifts to
##       maintain the target AT the deadzone edge — a Diablo-style "camera
##       catches up to the player at the deadzone edge" behavior. Re-engaging
##       follow_target with a fresh target/deadzone resets state.
##
##   set_world_bounds(bounds: Rect2) -> void
##       Set the world-edge clamp rect (world-space pixels). The camera's
##       position is clamped so the visible viewport (computed from current
##       engine zoom) never shows beyond `bounds`. If `bounds` is smaller
##       than the viewport on an axis, the camera centers on the rect's
##       center on that axis (the player still moves; the camera holds).
##
##   clear_world_bounds() -> void
##       Disable bounds-clamp.
##
##   clear_follow_target() -> void
##       Revert to T9 snap-follow behavior (player-group lookup, no deadzone,
##       no smoothing). The default after boot.
##
## **HUD-immunity preserved.** The new follow path writes only
## `_camera.global_position`. CanvasLayer parents (all M1 UI) remain immune
## per the same Godot architectural guarantee that backs T9 — verified by
## the existing `test_hud_canvaslayer_unaffected_by_camera_zoom` plus the
## new W1 `test_hud_canvaslayer_unaffected_by_continuous_scroll`.
##
## **Zoom preserved.** Zoom requests are orthogonal to follow mode — a zoom
## tween fired during follow_target keeps tracking; the world-bounds clamp
## recomputes against the current engine zoom each tick.
##
## ## References
##
##   - ClickUp `86c9wjyf3` — original T9 ticket (snap-follow + zoom)
##   - ClickUp `86c9xu9yt` — M3 Tier 3 W1 spike (continuous-scroll follow + bounds)
##   - `team/devon-dev/camera2d-spike.md` — original T9 spike doc + design rationale
##   - `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T9 — original AC
##   - `team/priya-pl/post-wave3-sequencing.md` §1 Commitment 1 + §4 W1 — W1 brief
##   - `team/uma-ux/boss-intro.md` BI-05 + F2 — Wave 3 consumers
##   - `.claude/docs/html5-export.md` — gl_compatibility + visual-verification gate
##   - `.claude/docs/camera-layer.md` — full reference (updated with continuous-scroll § by W2 impl PR)


# ---- Constants -------------------------------------------------------

## Viewport base zoom — matches `1280/480 = 2.6667` so a normalized 1.0×
## request produces pixel-perfect parity with the pre-T9 viewport-stretch
## rendering. Pinned to `project.godot [display]` window/size values; if
## those change this constant updates.
##
## NOTE: rounded constant; the exact value `1280/480 = 2.6̄` is irrational
## as a decimal. The 4-digit rounding `2.6667` is within float epsilon
## (~3.3e-5 delta) of behavior parity and is well below the assertion
## tolerance (`is_equal_approx` default ~1e-6 relative). Verified via
## `test_camera2d_exists_and_is_current` + `test_request_zoom_instant_applies_zoom`.
const BASELINE_ZOOM: Vector2 = Vector2(2.6667, 2.6667)

## Normalized zoom that means "default." Callers request 1.0× to return to
## pre-T9 rendering. The autoload multiplies by BASELINE_ZOOM internally.
const DEFAULT_NORMALIZED_ZOOM: float = 1.0

## Clamp bounds on the normalized scale callers can request. 0.5× is "wider
## than default" (Sponsor-soak / debug); 4.0× is "way too close" but reserved
## for cinematic spikes. Out-of-range = WarningBus warning + clamp.
const MIN_NORMALIZED_ZOOM: float = 0.5
const MAX_NORMALIZED_ZOOM: float = 4.0

## Default duration for `reset_to_player()` when no caller-specified value
## is provided.
const DEFAULT_RESET_DURATION: float = 0.2


# ---- Signals ---------------------------------------------------------

## Emitted whenever the live normalized zoom changes (after a tween step
## or instant set). Payload is the new normalized value (1.0-relative,
## NOT the engine `Camera2D.zoom` Vector2).
signal zoom_changed(new_normalized_zoom: float)

## Emitted at start of a zoom request. Payload mirrors the request shape.
## Subscribers: T13 (nameplate slide-in coordination), T16 (ember-rise
## sequencer), debug overlay.
signal zoom_requested(target_normalized: float, duration: float, anchor: Vector2)

## Emitted when continuous-scroll follow mode engages or disengages.
## Payload: `engaged` true on engage; false on `clear_follow_target()`.
## W1 spike (`86c9xu9yt`) consumer surface; W2 impl + Sponsor-soak utility.
signal follow_target_changed(engaged: bool)

## Emitted when the world-bounds clamp engages, changes, or clears.
## Payload is the new clamp rect; `Rect2()` (zero size) means cleared.
signal world_bounds_changed(bounds: Rect2)


# ---- State -----------------------------------------------------------

## The Camera2D node we own. Created in `_ready`; never re-created.
var _camera: Camera2D = null

## Active zoom tween, if any. Nullable. Killed on a new `request_zoom` so
## the most-recent call always wins.
var _zoom_tween: Tween = null

## Active position tween, if any. Used when `anchor` is non-zero — pins
## the camera to the override coord by tweening + then holding.
var _pos_tween: Tween = null

## Live normalized zoom (1.0 == default). Mirror of the engine state; the
## director is the single writer of `_camera.zoom`.
var _current_normalized_zoom: float = DEFAULT_NORMALIZED_ZOOM

## Active anchor mode. `Vector2.ZERO` means "follow player"; any other
## value pins the camera to that world coord.
var _anchor_override: Vector2 = Vector2.ZERO

## Cached player reference, re-resolved per tick via the "player" group.
## Nullable. `is_instance_valid` guard before each read.
var _target_player: Node2D = null

## True when the latest in-flight request matches its own params + state.
## Used by the idempotence guard so a same-params re-request is a no-op.
var _last_request_target_normalized: float = DEFAULT_NORMALIZED_ZOOM
var _last_request_anchor: Vector2 = Vector2.ZERO

## Throttle accumulator for the HTML5-only `CameraDirector.state` trace —
## Playwright-fixture consumers (`tests/playwright/fixtures/mouse-facing.ts`)
## parse the latest emission to translate world coords to canvas-pixel coords
## via the live camera transform. See `.claude/docs/camera-layer.md` §
## "Playwright-harness implication" for the world↔canvas math.
var _state_trace_accum: float = 0.0

## How often the `CameraDirector.state` trace emits. 0.25 s mirrors
## `Player.pos` so the fixture has same-tick datapoints for both player
## position AND camera state when computing aim targets.
const STATE_TRACE_INTERVAL: float = 0.25

## ---- M3 Tier 3 W1 — continuous-scroll follow + bounds-clamp state ----

## Continuous-scroll follow target. When non-null, takes precedence over
## both `_anchor_override` and the T9 snap-follow path. Re-resolves via
## `is_instance_valid` per tick; clears on target free without panic.
var _follow_target: Node2D = null

## Half-extents of the deadzone in WORLD pixels. `Vector2(40, 24)` means
## an 80×48 rectangle around the camera within which the target can move
## freely without shifting the camera. Set by `follow_target()`.
var _follow_deadzone: Vector2 = Vector2.ZERO

## World-edge clamp rect in WORLD pixels. `Rect2()` (zero size) means
## "no clamp." When set, `_process` post-processes the candidate camera
## position to keep the visible viewport (computed from current engine
## zoom) inside the rect.
var _world_bounds: Rect2 = Rect2()

## Viewport size in WORLD pixels at engine zoom 1.0. The viewport is
## 1280×720 in display pixels (`project.godot [display]`). At default
## engine zoom `BASELINE_ZOOM = 2.6667`, the visible WORLD region is
## `1280/2.6667 × 720/2.6667 = 480×270` — the same logical-room size
## that pre-T9 rendering assumed.
const LOGICAL_VIEWPORT_BASE: Vector2 = Vector2(1280.0, 720.0)


# ---- Lifecycle -------------------------------------------------------

func _ready() -> void:
	# Create the Camera2D puppet. Parented to the autoload (which is itself
	# parented to the SceneTree root), so it survives all room swaps.
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.zoom = BASELINE_ZOOM
	# `make_current()` is called when added to the tree if no other Camera2D
	# is current. M1 has no other Camera2D in any scene, so this becomes the
	# active camera on add.
	add_child(_camera)
	_camera.make_current()
	# Defer player resolution one frame so the boot scene (Main) has time
	# to spawn + register the player in the "player" group.
	call_deferred("_resolve_player_target")
	print("[CameraDirector] ready normalized_zoom=%.3f baseline=(%.4f,%.4f)" % [
		DEFAULT_NORMALIZED_ZOOM, BASELINE_ZOOM.x, BASELINE_ZOOM.y])


func _process(delta: float) -> void:
	# Per-tick precedence (highest → lowest):
	#   1. Pinned anchor (T9 `request_zoom(anchor)`) — holds at world coord.
	#   2. Continuous-scroll follow_target (W1 spike) — deadzone follow,
	#      optionally bounds-clamped.
	#   3. T9 snap-follow on the "player" group — backward-compat default.
	# Order matters: a caller that does request_zoom with non-zero anchor
	# during follow_target gets the anchor pin (cinematic supersedes scroll).
	if _camera == null:
		return
	if _anchor_override != Vector2.ZERO:
		# Pinned anchor — _pos_tween (if any) drives position; otherwise hold.
		if _pos_tween == null or not _pos_tween.is_valid():
			_camera.global_position = _anchor_override
	elif _follow_target != null and is_instance_valid(_follow_target):
		# Continuous-scroll mode — deadzone follow.
		var candidate: Vector2 = _compute_deadzone_follow_position(
			_camera.global_position, _follow_target.global_position, _follow_deadzone)
		if _world_bounds.size != Vector2.ZERO:
			candidate = _clamp_to_world_bounds(candidate, _world_bounds)
		_camera.global_position = candidate
	else:
		# T9 snap-follow on the "player" group.
		if _target_player == null or not is_instance_valid(_target_player):
			_resolve_player_target()
		if _target_player != null and is_instance_valid(_target_player):
			var snap_pos: Vector2 = _target_player.global_position
			if _world_bounds.size != Vector2.ZERO:
				snap_pos = _clamp_to_world_bounds(snap_pos, _world_bounds)
			_camera.global_position = snap_pos
	# HTML5-only state trace for Playwright-fixture consumers. Throttled so
	# console doesn't drown in chatter. Mirrors `Player.pos` cadence.
	_state_trace_accum += delta
	if _state_trace_accum >= STATE_TRACE_INTERVAL:
		_state_trace_accum = 0.0
		_emit_state_trace()


## Emit the HTML5-only `CameraDirector.state` trace line. Payload carries
## live engine `Camera2D.zoom` (NOT normalized — fixture wants the engine-units
## value because the world↔canvas math is `canvas = (world - cam.pos) * zoom
## + viewport_center` using engine zoom directly) + current camera position.
##
## Consumed by `tests/playwright/fixtures/mouse-facing.ts::latestCameraState`.
## See `.claude/docs/camera-layer.md` § "Playwright-harness implication".
func _emit_state_trace() -> void:
	if _camera == null:
		return
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("CameraDirector.state",
			"zoom=%.4f pos=(%.0f,%.0f)" % [
				_camera.zoom.x, _camera.global_position.x, _camera.global_position.y])


# ---- Public API ------------------------------------------------------

## Request a zoom change. See class docstring for semantics.
##
## `target_normalized_scale`: 1.0 == default (pre-T9 rendering), >1.0 zooms IN,
## <1.0 zooms OUT. Clamped to [MIN_NORMALIZED_ZOOM, MAX_NORMALIZED_ZOOM]; out-of-range
## emits a WarningBus warning.
##
## `duration`: tween length in seconds. `0.0` snaps instantly. Negative
## clamps to 0.0.
##
## `anchor`: `Vector2.ZERO` (default) means player-follow; any other value
## pins the camera to that world coord for the duration of the request.
## Subsequent `reset_to_player` returns to follow mode.
##
## **Idempotence:** if `target_normalized_scale` and `anchor` match the most
## recent in-flight request, this is a no-op. Different params kill the
## in-flight tween + start a new one (most-recent-call-wins).
func request_zoom(target_normalized_scale: float, duration: float, anchor: Vector2 = Vector2.ZERO) -> void:
	# Validate scale.
	if is_nan(target_normalized_scale) or is_inf(target_normalized_scale):
		_warn(("CameraDirector.request_zoom: non-finite scale (%s) — refusing"
			% str(target_normalized_scale)), "camera_director")
		return
	var clamped: float = clampf(target_normalized_scale, MIN_NORMALIZED_ZOOM, MAX_NORMALIZED_ZOOM)
	if not is_equal_approx(clamped, target_normalized_scale):
		_warn(("CameraDirector.request_zoom: scale %.3f clamped to %.3f (range [%.2f, %.2f])"
			% [target_normalized_scale, clamped, MIN_NORMALIZED_ZOOM, MAX_NORMALIZED_ZOOM]),
			"camera_director")
	var clamped_duration: float = maxf(duration, 0.0)

	# Idempotence: same target + same anchor as the live request, and we're
	# already at the target → no-op. The threshold tolerates float drift.
	if (is_equal_approx(clamped, _last_request_target_normalized)
			and _last_request_anchor == anchor
			and is_equal_approx(_current_normalized_zoom, clamped)
			and (_zoom_tween == null or not _zoom_tween.is_valid())):
		# Already at the requested state; no-op.
		return

	_last_request_target_normalized = clamped
	_last_request_anchor = anchor

	# HTML5-only Playwright-observable trace (per `audio-architecture.md`
	# `[combat-trace]` pattern). The cue_id-style payload lets a Playwright
	# spec assert request_zoom was invoked + with what params, without
	# poking at GDScript internals.
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("CameraDirector.request_zoom",
			"target=%.3f duration=%.3f anchor=(%.1f,%.1f)" % [
				clamped, clamped_duration, anchor.x, anchor.y])

	# Kill in-flight tweens — most-recent call wins.
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
		_zoom_tween = null
	if _pos_tween != null and _pos_tween.is_valid():
		_pos_tween.kill()
		_pos_tween = null

	zoom_requested.emit(clamped, clamped_duration, anchor)

	# Apply zoom (instant or tweened).
	var target_engine_zoom: Vector2 = BASELINE_ZOOM * clamped
	if clamped_duration <= 0.0 or _camera == null:
		if _camera != null:
			_camera.zoom = target_engine_zoom
		_current_normalized_zoom = clamped
		zoom_changed.emit(clamped)
	else:
		_zoom_tween = create_tween()
		_zoom_tween.set_trans(Tween.TRANS_SINE)
		_zoom_tween.set_ease(Tween.EASE_IN_OUT)
		_zoom_tween.tween_property(_camera, "zoom", target_engine_zoom, clamped_duration)
		# Update the live normalized mirror + signal on completion. Use a
		# parallel value-tween of our own state so subscribers see smooth
		# updates each frame.
		_zoom_tween.parallel().tween_method(_on_zoom_tween_step, _current_normalized_zoom, clamped, clamped_duration)
		_zoom_tween.tween_callback(_on_zoom_tween_done.bind(clamped))

	# Apply anchor.
	_anchor_override = anchor
	if anchor != Vector2.ZERO and _camera != null:
		if clamped_duration <= 0.0:
			_camera.global_position = anchor
		else:
			_pos_tween = create_tween()
			_pos_tween.set_trans(Tween.TRANS_SINE)
			_pos_tween.set_ease(Tween.EASE_IN_OUT)
			_pos_tween.tween_property(_camera, "global_position", anchor, clamped_duration)


## Tween back to default zoom (1.0×) + player-follow.
func reset_to_player(duration: float = DEFAULT_RESET_DURATION) -> void:
	request_zoom(DEFAULT_NORMALIZED_ZOOM, duration, Vector2.ZERO)


## Live normalized zoom (1.0 == default). Mirror of the engine state.
func current_zoom() -> float:
	return _current_normalized_zoom


## Live world-space anchor. In follow mode returns player position; in
## override mode returns the pinned anchor. Returns `Vector2.ZERO` if
## both the override is zero AND the player is unresolved.
func current_anchor() -> Vector2:
	if _anchor_override != Vector2.ZERO:
		return _anchor_override
	if _target_player != null and is_instance_valid(_target_player):
		return _target_player.global_position
	return Vector2.ZERO


## True iff the camera is in player-follow mode (anchor override is zero).
func is_following_player() -> bool:
	return _anchor_override == Vector2.ZERO


## Access the underlying Camera2D node. For tests + debug only — callers
## must NOT mutate `zoom` or `global_position` directly; route through the
## director API.
func get_camera() -> Camera2D:
	return _camera


# ---- M3 Tier 3 W1 — continuous-scroll API -----------------------------

## Engage continuous-scroll follow mode against `target`. The camera moves
## smoothly within a deadzone so small target motions don't shake the view;
## crossings of the deadzone edge cause the camera to catch up to maintain
## the target AT the deadzone edge (Diablo-style behavior).
##
## `deadzone_px`: half-extents in WORLD pixels. `Vector2(40, 24)` is an
## 80×48 freely-moveable rectangle. `Vector2.ZERO` (the default) makes
## every target movement immediately translate to camera movement — same
## visual effect as snap-follow, but routed through the continuous-scroll
## codepath (useful for tests that want to exercise the path without
## introducing a deadzone variable).
##
## Negative deadzone components are clamped to 0.0 with a WarningBus
## warning. `null` target is treated as `clear_follow_target()`.
##
## Idempotent: re-engaging with the same target + same deadzone does not
## emit `follow_target_changed` (avoids signal-spam on per-frame callers).
func follow_target(target: Node2D, deadzone_px: Vector2 = Vector2.ZERO) -> void:
	if target == null:
		clear_follow_target()
		return
	# Validate + clamp deadzone.
	if is_nan(deadzone_px.x) or is_nan(deadzone_px.y) or is_inf(deadzone_px.x) or is_inf(deadzone_px.y):
		_warn(("CameraDirector.follow_target: non-finite deadzone (%s) — refusing"
			% str(deadzone_px)), "camera_director")
		return
	var clamped_dz: Vector2 = Vector2(maxf(deadzone_px.x, 0.0), maxf(deadzone_px.y, 0.0))
	if clamped_dz != deadzone_px:
		_warn(("CameraDirector.follow_target: deadzone %s clamped to %s "
			+ "(negative components → 0)") % [str(deadzone_px), str(clamped_dz)],
			"camera_director")

	# HTML5-only Playwright-observable trace.
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("CameraDirector.follow_target",
			"target=%s deadzone=(%.1f,%.1f)" % [
				target.name, clamped_dz.x, clamped_dz.y])

	var was_engaged: bool = _follow_target != null and is_instance_valid(_follow_target)
	var changed: bool = (_follow_target != target) or (clamped_dz != _follow_deadzone) or not was_engaged
	_follow_target = target
	_follow_deadzone = clamped_dz
	if changed:
		follow_target_changed.emit(true)


## Disengage continuous-scroll follow mode. Reverts to T9 snap-follow on
## the "player" group. Idempotent — no-op if not currently engaged.
func clear_follow_target() -> void:
	if _follow_target == null:
		return
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("CameraDirector.follow_target", "cleared")
	_follow_target = null
	_follow_deadzone = Vector2.ZERO
	follow_target_changed.emit(false)


## Set the world-edge clamp rect. The camera position is constrained so
## the visible viewport (computed from current engine zoom) does not show
## beyond `bounds`. Pass `Rect2()` (zero size) or use `clear_world_bounds()`
## to disable. Idempotent on same value.
##
## `bounds` is in WORLD pixels. Example: a 3-chunk scene 1440×270 wide:
## `set_world_bounds(Rect2(0, 0, 1440, 270))`.
func set_world_bounds(bounds: Rect2) -> void:
	if bounds.size.x < 0.0 or bounds.size.y < 0.0:
		_warn(("CameraDirector.set_world_bounds: negative size %s — refusing"
			% str(bounds)), "camera_director")
		return
	if _world_bounds == bounds:
		return
	_world_bounds = bounds
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("CameraDirector.set_world_bounds",
			"pos=(%.0f,%.0f) size=(%.0f,%.0f)" % [
				bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y])
	world_bounds_changed.emit(bounds)


## Disable the world-edge clamp.
func clear_world_bounds() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return
	set_world_bounds(Rect2())


## Live world-edge clamp rect. `Rect2()` (zero size) means "no clamp."
## For tests + debug only.
func get_world_bounds() -> Rect2:
	return _world_bounds


## True iff continuous-scroll follow mode is engaged + the target is alive.
## For tests + debug only.
func is_following_target() -> bool:
	return _follow_target != null and is_instance_valid(_follow_target)


## Live follow-target reference. Nullable. For tests + debug only.
func get_follow_target() -> Node2D:
	if _follow_target != null and is_instance_valid(_follow_target):
		return _follow_target
	return null


## Live deadzone half-extents in WORLD pixels. For tests + debug only.
func get_follow_deadzone() -> Vector2:
	return _follow_deadzone


# ---- Internals -------------------------------------------------------

func _resolve_player_target() -> void:
	if not is_inside_tree():
		return
	var n: Node = get_tree().get_first_node_in_group("player")
	if n is Node2D:
		_target_player = n as Node2D


func _on_zoom_tween_step(value: float) -> void:
	# Called each tween frame; mirror to our normalized cache + emit so
	# subscribers see smooth updates.
	if not is_equal_approx(value, _current_normalized_zoom):
		_current_normalized_zoom = value
		zoom_changed.emit(value)


func _on_zoom_tween_done(final_normalized: float) -> void:
	_current_normalized_zoom = final_normalized
	zoom_changed.emit(final_normalized)
	_zoom_tween = null


## Compute the deadzone-follow camera position for one tick. Pure function:
## given the current camera position, the target's position, and the
## deadzone half-extents, returns the new camera position such that the
## target sits AT the deadzone edge in any axis it has crossed past.
##
## Behavior per axis:
##   - If `abs(target.axis - camera.axis) <= deadzone.axis`: camera holds
##     (target is inside the deadzone — no movement).
##   - Else: camera shifts so the target lands EXACTLY on the deadzone
##     edge in the direction of motion (`target - sign * deadzone`).
##
## A zero-deadzone axis collapses to snap-follow on that axis (camera ==
## target). Negative deadzone components were rejected at `follow_target`
## entry; this helper assumes ≥ 0.
##
## Static-like: no member access except via params. Test-callable.
func _compute_deadzone_follow_position(camera_pos: Vector2, target_pos: Vector2, deadzone: Vector2) -> Vector2:
	var result: Vector2 = camera_pos
	# X axis.
	var dx: float = target_pos.x - camera_pos.x
	if absf(dx) > deadzone.x:
		# Target outside deadzone → shift camera so target lands on edge.
		# If dx > 0, target is to the right; camera moves to target.x - deadzone.x.
		# If dx < 0, target is to the left; camera moves to target.x + deadzone.x.
		result.x = target_pos.x - signf(dx) * deadzone.x
	# Y axis (independent of X).
	var dy: float = target_pos.y - camera_pos.y
	if absf(dy) > deadzone.y:
		result.y = target_pos.y - signf(dy) * deadzone.y
	return result


## Clamp a candidate camera position so the visible viewport stays inside
## `bounds`. Visible viewport is `LOGICAL_VIEWPORT_BASE / engine_zoom`
## (e.g. at zoom 2.6667 the visible world region is 480×270). Camera
## position is the CENTER of the viewport (Godot Camera2D semantics).
##
## Per axis:
##   - If `bounds.size.axis < viewport.axis`: viewport is wider than the
##     bounds on this axis → center the camera on the bounds center
##     (player still moves; camera holds — no "scrolling past content").
##   - Else: clamp camera to `[bounds.position + viewport/2,
##     bounds.end - viewport/2]` so the viewport edges align with the
##     bounds edges at the extremes.
##
## Static-like helper; test-callable.
func _clamp_to_world_bounds(camera_pos: Vector2, bounds: Rect2) -> Vector2:
	var zoom: Vector2 = BASELINE_ZOOM
	if _camera != null:
		zoom = _camera.zoom
	# Guard against zoom = 0 (would be infinite viewport — shouldn't happen
	# given MIN_NORMALIZED_ZOOM 0.5, but defensive).
	var safe_zoom_x: float = zoom.x if zoom.x > 0.001 else BASELINE_ZOOM.x
	var safe_zoom_y: float = zoom.y if zoom.y > 0.001 else BASELINE_ZOOM.y
	var viewport_world: Vector2 = Vector2(
		LOGICAL_VIEWPORT_BASE.x / safe_zoom_x,
		LOGICAL_VIEWPORT_BASE.y / safe_zoom_y)
	var half_vp: Vector2 = viewport_world * 0.5

	var result: Vector2 = camera_pos
	# X axis.
	if bounds.size.x <= viewport_world.x:
		# Bounds narrower than viewport → center on bounds.
		result.x = bounds.position.x + bounds.size.x * 0.5
	else:
		result.x = clampf(camera_pos.x,
			bounds.position.x + half_vp.x,
			bounds.position.x + bounds.size.x - half_vp.x)
	# Y axis.
	if bounds.size.y <= viewport_world.y:
		result.y = bounds.position.y + bounds.size.y * 0.5
	else:
		result.y = clampf(camera_pos.y,
			bounds.position.y + half_vp.y,
			bounds.position.y + bounds.size.y - half_vp.y)
	return result


## Internal warning helper. Routes through WarningBus when available; falls
## back to push_warning when the autoload isn't booted (test contexts).
func _warn(text: String, category: String) -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	var bus: Node = null
	if main_loop is SceneTree:
		bus = (main_loop as SceneTree).root.get_node_or_null("WarningBus")
	if bus != null and bus.has_method("warn"):
		bus.warn(text, category)
	else:
		push_warning(text)

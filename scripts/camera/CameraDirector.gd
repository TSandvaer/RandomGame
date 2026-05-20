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
##     `Stratum1Boss._play_climax_shake`. Filed for follow-up.
##   - `?camera=<scale>` URL-param debug hook for Sponsor-soak of T13/T16.
##   - Smooth lerp-follow (~0.1 s catch-up) instead of snap. Sponsor decision.
##
## ## References
##
##   - ClickUp `86c9wjyf3` — this ticket (T9)
##   - `team/devon-dev/camera2d-spike.md` — spike doc + design rationale
##   - `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T9 — AC
##   - `team/uma-ux/boss-intro.md` BI-05 + F2 — Wave 3 consumers
##   - `.claude/docs/html5-export.md` — gl_compatibility + visual-verification gate
##   - `.claude/docs/camera-layer.md` (to be created by maintain-docs when this lands)


# ---- Constants -------------------------------------------------------

## Viewport base zoom — matches `1280/480 = 2.6667` so a normalized 1.0×
## request produces pixel-perfect parity with the pre-T9 viewport-stretch
## rendering. Pinned to `project.godot [display]` window/size values; if
## those change this constant updates.
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


func _process(_delta: float) -> void:
	# Per-tick: resolve player target (cheap group lookup if cache is stale)
	# then write camera position. Snap-follow (no lerp) keeps T9 behavior
	# indistinguishable from pre-T9 native-stretch rendering.
	if _camera == null:
		return
	if _anchor_override != Vector2.ZERO:
		# Pinned anchor — _pos_tween (if any) drives position; otherwise hold.
		if _pos_tween == null or not _pos_tween.is_valid():
			_camera.global_position = _anchor_override
		return
	# Player-follow mode. Re-resolve if cached target is gone.
	if _target_player == null or not is_instance_valid(_target_player):
		_resolve_player_target()
	if _target_player != null and is_instance_valid(_target_player):
		_camera.global_position = _target_player.global_position


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

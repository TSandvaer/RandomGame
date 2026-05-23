class_name CameraScrollSpike
extends Node2D
## M3 Tier 3 W1 — Continuous-scroll camera spike (`86c9xu9yt`).
##
## **Hand-stitched 3-chunk test scene** that demonstrates the post-W1
## `CameraDirector.follow_target()` + `set_world_bounds()` API against a
## 3× canvas-width tilemap (1440×270 logical pixels — three 480×270 chunks
## side-by-side at x=0 / 480 / 960).
##
## ## What this scene proves
##
##   1. **Continuous follow-scroll** — WASD-walking the player marker across
##      the full 1440-pixel-wide scene scrolls the camera smoothly through
##      all three chunks without the camera lagging the player or jittering
##      at chunk seams.
##   2. **Bounds-clamp at world edges** — walking the marker past the left
##      edge (x < 0) or right edge (x > 1440) does NOT scroll the camera
##      past those edges; the camera halts at the bounds-edge while the
##      marker continues to move (visible space gap).
##   3. **Deadzone tolerance** — small marker motions inside the configured
##      deadzone half-extents do NOT shift the camera. Visible by the camera
##      holding while the marker shifts within a ~80×48-pixel window.
##   4. **Multi-chunk render under gl_compatibility** — three distinct floor
##      ColorRects render across chunk seams without visible gaps, z-index
##      sharp edges, or HUD flicker. This is the HTML5 visual-verification
##      surface (per `html5-export.md` § "Z-index sensitivity").
##
## ## Why a self-contained scene (vs. integrating with `Main.tscn`)
##
##   - The brief is **spike**, not feature-complete. Wiring continuous-scroll
##     into the full Main.tscn pipeline (room cycle, mob spawning, save state,
##     boss room, HUD) collides with W2's S1-retrofit ticket scope.
##   - The scene needs no Save/Inventory/MobRegistry hookup — only Camera +
##     a Node2D the camera can follow. Smaller blast radius.
##   - Test-isolation: `tests/test_camera_director.gd` adds spike-class GUT
##     pins for the new API; this scene is the HTML5-visual verification
##     surface. The two are orthogonal coverage.
##
## ## Marker (not Player)
##
## A minimal `CharacterBody2D` `PlayerMarker` (defined in the .tscn) responds
## to WASD inputs (mapped in `project.godot` for the production player) at
## `MARKER_SPEED = 180 px/s`. No combat, no animation, no inventory — just
## a 12×16 ColorRect that moves so the camera has something to follow. The
## production `Player.gd` carries enough side-baggage (Save hooks, hitbox,
## inventory bridge) that pulling it into a spike scene was a worse trade
## than a marker-only re-implementation.
##
## ## HUD overlay
##
## A CanvasLayer at `layer=10` (same layer as Main.gd's HUD) carries:
##   - **Build SHA + scene name** top-left (sanity check the right artifact loaded)
##   - **Live marker position** top-right (read by Sponsor / Tess for soak)
##   - **Live camera position** below that (visualizes deadzone hold + clamp)
##   - **Mode indicator** bottom-left (`follow_target ON / bounds=(...)`)
##
## The HUD is the same CanvasLayer pattern as `Main.gd::_build_hud()` — it
## should remain pixel-anchored throughout the entire scroll. **A drifting
## HUD value is the regression-tell** the Self-Test Report probes.
##
## ## Spawn + initial camera state
##
##   - Marker spawned at world (240, 135) — center of chunk 1.
##   - `follow_target(marker, deadzone=Vector2(40, 24))` engaged on `_ready`.
##   - `set_world_bounds(Rect2(0, 0, 1440, 270))` engaged on `_ready`.
##   - At BASELINE_ZOOM (2.6667), visible viewport is 480×270 world pixels —
##     the camera is centered on the marker's spawn, showing all of chunk 1.
##   - Walking the marker right past x=520 (chunk-1→chunk-2 seam) crosses
##     the deadzone edge and the camera follows; the chunk-2 floor color
##     becomes visible.
##   - Walking the marker further past x=1000 (chunk-2→chunk-3 seam) does
##     the same; chunk-3 floor appears.
##   - Walking past x=1200 (camera-clamp-edge for the right side) holds
##     the camera at x=1200 while the marker continues to x=1440.
##
## ## How to soak this manually
##
##   1. Run from editor: `scenes/spike/CameraScrollSpike.tscn` as main scene.
##   2. WASD to move marker; cursor for facing has no effect (no combat).
##   3. Walk a full left→right→left sweep; observe:
##      - Smooth camera follow without jitter at chunk seams.
##      - Camera clamp at left / right edges (visible space between marker
##        and screen edge once clamped).
##      - HUD remains screen-anchored (top-left build SHA never drifts).
##      - Chunk floor colors crisp at seams (no z-fight, no gap, no flicker).
##
## ## Cross-references
##
##   - `scripts/camera/CameraDirector.gd` — the API extension under test
##   - `tests/test_camera_director.gd` — paired GUT pins for math + lifecycle
##   - `tests/playwright/specs/camera-scroll-spike.spec.ts` — HTML5 spec
##   - `team/priya-pl/post-wave3-sequencing.md` §1 Commitment 1 — W1 brief
##   - `.claude/docs/html5-export.md` § "Z-index sensitivity" — risk surface

# ---- Tuning constants -------------------------------------------------

## Marker movement speed in world pixels/sec. ~50% faster than the production
## Player walk speed (120) so a sponsor soak can sweep the full 1440-pixel
## world in ~8 seconds (vs ~12 at production walk speed).
const MARKER_SPEED: float = 180.0

## Sprint multiplier (Shift). Lets the soaker traverse faster for repeat
## sweeps. ~360 px/s — same scale as the production Player sprint.
const MARKER_SPRINT_MULT: float = 2.0

## Marker spawn — center of chunk 1 (chunks are 480px each, world 0..1440).
## (240, 135) is the X-center of chunk 1 + Y-center of the 270px tall world.
const MARKER_SPAWN: Vector2 = Vector2(240.0, 135.0)

## Deadzone half-extents. 40×24 world pixels = an 80×48 freely-moveable
## rectangle around the camera center. Walking the marker a few pixels
## inside this window holds the camera; crossing the edge re-engages
## the catch-up motion.
const DEADZONE: Vector2 = Vector2(40.0, 24.0)

## World bounds — origin at (0, 0), 3 chunks wide × 1 chunk tall.
## 1440 × 270 world pixels. The bounds-clamp keeps the camera from
## scrolling past the authored content.
const WORLD_BOUNDS: Rect2 = Rect2(0.0, 0.0, 1440.0, 270.0)

# ---- Node refs --------------------------------------------------------

@onready var _marker: CharacterBody2D = $PlayerMarker
@onready var _hud_marker_pos_label: Label = $HUD/MarkerPosLabel
@onready var _hud_camera_pos_label: Label = $HUD/CameraPosLabel
@onready var _hud_mode_label: Label = $HUD/ModeLabel
@onready var _hud_build_label: Label = $HUD/BuildLabel

# ---- Lifecycle --------------------------------------------------------


func _ready() -> void:
	# Reachability check — abort cleanly if CameraDirector missing.
	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd == null:
		push_warning("[CameraScrollSpike] CameraDirector autoload missing — spike inactive")
		return

	# Engage continuous-scroll follow + world-bounds clamp.
	if cd.has_method("follow_target"):
		cd.follow_target(_marker, DEADZONE)
	if cd.has_method("set_world_bounds"):
		cd.set_world_bounds(WORLD_BOUNDS)

	# HUD: build SHA + scene name (sanity check the right artifact loaded).
	var bi: Node = get_tree().root.get_node_or_null("BuildInfo")
	var sha: String = ""
	if bi != null and "short_sha" in bi:
		sha = String(bi.short_sha)
	if _hud_build_label != null:
		_hud_build_label.text = "[CameraScrollSpike] build=%s" % (sha if sha != "" else "dev")

	# Static mode label — reflects the engaged configuration.
	if _hud_mode_label != null:
		_hud_mode_label.text = (
			"follow_target ON | deadzone=(%.0f,%.0f) | bounds=(0,0,%.0f,%.0f)"
			% [DEADZONE.x, DEADZONE.y, WORLD_BOUNDS.size.x, WORLD_BOUNDS.size.y]
		)

	print(
		(
			"[CameraScrollSpike] ready spawn=(%.0f,%.0f) deadzone=(%.0f,%.0f) bounds=(0,0,%.0f,%.0f)"
			% [
				MARKER_SPAWN.x,
				MARKER_SPAWN.y,
				DEADZONE.x,
				DEADZONE.y,
				WORLD_BOUNDS.size.x,
				WORLD_BOUNDS.size.y
			]
		)
	)


func _exit_tree() -> void:
	# Tear down our follow + bounds when the scene unloads so other tests
	# that share this autoload start from a clean baseline.
	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd == null:
		return
	if cd.has_method("clear_follow_target"):
		cd.clear_follow_target()
	if cd.has_method("clear_world_bounds"):
		cd.clear_world_bounds()


func _physics_process(_delta: float) -> void:
	# Read WASD input → set marker velocity. CharacterBody2D.move_and_slide
	# handles the rest (no walls in this scene, but the world-bounds clamp
	# is camera-side — the marker is free to walk past the bounds, at which
	# point the camera halts but the marker stays visible at screen-edge).
	if _marker == null:
		return
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	var speed: float = MARKER_SPEED
	if Input.is_action_pressed("sprint"):
		speed *= MARKER_SPRINT_MULT
	_marker.velocity = input_dir.normalized() * speed
	_marker.move_and_slide()


func _process(_delta: float) -> void:
	# Live HUD labels — marker + camera positions for visual verification
	# of follow + clamp behavior during soak.
	if _marker != null and _hud_marker_pos_label != null:
		_hud_marker_pos_label.text = (
			"marker=(%.0f, %.0f)" % [_marker.global_position.x, _marker.global_position.y]
		)
	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd != null and cd.has_method("get_camera") and _hud_camera_pos_label != null:
		var cam: Camera2D = cd.get_camera()
		if cam != null:
			_hud_camera_pos_label.text = (
				"camera=(%.0f, %.0f)" % [cam.global_position.x, cam.global_position.y]
			)

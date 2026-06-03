# gdlint:disable=max-public-methods
extends GutTest
## S1 bigger-rooms retrofit Stage 1 (ticket 86ca3kpzz — S0 + S1A).
##
## Covers the engine-side invariants the HTML5 visual gate cannot assert
## headlessly (the actual wide-screen fill + scroll is the Sponsor-soak gate
## of record; these pin the mechanics underneath):
##
##   S0 — aspect=expand + HUD re-anchor:
##     - project.godot ships `window/stretch/aspect="expand"` (kills the
##       16:9 pillarbox so a wide window claims more logical width).
##     - The CameraDirector size_changed → zoom re-assert connection survives
##       (the canvas-resize owned-state clobber guard, html5-export.md §
##       "Canvas resize / minimize-restore"). `expand` re-runs the stretch
##       pass on every window resize, so this guard is load-bearing under it.
##     - Every HUD control uses an ANCHOR PRESET (proportional anchors), NOT
##       absolute pixel layout — so under `expand` (which changes the logical
##       viewport width) the HUD re-resolves to the live width automatically:
##       top-left stays top-left, top-right (negative offsets) stays pinned to
##       the right edge, center-top stays centred, bottom-wide spans full
##       width. A regression that hard-coded a width (e.g. positioned the
##       STRATUM context at x=980) would drift off-screen under expand.
##
##   S1A — widened proof chunk:
##     - The widened chunk def (s1_room02_wide.tres) is 30×8 = 960×256, wider
##       than the 480-wide viewport on X (so the camera-scroll branch engages).
##     - The widened chunk scene paints its full 30×8 grid with zero
##       WarningBus emissions.
##     - The grid-size export on S1CloisterChunk defaults to 15×8 (existing
##       rooms unchanged) and the wide scene overrides grid_w=30.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const PROJECT_GODOT_PATH: String = "res://project.godot"
const CAMERA_DIRECTOR_SOURCE: String = "res://scripts/camera/CameraDirector.gd"
const WIDE_CHUNK_DEF_PATH: String = "res://resources/level_chunks/s1_room02_wide.tres"
const WIDE_CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_room02_wide_chunk.tscn"
const NARROW_CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_room01_chunk.tscn"
const MAIN_SCENE := preload("res://scenes/Main.tscn")

# Viewport-world width at BASELINE_ZOOM (1280 / 2.6667). The scroll branch in
# CameraDirector._clamp_to_world_bounds engages when bounds.size.x exceeds it.
const VIEWPORT_WORLD_X: float = 480.0

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.detach()
	_warn_guard = null


# ---- S0: aspect=expand ------------------------------------------------


func test_project_godot_uses_aspect_expand() -> void:
	# The whole S0 fix is this one line — `keep` pillarboxes a wide monitor to
	# 16:9 black bars; `expand` claims the wide pixels (more logical width).
	var text: String = FileAccess.get_file_as_string(PROJECT_GODOT_PATH)
	assert_gt(text.length(), 0, "project.godot readable")
	assert_true(
		text.find('window/stretch/aspect="expand"') > -1,
		"project.godot ships aspect=expand (S0 — kills the 16:9 pillarbox on wide monitors)"
	)
	assert_eq(
		text.find('window/stretch/aspect="keep"'),
		-1,
		"the old aspect=keep is gone (it would re-introduce the black side-bars)"
	)


func test_camera_director_size_changed_reassert_connection_present() -> void:
	# Under `expand`, a window resize re-runs the canvas_items stretch pass,
	# which clobbers the engine Camera2D.zoom back to default while the
	# director's GDScript mirror keeps the old value. The size_changed →
	# _on_window_size_changed → _reassert_owned_camera_state guard re-projects
	# the mirror onto the engine state. If this connection is dropped, the
	# Sponsor's dialed `?cam_zoom` silently reverts on every minimize/restore.
	# (Source-scan pin — the live HTML5 trigger is browser-only; this guards
	# the wiring that test_camera_director.gd's behavioural pins exercise.)
	var src: String = FileAccess.get_file_as_string(CAMERA_DIRECTOR_SOURCE)
	assert_gt(src.length(), 0, "CameraDirector.gd readable")
	assert_true(
		src.find("size_changed.connect(_on_window_size_changed)") > -1,
		"CameraDirector subscribes viewport size_changed (resize zoom re-assert holds under expand)"
	)
	assert_true(
		src.find("func _reassert_owned_camera_state") > -1,
		"CameraDirector defines _reassert_owned_camera_state (re-projects owned zoom on resize)"
	)


func test_all_hud_controls_use_anchor_presets_not_absolute_layout() -> void:
	# **The S0 HUD-re-anchor regression gate.** Under `expand` the logical
	# viewport WIDTH grows on a wide window; HUD Controls anchored with PROPER
	# PRESETS (proportional 0..1 anchors) re-resolve to the live width every
	# layout pass, so they stay correctly placed. A Control positioned by an
	# absolute pixel (e.g. anchored TOP_LEFT but pushed to x=980 to fake a
	# right-edge placement) would drift off-screen when the width changes.
	#
	# We assert every named HUD widget has a NON-degenerate anchor preset
	# matching its intended corner/edge. anchor_left/right/top/bottom are the
	# proportional anchors set by set_anchors_preset; checking they are the
	# expected 0/1 values proves the widget tracks the live viewport rather
	# than a baked width.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: CanvasLayer = main.get_node_or_null("HUD")
	assert_not_null(hud, "Main builds the HUD CanvasLayer")

	# Top-left vitals (LV / health / XP) — anchored TOP_LEFT (all anchors 0).
	var vitals: Control = hud.get_node_or_null("TopLeftVitals")
	assert_not_null(vitals, "HUD has TopLeftVitals")
	assert_eq(vitals.anchor_left, 0.0, "vitals left anchor = 0 (tracks left edge)")
	assert_eq(vitals.anchor_right, 0.0, "vitals right anchor = 0 (TOP_LEFT preset)")

	# Top-right run context (STRATUM x/8) — anchored TOP_RIGHT (anchors at 1
	# on X). Under expand, anchor=1 keeps it pinned to the live right edge.
	var ctx: Control = hud.get_node_or_null("TopRightContext")
	assert_not_null(ctx, "HUD has TopRightContext (STRATUM label)")
	assert_eq(ctx.anchor_left, 1.0, "context left anchor = 1 (tracks right edge under expand)")
	assert_eq(ctx.anchor_right, 1.0, "context right anchor = 1 (TOP_RIGHT preset)")

	# Top-center camera-zoom readout — anchored CENTER_TOP (anchors at 0.5 on
	# X). Under expand, anchor=0.5 keeps it centred over the live width.
	var cam: Control = hud.get_node_or_null("CamZoomReadout")
	assert_not_null(cam, "HUD has CamZoomReadout (CAM-ZOOM top-center)")
	assert_eq(cam.anchor_left, 0.5, "cam-zoom left anchor = 0.5 (stays centred under expand)")
	assert_eq(cam.anchor_right, 0.5, "cam-zoom right anchor = 0.5 (CENTER_TOP preset)")

	# Bottom-wide onboarding banner — anchored BOTTOM_WIDE (left=0, right=1)
	# so it spans the full live width and stays centred under expand.
	var banner: Control = hud.get_node_or_null("BootBanner")
	assert_not_null(banner, "HUD has BootBanner (onboarding controls text)")
	assert_eq(banner.anchor_left, 0.0, "banner left anchor = 0 (spans from left edge)")
	assert_eq(banner.anchor_right, 1.0, "banner right anchor = 1 (BOTTOM_WIDE spans full width)")


# ---- S1A: widened proof chunk ----------------------------------------


func test_wide_chunk_def_is_scroll_width() -> void:
	# The widened proof chunk must be WIDER than the viewport on X so the
	# camera-scroll branch engages (camera-scroll.md § "Bounds-clamp math").
	# Height stays single-screen (vertical scroll is OOS for S1A).
	var c: LevelChunkDef = load(WIDE_CHUNK_DEF_PATH) as LevelChunkDef
	assert_not_null(c, "wide chunk def loads")
	var errors: Array[String] = c.validate()
	assert_eq(errors.size(), 0, "wide chunk def validates: %s" % str(errors))
	assert_eq(c.size_tiles, Vector2i(30, 8), "wide chunk is 30×8 tiles")
	var size_px: Vector2i = c.size_px()
	assert_eq(size_px.x, 960, "wide chunk is 960 px wide")
	assert_gt(
		float(size_px.x),
		VIEWPORT_WORLD_X,
		"wide chunk width exceeds the 480-px viewport (camera SCROLLS, not centres)"
	)
	assert_eq(
		c.id, &"s1_room02", "wide chunk keeps id s1_room02 (StratumProgression/save unchanged)"
	)
	# Mob roster grew with the floor (light balance pass).
	assert_eq(
		c.mob_spawns.size(), 4, "wide chunk carries 4 grunts (balance pass for the bigger floor)"
	)
	# Every spawn + port stays inside the 30×8 grid (validate() already checks
	# this, but pin it explicitly so a future coord edit fails loud).
	for ms: MobSpawnPoint in c.mob_spawns:
		assert_true(
			c.contains_tile(ms.position_tiles), "spawn %s inside wide grid" % str(ms.position_tiles)
		)


func test_wide_chunk_scene_paints_full_grid_without_warnings() -> void:
	# The widened chunk scene reuses the S1CloisterChunk painter with
	# grid_w=30. After _ready it must paint a 30×8 TileMapLayer with zero
	# WarningBus emissions (the painter push_warnings only if FloorTiles is
	# missing — a regression tell).
	var packed: PackedScene = load(WIDE_CHUNK_SCENE_PATH)
	assert_not_null(packed, "wide chunk scene loads")
	var inst: Node = packed.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var floor_tiles: TileMapLayer = inst.get_node_or_null("FloorTiles")
	assert_not_null(floor_tiles, "wide chunk has a FloorTiles TileMapLayer")
	# 30×8 = 240 painted cells; the used rect must span the full 30 columns.
	var used: Rect2i = floor_tiles.get_used_rect()
	assert_eq(used.size.x, 30, "painted floor spans the full 30 tile columns")
	assert_eq(used.size.y, 8, "painted floor spans the full 8 tile rows")
	_warn_guard.assert_clean(self)


func test_wide_chunk_painter_grid_export_overrides_default() -> void:
	# The grid_w export defaults to 15 (existing rooms unchanged) and the wide
	# scene sets 30. Confirm the wide instance reports grid_w=30 + the narrow
	# scene keeps the 15 default — proves the parameterisation is data-driven,
	# not a forked script.
	var wide: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(wide)
	assert_eq(wide.grid_w, 30, "wide chunk overrides grid_w=30")
	var narrow: Node = (load(NARROW_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(narrow)
	assert_eq(
		narrow.grid_w, 15, "narrow chunk keeps the default grid_w=15 (existing rooms unchanged)"
	)

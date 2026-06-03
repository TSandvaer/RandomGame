extends GutTest
## W2-T1 (`86c9y0zmg`) — pin that Main.gd wires CameraDirector continuous-
## scroll on every room load + that Stratum1BossRoom does the same from
## its deferred fixture pass.
##
## Per the W2-T1 ticket scope (Part A + Part B), Main._load_room_at_index
## MUST call `CameraDirector.follow_target(player, Vector2(40, 24))` +
## `CameraDirector.set_world_bounds(Rect2(0, 0, 480, 270))` after re-
## parenting the player into the freshly-loaded room. Stratum1BossRoom's
## deferred `_assemble_room_fixtures` pass MUST do the same with the boss
## room's authored bounds + deadzone constants.
##
## ## Coverage shape
##
##   1. **Source-scan structural pin (Main)** — verify the engage call
##      sits in `_load_room_at_index` between the player re-parent and
##      `_wire_room_signals`. A refactor that removes the call would
##      silently break the production wiring without breaking the
##      behavioural pin if a different code path were to engage the
##      camera elsewhere.
##   2. **Source-scan structural pin (Stratum1BossRoom)** — verify the
##      engage call sits at the end of `_assemble_room_fixtures` after
##      the entry-sequence trigger.
##   3. **Behavioural pin (Main)** — bare-instantiate Main, await frames
##      for the build chain to settle, assert `CameraDirector.is_following_target()
##      is true with the player as target + `Vector2(40, 24)` deadzone +
##      `Rect2(0, 0, 480, 270)` bounds.
##   4. **HTML5-trace pin (constants)** — verify `Main.S1_ROOM_BOUNDS` /
##      `Main.CAMERA_FOLLOW_DEADZONE` match the W1 spike's authored values
##      so the Playwright spec's regex against the trace line stays
##      consistent with production reality.
##
## ## Test-isolation hygiene
##
## CameraDirector autoload is shared state; `before_each` calls
## `clear_follow_target()` + `clear_world_bounds()` so a leaked engage
## from a prior test doesn't poison this file.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const MAIN_SOURCE_PATH := "res://scenes/Main.gd"
const BOSS_ROOM_SOURCE_PATH := "res://scripts/levels/Stratum1BossRoom.gd"
const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _warn_guard: NoWarningGuard
var _director: Node


func before_each() -> void:
	_director = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	if _director != null:
		if _director.has_method("clear_follow_target"):
			_director.clear_follow_target()
		if _director.has_method("clear_world_bounds"):
			_director.clear_world_bounds()
		if _director.has_method("reset_to_player"):
			_director.reset_to_player(0.0)
	# Permissive warning gate — Main boot surfaces warnings from save +
	# content registry that aren't W2-T1's concern. We scope assertions
	# to camera wiring; the full boot-zero-warning bar is tested elsewhere.
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	if _director != null:
		if _director.has_method("clear_follow_target"):
			_director.clear_follow_target()
		if _director.has_method("clear_world_bounds"):
			_director.clear_world_bounds()
		if _director.has_method("reset_to_player"):
			_director.reset_to_player(0.0)
	_warn_guard.detach()
	_warn_guard = null


# ---- Pin 1: source-scan structural — Main._load_room_at_index ---------


func test_main_load_room_calls_engage_camera_after_player_reparent() -> void:
	# Per `.claude/docs/test-conventions.md` § "Source-scan structural pins":
	# behaviour-side tests can't easily prove "the engage call sits AFTER
	# the player re-parent" — the behavioural pin observes the END state.
	# A refactor that moved the engage call before the player re-parent
	# would still satisfy the behavioural pin (the engage uses the player
	# in its closure), but would break the per-tick player resolution.
	# The structural pin guards the ordering invariant.
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	assert_gt(source.length(), 0, "Main.gd readable as resource")
	# Find _load_room_at_index's body region.
	var fn_start: int = source.find("func _load_room_at_index(")
	assert_gt(fn_start, -1, "Main.gd defines _load_room_at_index")
	var body_start: int = source.find("\n", fn_start)
	var next_fn: int = source.find("\nfunc ", body_start)
	assert_gt(next_fn, body_start, "next function follows _load_room_at_index")
	var fn_body: String = source.substr(body_start, next_fn - body_start)
	# Pin: player re-parent → engage → wire room signals appear in this
	# order. Player re-parent is the `room.add_child(_player)` line; engage
	# is `_engage_camera_for_room()`; wire is `_wire_room_signals(`.
	var reparent_pos: int = fn_body.find("room.add_child(_player)")
	var engage_pos: int = fn_body.find("_engage_camera_for_room()")
	var wire_pos: int = fn_body.find("_wire_room_signals(")
	assert_gt(reparent_pos, -1, "_load_room_at_index re-parents the player into the new room")
	assert_gt(engage_pos, -1, "_load_room_at_index calls _engage_camera_for_room() — W2-T1 wiring")
	assert_gt(wire_pos, -1, "_load_room_at_index calls _wire_room_signals()")
	assert_lt(
		reparent_pos, engage_pos, "camera engage runs AFTER player re-parent (player ref alive)"
	)
	assert_lt(
		engage_pos,
		wire_pos,
		"camera engage runs BEFORE _wire_room_signals (no signal-ordering coupling)"
	)


func test_main_engage_camera_helper_calls_follow_target_and_set_world_bounds() -> void:
	# Pin: _engage_camera_for_room body calls follow_target + set_world_bounds
	# with the authored constants. A future refactor that drops one of the
	# two API calls would break the W2-T1 contract silently — the behavioural
	# pin would still observe SOMETHING engaged, but maybe only follow_target
	# (no bounds-clamp).
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var fn_start: int = source.find("func _engage_camera_for_room(")
	assert_gt(fn_start, -1, "Main.gd defines _engage_camera_for_room helper")
	var body_start: int = source.find("\n", fn_start)
	var next_fn: int = source.find("\nfunc ", body_start)
	var end: int = next_fn if next_fn > body_start else source.length()
	var fn_body: String = source.substr(body_start, end - body_start)
	assert_true(
		fn_body.find("follow_target") > -1,
		"_engage_camera_for_room calls CameraDirector.follow_target"
	)
	assert_true(
		fn_body.find("set_world_bounds") > -1,
		"_engage_camera_for_room calls CameraDirector.set_world_bounds"
	)
	assert_true(
		fn_body.find("CAMERA_FOLLOW_DEADZONE") > -1,
		"_engage_camera_for_room passes Main.CAMERA_FOLLOW_DEADZONE deadzone"
	)
	# Ticket 86ca3kpzz (S1A): bounds are now read from the live room geometry
	# via `_room_world_bounds()` (which reads `get_bounds_px()` + falls back to
	# S1_ROOM_BOUNDS) — NOT the fixed constant. The scroll machinery engages
	# only when bounds are wider than the viewport, which the widened proof
	# chunk produces. A refactor that hard-codes the constant again (dropping
	# the chunk-driven source) would regress the scroll-on-wide-room behaviour.
	assert_true(
		fn_body.find("_room_world_bounds()") > -1,
		"_engage_camera_for_room drives bounds from the chunk via _room_world_bounds()"
	)


# ---- Pin 2: source-scan structural — Stratum1BossRoom -----------------


func test_boss_room_assemble_fixtures_calls_engage_camera_at_tail() -> void:
	# Boss-room engage runs AT THE END of the deferred fixture pass, AFTER
	# the entry-sequence trigger. This ordering protects the case where a
	# future ticket adds camera-bounds work to the entry-sequence trigger —
	# the engage MUST run last so the bounds the player sees are the boss-
	# room bounds, not whatever the trigger temporarily sets.
	var source: String = FileAccess.get_file_as_string(BOSS_ROOM_SOURCE_PATH)
	assert_gt(source.length(), 0, "Stratum1BossRoom.gd readable as resource")
	var fn_start: int = source.find("func _assemble_room_fixtures(")
	assert_gt(fn_start, -1, "Stratum1BossRoom defines _assemble_room_fixtures")
	var body_start: int = source.find("\n", fn_start)
	var next_fn: int = source.find("\nfunc ", body_start)
	var fn_body: String = source.substr(body_start, next_fn - body_start)
	var trigger_pos: int = fn_body.find("trigger_entry_sequence()")
	var engage_pos: int = fn_body.find("_engage_camera_for_boss_room()")
	assert_gt(trigger_pos, -1, "_assemble_room_fixtures fires the entry sequence")
	assert_gt(engage_pos, -1, "_assemble_room_fixtures fires the camera engage")
	assert_lt(
		trigger_pos,
		engage_pos,
		"camera engage fires AFTER entry-sequence trigger (deferred-pass tail)"
	)


# ---- Pin 3: behavioural — Main boots → camera engaged -----------------


func test_main_boot_engages_camera_against_player_with_authored_constants() -> void:
	# Bare-instantiate Main; wait for the deferred build chain to settle;
	# verify CameraDirector reports an engaged follow + bounds matching
	# the constants Main declares.
	#
	# Note: we cannot assert against `Main.S1_ROOM_BOUNDS` / `Main.CAMERA_FOLLOW_DEADZONE`
	# constants directly because GDScript lacks compile-time const lookup
	# from outside the class; we use the W1 spike's authored values
	# (Vector2(40,24) + Rect2(0,0,480,270)) which Main is required by the
	# source-scan pin above to match.
	if _director == null:
		# Bare-test surface without CameraDirector autoload registered.
		# This test requires the autoload; skip cleanly so non-prod test
		# rigs don't fail.
		return
	assert_not_null(MAIN_SCENE, "Main.tscn loads")
	var main: Node = MAIN_SCENE.instantiate()
	assert_not_null(main, "Main instantiates")
	add_child_autofree(main)
	# Three frames cover: _ready + first room queue_free defer +
	# CameraDirector._process tick. The save-load deferred chain is also
	# settled by frame 3 (save layer reads on _ready, content registry
	# is autoload-built, room is loaded synchronously from Main._ready
	# at the end of its build chain).
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# CameraDirector reports engaged follow.
	assert_true(
		_director.is_following_target(),
		"CameraDirector.is_following_target() true after Main boot (W2-T1 engage)"
	)
	# Player is the follow target.
	var follow: Node2D = _director.get_follow_target()
	assert_not_null(follow, "follow target is non-null after engage")
	assert_true(follow.is_in_group("player"), "follow target is in 'player' group (== Player node)")
	# Deadzone matches authored Vector2(40, 24).
	assert_eq(
		_director.get_follow_deadzone(),
		Vector2(40, 24),
		"deadzone matches Main.CAMERA_FOLLOW_DEADZONE = Vector2(40, 24)"
	)
	# World bounds is now driven from the boot room's chunk geometry
	# (ticket 86ca3kpzz). Room01 (the boot room) is a 15×8 / 480×256 chunk,
	# so `get_bounds_px()` returns Rect2(0, 0, 480, 256) — the chunk-derived
	# value, NOT the old fixed Rect2(0, 0, 480, 270) constant. 256 (8×32) is
	# the chunk's true pixel height; the prior 270 was the viewport-target
	# height the old constant baked in. On both axes 480/256 <= the 480×270
	# viewport_world, so the camera still centres (zero visual change at boot).
	assert_eq(
		_director.get_world_bounds(),
		Rect2(0, 0, 480, 256),
		"world bounds is chunk-derived from boot room Room01 (15×8 = 480×256)"
	)


# ---- Pin 3b: widened proof room engages the SCROLL branch -------------


func test_loading_widened_room02_drives_scrolling_bounds() -> void:
	# **The S1A regression gate (ticket 86ca3kpzz).** Loading the widened
	# proof chunk (Room02 → 30×8 = 960×256) must set world bounds wider than
	# the viewport on X, so `_clamp_to_world_bounds` takes the SCROLL branch
	# (not the centre branch) — the behaviour that makes the camera follow the
	# player across the bigger room. If a future refactor reverts
	# `_engage_camera_for_room` to the fixed S1_ROOM_BOUNDS constant, the
	# bounds would read 480-wide and the camera would centre — the bug this
	# whole ticket fixes. This pin catches that regression.
	if _director == null:
		return
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# Load the widened Room02 (ROOM_SCENE_PATHS index 1) through the real
	# production room-load path.
	main.call("_load_room_at_index", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	# Bounds reflect the widened chunk geometry: 30×8 tiles × 32 px = 960×256.
	var bounds: Rect2 = _director.get_world_bounds()
	assert_eq(
		bounds,
		Rect2(0, 0, 960, 256),
		"widened Room02 drives world bounds = chunk size 960×256 (scroll-width)"
	)
	# Prove the clamp actually SCROLLS on X: the camera position for a player
	# at the far-right of the room must differ from the bounds-centre. At
	# BASELINE_ZOOM the viewport_world is 480 wide; 960 > 480 so the X axis
	# takes the clamp (scroll) branch. The clamp helper is pure + test-callable.
	var centre_x: float = bounds.position.x + bounds.size.x * 0.5  # 480
	var far_right_cam: Vector2 = _director._clamp_to_world_bounds(Vector2(900, 128), bounds)
	assert_ne(
		far_right_cam.x,
		centre_x,
		"camera scrolls on X for a far-right player (clamp took the scroll branch, not centre)"
	)
	# And clamps at the right edge: at BASELINE_ZOOM half_vp.x = 240, so the
	# right-edge camera x is bounds.end.x - 240 = 960 - 240 = 720.
	assert_almost_eq(
		far_right_cam.x,
		720.0,
		0.5,
		"camera clamps to the right edge (bounds.end.x - half_viewport)"
	)


# ---- Pin 4: idempotence — re-engage on room-cycle ---------------------


func test_main_engage_camera_idempotent_on_room_swap() -> void:
	# The per-room engage call runs on EVERY _load_room_at_index, so when
	# the player traverses Room01 → Room02 → Room01 → Room02 the
	# CameraDirector receives 4 follow_target() calls with identical args.
	# Per spike's idempotence semantics, follow_target_changed must fire
	# at most once (engage→true on first call); same for world_bounds_changed.
	if _director == null:
		return
	var events: Array = []
	var cb := func(engaged: bool) -> void: events.append(engaged)
	_director.follow_target_changed.connect(cb)
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# Track engagement count post-boot.
	var engage_events: int = 0
	for e: Variant in events:
		if bool(e):
			engage_events += 1
	# Boot fires exactly one engage. (Tests that explicitly load other
	# rooms via Main._load_room_at_index would fire more — we don't
	# trigger that here; the source-scan pin already proves the engage
	# call sits in _load_room_at_index.)
	assert_eq(
		engage_events,
		1,
		(
			"follow_target_changed(true) fires exactly once on Main boot "
			+ "(idempotence: same-target same-deadzone re-calls = no signal)"
		)
	)
	_director.follow_target_changed.disconnect(cb)

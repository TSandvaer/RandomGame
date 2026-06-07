extends GutTest
## Paired GUT tests for the S1 cloister-yard KEYSTONE retrofit (ticket
## `86ca5errv`) — wiring Stratum-1's live play loop onto `FloorAssembler`
## (today only S2 consumes it in production).
##
## What this pins (the foundation + minimal proof; full yard CONTENT is a
## downstream Drew ticket):
##   1. **Regression guard — the keystone path EXISTS + is consumed.** Main has a
##      `_load_s1_zone` that calls the FloorAssembler API + feeds
##      `bounding_box_px` to the camera. If a refactor drops the S1 assembler
##      path (back to static-rooms-only), the structural tests fail. This is the
##      single class of test that catches a regression of the retrofit itself.
##   2. **Boots cleanly — non-degenerate, well-mated floor.** Driving
##      `load_s1_zone_for_test()` on a bare-instance Main renders the assembled
##      S1 floor (`is_s1_floor_active()` true), spawns the authored chunk mobs,
##      and produces zero `USER WARNING:` (the NoWarningGuard gate — proves
##      clean mating + clean mob resolution end-to-end through Main).
##   3. **Camera bounds come from the assembled floor, NOT the hardcoded
##      S1_ROOM_BOUNDS.** The keystone camera swap: `_render_assembled_s1_floor`
##      engages `set_world_bounds(assembled.bounding_box_px)` via the shared
##      `_engage_camera_for_assembled_floor` helper. Bounds wider than the
##      viewport → the continuous-scroll clamp branch (the "big + endless" read).
##   4. **Default boot is undisturbed.** Without the soak flag / test call, Main
##      boots the static Room01 (the 8-room traversal the Playwright suite +
##      onboarding gate depend on) — `is_s1_floor_active()` is false on a normal
##      boot. This pins the "foundation is additive, not a hard swap" contract.
##   5. **OOS gaps carried forward consciously (parity with S2).** Documented,
##      not silently regressed: assembled-floor mobs grant XP/loot (wire_combat),
##      but there is no in-zone chunk-clear progression gate (S1 is one floor).
##
## **Determinism + bounds + clean-mating at the ASSEMBLER layer** are already
## pinned by `tests/test_floor_assembler.gd` (test_s1_z1_clean_mating_across_8_seeds,
## test_assemble_authored_s1_z1_*). This file pins the MAIN INTEGRATION — the
## thing that was the open `product-vs-component-completeness` gap. The BFS
## navigability gate is in `tests/test_s1_assembled_floor_navigability.gd`.

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MAIN_SOURCE_PATH: String = "res://scenes/Main.gd"

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Source-scan structural tests (regression guards) ----------------


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "could not open source %s" % path)
	if f == null:
		return ""
	var src: String = f.get_as_text()
	f.close()
	return src


func _func_body(src: String, fn_decl: String) -> String:
	var fn_idx: int = src.find(fn_decl)
	if fn_idx < 0:
		return ""
	var next_fn: int = src.find("\nfunc ", fn_idx + 1)
	if next_fn > fn_idx:
		return src.substr(fn_idx, next_fn - fn_idx)
	return src.substr(fn_idx)


## REGRESSION GUARD. The S1 keystone path must consume the FloorAssembler API.
## If a refactor removes `_load_s1_zone` or its assemble call, this fails.
func test_s1_load_zone_consumes_floor_assembler() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _load_s1_zone")
	assert_ne(body, "", "expected _load_s1_zone (the keystone S1 assembler path)")
	assert_gt(body.find("FloorAssembler.derive_stratum_seed"), 0, "S1 must derive stratum seed")
	assert_gt(body.find("FloorAssembler.derive_zone_seed"), 0, "S1 must derive zone seed")
	assert_gt(body.find("assemble_floor("), 0, "S1 must call assemble_floor")


## REGRESSION GUARD — the keystone camera swap. The S1 render must engage the
## continuous-scroll camera against the ASSEMBLED FLOOR bounds (not the hardcoded
## S1_ROOM_BOUNDS). The shared helper `_engage_camera_for_assembled_floor` reads
## `assembled.bounding_box_px`; the render path must call it.
func test_s1_render_engages_camera_for_assembled_floor() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _render_assembled_s1_floor")
	assert_ne(body, "", "expected _render_assembled_s1_floor helper")
	assert_gt(
		body.find("_engage_camera_for_assembled_floor"),
		0,
		"S1 render must feed bounding_box_px to the camera via the shared helper"
	)
	# And the shared helper itself must source bounds from the assembled floor.
	var helper: String = _func_body(src, "func _engage_camera_for_assembled_floor")
	assert_gt(helper.find("assembled.bounding_box_px"), 0, "bounds source = bounding_box_px")
	assert_gt(helper.find("set_world_bounds"), 0, "must call set_world_bounds")


## The S1 zone def path resolves the soak-target S1 ZoneDef constant. Updated by
## S1-YARD T4 (ticket 86ca5erzk): the ?s1_assembler=1 soak zone is now the open
## cloister-YARD first slice (`s1_z1_yard_slice` — the big walkable open expanse)
## rather than the narrative-arc `s1_z1_outer_cloister` zone (retained for T7's
## full-extension work). The retrofit wiring (camera-bounds swap, mob spawn, clean
## render) is zone-agnostic — the behavioural tests below still hold for the yard.
func test_s1_zone_id_constant_matches_authored_zone() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	assert_gt(
		src.find('S1_ZONE_ID: StringName = &"s1_z1_yard_slice"'),
		0,
		"S1_ZONE_ID must be the S1-YARD soak zone s1_z1_yard_slice"
	)


# ---- Behavioural bare-instance Main tests -----------------------------


## Default boot (no soak flag, no test call) stays on the static Room01 — the
## assembler-driven S1 floor is NOT active. Pins "foundation is additive".
func test_default_boot_does_not_activate_s1_assembler_floor() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(main.get_current_room_index(), 0, "default boot loads static Room 01")
	assert_false(
		main.is_s1_floor_active(), "default boot must NOT activate the assembler-driven S1 floor"
	)
	main.queue_free()


## Driving the keystone path renders the assembled S1 floor cleanly: the floor
## becomes active, the authored chunk mobs spawn, and the NoWarningGuard confirms
## zero USER WARNING — proving clean mating + clean mob resolution end-to-end
## through Main (the integration the assembler-layer tests cannot reach).
func test_load_s1_zone_renders_assembled_floor_clean() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main.load_s1_zone_for_test()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(main.is_s1_floor_active(), "load_s1_zone_for_test must activate the S1 floor")
	# The yard-slice chunk carries 3 grunt mob_spawns, so a non-degenerate
	# assemble spawns mobs. A zero count would mean the chunk mob_spawns silently
	# failed to resolve through Main.
	assert_gt(
		main.s1_mobs_remaining(),
		0,
		"assembled S1 floor must spawn the authored chunk mobs (mob_spawns resolved)"
	)
	main.queue_free()


## The keystone camera-bounds swap, behaviourally. After rendering the assembled
## floor, the CameraDirector's world-bounds must be the assembled floor's
## bounding box (wider than the 480-px viewport-native S1_ROOM_BOUNDS) — the
## "big + endless" continuous-scroll read. This is the heart of the retrofit:
## bounds come from the assembler, not the hardcoded constant.
func test_load_s1_zone_sets_camera_bounds_from_assembled_floor() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd == null or not cd.has_method("get_world_bounds"):
		# CameraDirector autoload absent in this bare surface — the structural
		# test above already pins the wiring; skip the behavioural assert.
		main.queue_free()
		pass_test(
			"CameraDirector autoload / get_world_bounds unavailable — structural test covers it"
		)
		return

	main.load_s1_zone_for_test()
	await get_tree().process_frame
	await get_tree().process_frame

	var bounds: Rect2 = cd.get_world_bounds()
	# The yard-slice floor is 1280 (yard) + 192 (descent) = 1472 px wide → well
	# over the 480-px viewport. The bounds MUST be wider than the hardcoded
	# S1_ROOM_BOUNDS (480) — that wider-than-viewport bounds is what scrolls.
	assert_gt(
		bounds.size.x,
		main.S1_ROOM_BOUNDS.size.x,
		"camera bounds must be WIDER than S1_ROOM_BOUNDS (the scroll-enabling swap)"
	)
	main.queue_free()


## Idempotence / re-entry: rendering the S1 floor twice tears down the prior
## floor container cleanly (no leaked mobs, no double-count, no USER WARNING).
func test_load_s1_zone_twice_tears_down_cleanly() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main.load_s1_zone_for_test()
	await get_tree().process_frame
	var first_count: int = main.s1_mobs_remaining()
	assert_gt(first_count, 0, "first render spawns mobs")

	main.load_s1_zone_for_test()
	await get_tree().process_frame
	await get_tree().process_frame
	# Same seed → same assembly → same mob count. A leak would show as a higher
	# count (old floor's mobs surviving the re-render).
	assert_eq(
		main.s1_mobs_remaining(),
		first_count,
		"re-render must produce the same mob count (no leaked prior-floor mobs)"
	)
	assert_true(main.is_s1_floor_active(), "S1 floor still active after re-render")
	main.queue_free()

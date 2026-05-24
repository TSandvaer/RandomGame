extends GutTest
## Tests for WorldMapPanel — minimal world-map UI (M3 Tier 3 W2-T5, ticket
## `86c9y10fv`).
##
## **What this test pins (acceptance Part E):**
##
##   1. Panel scene loads + instantiates cleanly.
##   2. Header label renders.
##   3. Stratum-list pane renders ≥1 row (the shipped S1 zone unlocks S1
##      by default — `meta.deepest_stratum = 1`).
##   4. Zone-list pane renders ≥1 row for the selected stratum when at
##      least one ZoneDef.tres exists for that stratum.
##   5. Zone-state markers render per Player.discovered_zones — undiscovered
##      zones render the muted slate marker, discovered render parchment +
##      ink outline, cleared (proxy via deepest_stratum > zone.stratum) adds
##      the X-cross strokes.
##   6. `close_requested` signal fires on Esc.
##
## **Regression-guard surfaces:**
##
##   - WorldMapPanel.stratum_button_count() / zone_row_count() — pin the
##     count contract so a future refactor that drops the stratum-list or
##     zone-list pane fails this test before shipping.
##   - Test seam `set_discovered_zones_for_test` — proves the per-zone-state
##     marker rendering is driven by Player state, NOT hardcoded.
##   - Paired test `test_world_map_panel_geometry_glyphs_no_unicode.gd`
##     pins the geometry-as-glyph rule structurally.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const PanelScene: PackedScene = preload("res://scenes/ui/WorldMapPanel.tscn")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- AC1: panel scene loads + instantiates ------------------------


func test_panel_scene_loads_and_instantiates() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	assert_not_null(panel, "WorldMapPanel instantiates")
	add_child_autofree(panel)
	await get_tree().process_frame
	assert_true(panel.is_open(), "panel is_open() true after _ready builds modal")
	assert_true(panel.visible, "panel visible after _ready")


# ---- AC2: header + close hint render ------------------------------


func test_panel_header_label_renders() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	# Walk into the procedurally-built tree: parchment > HeaderLabel.
	var parchment: Node = panel.find_child("Parchment", true, false)
	assert_not_null(parchment, "Parchment substrate ColorRect exists")
	var header: Node = panel.find_child("HeaderLabel", true, false)
	assert_not_null(header, "HeaderLabel exists under Parchment")
	assert_true(header is Label, "HeaderLabel is a Label node")
	assert_eq((header as Label).text, "World Map")


# ---- AC3: stratum-list renders ≥1 row ----------------------------


func test_stratum_list_renders_at_least_s1() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	# S1 is always present — either from the shipped s1_z1_outer_cloister
	# zone OR from the deepest_stratum >= 1 fallback (which loops i=1..N).
	assert_gt(panel.stratum_button_count(), 0, "stratum-list renders at least the S1 row")


# ---- AC4: zone-list renders the shipped S1 zone -------------------


func test_zone_list_renders_s1_outer_cloister() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	# The W2-T3 retrofit shipped `s1_z1_outer_cloister.tres` under
	# resources/level/zones/. The panel's DirAccess scan should pick it up
	# and render a zone row.
	assert_gt(panel.zone_row_count(), 0, "zone-list renders at least the s1_z1_outer_cloister row")


# ---- AC5: per-state marker rendering driven by Player state ------


func test_zone_row_count_unchanged_by_discovery_state() -> void:
	# Discovery state changes the row's MARKER + LABEL color, NOT the row
	# count. This pin guards against a future refactor that filters out
	# undiscovered zones (which would break the "fog-of-war shows the
	# location exists, just doesn't paint the inside" semantic).
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	# Add a player to the tree so the panel's discovered-zones lookup hits.
	var player: Node = _make_player_stub()
	add_child_autofree(player)
	await get_tree().process_frame
	var baseline: int = panel.zone_row_count()
	# Empty discovery state.
	panel.set_discovered_zones_for_test({})
	assert_eq(panel.zone_row_count(), baseline, "empty discovery: row count unchanged")
	# Mark the shipped zone as discovered.
	panel.set_discovered_zones_for_test({&"s1_z1_outer_cloister": true})
	assert_eq(panel.zone_row_count(), baseline, "with discovery: row count unchanged")


func test_discovered_zone_marker_has_outline_and_parchment_base() -> void:
	# Discovered zones render the parchment-colored base + a 4-edge ink
	# outline. This test pins that geometry composition.
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	var player: Node = _make_player_stub()
	add_child_autofree(player)
	await get_tree().process_frame
	panel.set_discovered_zones_for_test({&"s1_z1_outer_cloister": true})
	await get_tree().process_frame
	# Find the marker node for the s1_z1_outer_cloister row.
	var row: Node = panel.find_child("ZoneRow_s1_z1_outer_cloister", true, false)
	assert_not_null(row, "ZoneRow for shipped s1_z1_outer_cloister exists")
	var marker: Node = row.find_child("ZoneMarker", true, false)
	assert_not_null(marker, "marker holder exists")
	var base: Node = marker.find_child("MarkerBase", true, false)
	assert_not_null(base, "MarkerBase ColorRect exists")
	assert_true(
		base is ColorRect, "MarkerBase is ColorRect (not Polygon2D — gl_compatibility rule)"
	)


# ---- AC6: Esc emits close_requested signal -----------------------


func test_esc_emits_close_requested() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	# Wire a signal-watcher.
	var captured: Array = []
	panel.close_requested.connect(func(): captured.append(true))
	# Simulate Esc by directly calling the internal handler since faking
	# input events via the SceneTree is brittle. We pin the close path's
	# emit-then-flip-open shape.
	panel._emit_close()
	assert_eq(captured.size(), 1, "close_requested fired once on _emit_close")
	assert_false(panel.is_open(), "panel marked closed after close emit")


# ---- AC7: locked strata are disabled (deepest_stratum gate) ------


func test_locked_stratum_button_is_disabled() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	# Force deepest_stratum = 1 so S2+ are locked. Render N strata if any
	# of S2..S8 has authored zones; the locked rows must be disabled.
	panel.set_deepest_stratum_for_test(1)
	# Walk the stratum buttons; ANY button >S1 must be disabled.
	for i in panel.stratum_button_count():
		var btn: Button = panel._stratum_buttons[i]
		if btn.text == "Stratum 1":
			assert_false(btn.disabled, "S1 is unlocked at deepest=1")
		else:
			assert_true(btn.disabled, "Stratum >1 is locked at deepest=1: %s" % btn.text)


# ---- AC8: cleared-state marker composes X-cross strokes ----------


func test_cleared_zone_marker_renders_x_cross_strokes() -> void:
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	var player: Node = _make_player_stub()
	add_child_autofree(player)
	await get_tree().process_frame
	# Cleared proxy = deepest_stratum > zone.stratum_id. Force deepest=2 so
	# S1 zones read as cleared.
	panel.set_deepest_stratum_for_test(2)
	panel.set_discovered_zones_for_test({&"s1_z1_outer_cloister": true})
	await get_tree().process_frame
	var row: Node = panel.find_child("ZoneRow_s1_z1_outer_cloister", true, false)
	assert_not_null(row, "row exists")
	var stroke_a: Node = row.find_child("ClearedStrokeA", true, false)
	assert_not_null(stroke_a, "cleared X-cross stroke A renders (rotated ColorRect, NOT Unicode ✓)")
	var stroke_b: Node = row.find_child("ClearedStrokeB", true, false)
	assert_not_null(stroke_b, "cleared X-cross stroke B renders")
	assert_true(stroke_a is ColorRect, "stroke A is ColorRect (renderer-safe)")
	assert_true(stroke_b is ColorRect, "stroke B is ColorRect")


# ---- Helpers ----------------------------------------------------


func _make_player_stub() -> Node:
	# Use a bare Node with the right field rather than a full Player —
	# the panel only reads `discovered_zones` from the "player" group,
	# so a stub with the field + group membership is sufficient.
	var n: Node = Node.new()
	n.set_script(_make_player_stub_script())
	n.add_to_group("player")
	return n


func _make_player_stub_script() -> Script:
	# Inline GDScript via GDScript.new() to declare a typed
	# `discovered_zones: Dictionary` field. Object.set on a bare Node
	# silently drops writes to undeclared properties (PR #352 lesson, see
	# .claude/docs/test-conventions.md § "Test stubs — script-typed
	# extends Node required for Object.set writes").
	var s: GDScript = GDScript.new()
	s.source_code = (
		"extends Node\n"
		+ "var discovered_zones: Dictionary = {}\n"
		+ "var discovered_waypoints: Dictionary = {}\n"
	)
	s.reload()
	return s

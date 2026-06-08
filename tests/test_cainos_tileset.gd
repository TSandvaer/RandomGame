# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Tests for the Cainos S1 paintable TileSet + authoring scene (ticket 86ca64xzb).
##
## The load-bearing bug class this pins: a corner-Wang TerrainSet silently DROPS
## its per-tile peering bits if the .tres is hand-authored (procgen-pipeline.md §
## "Godot autotile TERRAIN authoring"). These tests assert the peering bits are
## actually present in the saved resource — if a future edit hand-writes the
## .tres and the bits vanish, the autotiler falls back to hard edges and these
## tests go red BEFORE the broken tileset ships.
##
## Also smoke-pins that the paintable scene + prop palette LOAD + instantiate
## (the QA gate: "does it open / run"), and that the starter ground patch is
## actually painted (so the scene renders Cainos tiles on first open).

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const TILESET_PATH := "res://resources/tilesets/cainos_s1.tres"
const SCENE_PATH := "res://scenes/levels/s1_yard_authored.tscn"
const PALETTE_PATH := "res://scenes/levels/s1_prop_palette.tscn"

const T_GRASS := 0
const T_PATH := 1
# Solid stone-path fill cell (all 4 corners = path) in the grass source.
const PATH_FILL_CELL := Vector2i(0, 4)
# Plain grass field cell (all 4 corners = grass).
const GRASS_FIELD_CELL := Vector2i(0, 0)
# A vertical-edge transition cell (grass-left, path-right).
const EDGE_CELL := Vector2i(2, 4)


var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


func _load_tileset() -> TileSet:
	return load(TILESET_PATH) as TileSet


# --- TileSet structure ------------------------------------------------------

func test_tileset_resource_loads() -> void:
	assert_not_null(_load_tileset(), "cainos_s1.tres loads as a TileSet")


func test_tile_size_is_32px() -> void:
	assert_eq(_load_tileset().tile_size, Vector2i(32, 32), "32px tiles")


func test_has_six_atlas_sources() -> void:
	# grass + stone_ground + wall + props + plant + struct.
	assert_eq(_load_tileset().get_source_count(), 6, "six atlas sources registered")


func test_terrain_set_exists() -> void:
	assert_eq(_load_tileset().get_terrain_sets_count(), 1, "one terrain set")


func test_terrain_set_is_corner_mode() -> void:
	assert_eq(
		_load_tileset().get_terrain_set_mode(0),
		TileSet.TERRAIN_MODE_MATCH_CORNERS,
		"terrain set 0 is corner-match (the grass↔path Wang mode)"
	)


func test_has_grass_and_path_terrains() -> void:
	var ts := _load_tileset()
	assert_eq(ts.get_terrains_count(0), 2, "two terrains in set 0")
	assert_eq(ts.get_terrain_name(0, T_GRASS), "grass", "terrain 0 = grass")
	assert_eq(ts.get_terrain_name(0, T_PATH), "stone_path", "terrain 1 = stone_path")


# --- Peering bits (the bug-class pin) ---------------------------------------

func test_path_fill_cell_has_all_path_corners() -> void:
	var ts := _load_tileset()
	var src := ts.get_source(0) as TileSetAtlasSource
	var data := src.get_tile_data(PATH_FILL_CELL, 0)
	assert_not_null(data, "path-fill cell tile data exists")
	assert_eq(data.terrain_set, 0, "tile belongs to terrain set 0")
	# All four corners must read the stone_path terrain — the peering bits MUST
	# have survived serialization (the whole reason for the API builder).
	assert_eq(
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER),
		T_PATH, "TL corner = stone_path")
	assert_eq(
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER),
		T_PATH, "TR corner = stone_path")
	assert_eq(
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER),
		T_PATH, "BL corner = stone_path")
	assert_eq(
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER),
		T_PATH, "BR corner = stone_path")


func test_grass_field_cell_has_all_grass_corners() -> void:
	var ts := _load_tileset()
	var src := ts.get_source(0) as TileSetAtlasSource
	var data := src.get_tile_data(GRASS_FIELD_CELL, 0)
	assert_not_null(data, "grass-field cell tile data exists")
	assert_eq(
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER),
		T_GRASS, "grass field TL = grass")
	assert_eq(
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER),
		T_GRASS, "grass field BR = grass")


func test_edge_cell_is_a_real_transition() -> void:
	# A transition tile MUST mix terrains across its corners — if every cell were
	# uniform the autotiler would have no blend tiles and fall to hard edges.
	var ts := _load_tileset()
	var src := ts.get_source(0) as TileSetAtlasSource
	var data := src.get_tile_data(EDGE_CELL, 0)
	assert_not_null(data, "edge cell tile data exists")
	var corners := [
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER),
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER),
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER),
		data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER),
	]
	assert_true(corners.has(T_GRASS), "edge tile has a grass corner")
	assert_true(corners.has(T_PATH), "edge tile has a path corner")


func test_some_transition_tiles_exist() -> void:
	# Count cells whose corners are NOT uniform — must be > 0 or autotiling is dead.
	var ts := _load_tileset()
	var src := ts.get_source(0) as TileSetAtlasSource
	var transitions := 0
	for i in range(src.get_tiles_count()):
		var coord := src.get_tile_id(i)
		var data := src.get_tile_data(coord, 0)
		if data == null:
			continue
		var c := {
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: 0,
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: 0,
		}
		var tl := data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER)
		var tr := data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER)
		var bl := data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER)
		var br := data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER)
		var uniq := {}
		uniq[tl] = true
		uniq[tr] = true
		uniq[bl] = true
		uniq[br] = true
		if uniq.size() > 1:
			transitions += 1
	assert_gt(transitions, 0, "at least one grass↔path transition tile exists")


# --- Paintable scene smoke (the "does it open / run" QA gate) ---------------

func test_authoring_scene_loads() -> void:
	var ps := load(SCENE_PATH) as PackedScene
	assert_not_null(ps, "s1_yard_authored.tscn loads as a PackedScene")


func test_authoring_scene_instantiates_with_layers() -> void:
	var ps := load(SCENE_PATH) as PackedScene
	var root := ps.instantiate()
	add_child_autofree(root)
	assert_not_null(root.get_node_or_null("Ground"), "Ground TileMapLayer present")
	assert_not_null(root.get_node_or_null("StoneGround"), "StoneGround layer present")
	assert_not_null(root.get_node_or_null("Walls"), "Walls layer present")
	assert_not_null(root.get_node_or_null("Props"), "Props container present")
	assert_not_null(root.get_node_or_null("Player"), "Player instance present")


func test_ground_layer_has_cainos_tileset() -> void:
	var ps := load(SCENE_PATH) as PackedScene
	var root := ps.instantiate()
	add_child_autofree(root)
	var ground := root.get_node("Ground") as TileMapLayer
	assert_not_null(ground.tile_set, "Ground has a TileSet assigned")
	assert_eq(ground.tile_set.get_source_count(), 6, "Ground uses the 6-source Cainos set")


func test_starter_ground_patch_is_painted() -> void:
	# Proves the scene renders Cainos tiles the moment it opens (not a blank grid).
	var ps := load(SCENE_PATH) as PackedScene
	var root := ps.instantiate()
	add_child_autofree(root)
	var ground := root.get_node("Ground") as TileMapLayer
	assert_gt(ground.get_used_cells().size(), 100, "starter ground patch is painted")


func test_prop_palette_scene_loads() -> void:
	var ps := load(PALETTE_PATH) as PackedScene
	assert_not_null(ps, "s1_prop_palette.tscn loads")
	var root := ps.instantiate()
	add_child_autofree(root)
	# Carried-forward props present as copyable Sprite2D nodes.
	assert_not_null(root.get_node_or_null("Pillar"), "Pillar prop sprite present")
	assert_not_null(root.get_node_or_null("BrazierLit"), "BrazierLit prop sprite present")

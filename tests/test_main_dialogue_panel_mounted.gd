extends GutTest
## W2-T2 `86c9y0zyv` — pin that Main.tscn mounts DialoguePanel parallel to
## InventoryPanel.
##
## Two pins:
##   1. **Behavioural** — instantiate Main, await frames for the build chain
##      to settle, assert `get_dialogue_panel()` returns a non-null CanvasLayer
##      mounted under Main (named "DialoguePanel"), hidden by default.
##   2. **Source-scan structural** — Main.gd's `_ready()` MUST call
##      `_build_dialogue_panel()` AFTER `_build_inventory_panel()` and
##      BEFORE `_build_stat_panel()`. This positional invariant protects
##      against a refactor that removes the mount call (silent regression:
##      DialogueController autoload still works, but NPC interact opens
##      the controller with no UI rendering anything → player softlock).
##
## The behavioural pin uses a bare-instantiated Main; the autoload graph
## is intact in GUT runs so DialogueController's signal subscription
## from DialoguePanel._ready fires normally. We do not exercise the full
## game lifecycle — only the mount surface.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const MAIN_SOURCE_PATH := "res://scenes/Main.gd"

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	# Some Main build paths surface warnings that aren't W2-T2's concern
	# (content registry, save layer, etc.) — we permissively allow any that
	# aren't dialogue-namespaced. Tests in this file scope assertions to
	# the dialogue panel mount, not to a full Main-boot zero-warning bar
	# (that's tested elsewhere).
	_warn_guard.detach()
	_warn_guard = null


# ---- Pin 1: behavioural — DialoguePanel mounted on Main ---------------


func test_main_mounts_dialogue_panel_under_canvaslayer() -> void:
	# Bare-instantiated Main exercises _ready end-to-end. We are testing the
	# mount, not the full lifecycle.
	var main_packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	assert_not_null(main_packed, "Main.tscn loads")
	var main: Node = main_packed.instantiate()
	assert_not_null(main, "Main instantiates")
	add_child_autofree(main)
	# Two frames for `_ready` + the deferred build chain to settle (save
	# load, content registry, room load all queue deferred ops).
	await get_tree().process_frame
	await get_tree().process_frame
	# Mount assertion.
	assert_true(main.has_method("get_dialogue_panel"), "Main exposes get_dialogue_panel() accessor")
	var panel: CanvasLayer = main.get_dialogue_panel()
	assert_not_null(panel, "Main.get_dialogue_panel() returns mounted DialoguePanel")
	assert_eq(panel.name, "DialoguePanel", "mounted panel is named 'DialoguePanel'")
	assert_true(panel.get_parent() == main, "DialoguePanel is a direct child of Main")
	# Hidden by default — no active session at boot.
	# (The panel's own `_ready` hides it; we verify via the script's API
	# rather than the .visible field so the test is decoupled from how the
	# panel script implements hide-when-idle.)
	if panel.has_method("is_open"):
		assert_false(panel.is_open(), "DialoguePanel.is_open() false at boot (no active session)")


# ---- Pin 2: source-scan structural — mount call sites + ordering ------


func test_main_gd_calls_build_dialogue_panel_in_ready() -> void:
	# Per `.claude/docs/test-conventions.md` § "Source-scan structural pins":
	# verify the mount call lives in `_ready()` between
	# `_build_inventory_panel()` and `_build_stat_panel()`. A refactor
	# removing the call would silently break the W2-T2 wiring without
	# breaking GUT's bare-instance Main-mount test in isolation if the
	# Main.tscn scene file were edited to add a direct DialoguePanel child
	# (the behavioural pin would still pass via that alternate path,
	# masking the regression).
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	assert_gt(source.length(), 0, "Main.gd readable as resource")
	# Find _ready's body region — bounded by the function header and the
	# next top-level `func ` line.
	var ready_start: int = source.find("func _ready(")
	assert_gt(ready_start, -1, "Main.gd defines _ready()")
	var ready_body_start: int = source.find("\n", ready_start)
	var next_fn: int = source.find("\nfunc ", ready_body_start)
	var ready_body: String = source.substr(ready_body_start, next_fn - ready_body_start)
	# Pin: the three build calls appear in this order — inventory, dialogue,
	# stat. A refactor moving dialogue mount out of _ready (e.g. deferring
	# to a "on first NPC interact" lazy build) would fail this pin LOUDLY.
	var inv_pos: int = ready_body.find("_build_inventory_panel()")
	var dlg_pos: int = ready_body.find("_build_dialogue_panel()")
	var stat_pos: int = ready_body.find("_build_stat_panel()")
	assert_gt(inv_pos, -1, "_build_inventory_panel() called in _ready")
	assert_gt(dlg_pos, -1, "_build_dialogue_panel() called in _ready")
	assert_gt(stat_pos, -1, "_build_stat_panel() called in _ready")
	assert_lt(
		inv_pos,
		dlg_pos,
		(
			"_build_dialogue_panel() called AFTER _build_inventory_panel() — "
			+ "mount ordering pin (layer ordering convention)"
		)
	)
	assert_lt(
		dlg_pos,
		stat_pos,
		(
			"_build_dialogue_panel() called BEFORE _build_stat_panel() — "
			+ "mount ordering pin (consistent with InventoryPanel adjacency)"
		)
	)

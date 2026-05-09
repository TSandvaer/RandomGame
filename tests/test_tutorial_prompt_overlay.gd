extends GutTest
## Paired tests for the TutorialPromptOverlay event-bus scaffold (ticket
## `86c9qajcf` — Drew Stage 2b prereq).
##
## Test bar per the M2 W1 polish-design pattern (`team/uma-ux/m2-w1-ux-polish-design.md` §6):
##   - Tier 1 visual primitives — direct color / visibility / signal-fire
##     assertions on real Control nodes (no stubs).
##   - Tier 1 auto-dismiss — drive a real tween + advance time → assert
##     post-dismiss alpha is 0.
##   - Tier 2 bus integration — emit the autoload signal → assert overlay
##     surfaces the resolved text within 1 frame.
##   - HTML5 safety — every painted ColorRect color asserted strictly sub-1.0
##     per channel (HDR-clamp invariant per `.claude/docs/html5-export.md`).
##     Polygon2D-tree-walk assertion mirrors `test_m2_w1_ux_polish.gd::test_t2_toast_has_zero_polygon2d_and_subone_colors`.

const OverlayScript: Script = preload("res://scripts/ui/TutorialPromptOverlay.gd")


func _bus() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("TutorialEventBus")
	assert_not_null(n, "TutorialEventBus autoload registered")
	return n


# ============================================================================
# Tier 1 — visual primitives + HTML5 safety
# ============================================================================

# Tier 1 — `show_prompt` drives Label text + modulate.a delta.
# This is the visual-primitive invariant — `target ≠ rest` per the test bar
# codified in PR #138 (the SWING_FLASH_TINT cautionary tale).
func test_show_prompt_animates_alpha_and_sets_text() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	# Pre-state — alpha 0, label empty.
	assert_almost_eq(overlay.modulate.a, 0.0, 0.001, "overlay starts fully transparent")
	assert_eq(overlay.get_label().text, "", "label starts empty")
	# Fire a prompt.
	overlay.show_prompt("WASD to move.")
	# Text is set synchronously (before any tween steps).
	assert_eq(overlay.get_current_text(), "WASD to move.",
		"current_text reflects the show_prompt argument synchronously")
	assert_eq(overlay.get_label().text, "WASD to move.",
		"Label.text reflects the show_prompt argument synchronously")
	# Advance two frames so the tween fade-in steps.
	await get_tree().process_frame
	await get_tree().process_frame
	# Mid-fade-in — alpha must be > 0 (visible delta, not just tween_valid=true).
	assert_gt(overlay.modulate.a, 0.0,
		"after one frame the fade-in tween produced a non-zero alpha (visible delta — Tier 1 invariant)")


# Tier 1 — `prompt_shown` signal fires post-fade-in.
func test_show_prompt_emits_prompt_shown_signal() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	overlay.show_prompt("Space to dodge-roll.", 0.1)
	# Wait long enough for the fade-in (0.20 s) to finish — the prompt_shown
	# emit fires from the post-fade-in tween_callback.
	await get_tree().create_timer(0.30).timeout
	assert_signal_emitted(overlay, "prompt_shown",
		"prompt_shown fires after fade-in completes")
	var params: Array = get_signal_parameters(overlay, "prompt_shown", 0)
	assert_eq(params[0], "Space to dodge-roll.",
		"prompt_shown payload carries the show_prompt text")


# Tier 1 — auto-dismiss: post-duration the overlay fades back to alpha 0.
# Uses a short duration so the test runs in well under 2 s real time.
func test_show_prompt_auto_dismisses_after_duration() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	# Duration 0.05 s + fade-in 0.20 + fade-out 0.20 = 0.45 s total. Wait 0.65 s
	# to ensure the tween has finished + the dismissal callback has fired.
	overlay.show_prompt("LMB to strike.", 0.05)
	await get_tree().create_timer(0.70).timeout
	assert_almost_eq(overlay.modulate.a, 0.0, 0.05,
		"post-auto-dismiss the overlay alpha returns to ~0 (Tier 1 invariant)")
	assert_signal_emitted(overlay, "prompt_dismissed",
		"prompt_dismissed fires at end of fade-out chain")


# Replace-on-new-show: a second show_prompt while a prompt is in flight
# kills + restarts the tween. Mirrors `test_m2_w1_ux_polish.gd
# ::test_t2_toast_throttle_reuses_single_widget` Godot-4.3 Tween.kill discipline.
func test_replace_on_new_show_kills_in_flight_tween() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	overlay.show_prompt("WASD to move.")
	var first_tween: Tween = overlay._tween
	assert_not_null(first_tween, "first show_prompt created a tween")
	# Replace mid-flight.
	overlay.show_prompt("Space to dodge-roll.")
	var second_tween: Tween = overlay._tween
	assert_not_null(second_tween, "second show_prompt left a tween in place")
	assert_ne(first_tween, second_tween,
		"replace-on-new-show: tween reference flipped (kill + restart pattern)")
	# Sanity — single widget; the Label text reflects the most recent prompt.
	assert_eq(overlay.get_label().text, "Space to dodge-roll.",
		"replace preserves single widget — Label updates to the new prompt")
	assert_eq(overlay.get_current_text(), "Space to dodge-roll.",
		"current_text tracks the most recent show_prompt call")


# Anchor enum — show_prompt with each AnchorPos updates the active anchor.
func test_anchor_enum_applies() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	overlay.show_prompt("WASD to move.", 1.0, TutorialPromptOverlay.AnchorPos.CENTER_TOP)
	assert_eq(overlay.get_current_anchor(), TutorialPromptOverlay.AnchorPos.CENTER_TOP,
		"current_anchor reflects CENTER_TOP")
	overlay.show_prompt("WASD to move.", 1.0, TutorialPromptOverlay.AnchorPos.CENTER)
	assert_eq(overlay.get_current_anchor(), TutorialPromptOverlay.AnchorPos.CENTER,
		"current_anchor reflects CENTER")
	overlay.show_prompt("WASD to move.", 1.0, TutorialPromptOverlay.AnchorPos.BOTTOM)
	assert_eq(overlay.get_current_anchor(), TutorialPromptOverlay.AnchorPos.BOTTOM,
		"current_anchor reflects BOTTOM")


# HTML5 safety — zero Polygon2D in the entire overlay tree, all painted
# colors strictly sub-1.0 per channel (HDR-clamp invariant per
# `.claude/docs/html5-export.md`). Mirrors the SaveToast test pattern.
func test_html5_safety_no_polygon2d_and_subone_colors() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	# Walk every descendant; assert no Polygon2D anywhere.
	var queue: Array = [overlay]
	while not queue.is_empty():
		var n: Node = queue.pop_back()
		assert_false(n is Polygon2D,
			"TutorialPromptOverlay tree must contain zero Polygon2D nodes (HTML5 ban per .claude/docs/html5-export.md)")
		for c in n.get_children():
			queue.append(c)
	# Plate color sub-1.0 per channel.
	var plate: ColorRect = overlay.get_plate()
	assert_not_null(plate, "plate ColorRect exists")
	for ch in [plate.color.r, plate.color.g, plate.color.b]:
		assert_lt(ch, 1.0,
			"plate color channel %f must be strictly sub-1.0 (HDR clamp)" % ch)
	# Plate alpha is sub-1.0 too (75% per design — non-blocking ambient guidance).
	assert_lt(plate.color.a, 1.0,
		"plate alpha sub-1.0 (transparent ambient overlay, per design)")


# ============================================================================
# Tier 2 — bus integration (autoload signal → overlay visible)
# ============================================================================

# Tier 2 — emit `tutorial_beat_requested(&"wasd", anchor)` → overlay surfaces
# the resolved text within 1 frame. This is the Stage 2b prereq invariant —
# Drew fires from Room01, the overlay (mounted in Main HUD) renders.
func test_bus_emit_drives_overlay_show_prompt() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	# Bus emit — directly fire the signal as Drew's Stage 2b would.
	_bus().request_beat(&"wasd", 0)  # 0 = AnchorPos.CENTER_TOP
	# The overlay's _on_tutorial_beat_requested handler runs synchronously
	# inside the emit call (Godot signal dispatch is direct). show_prompt
	# updates Label.text and current_text synchronously.
	assert_eq(overlay.get_current_text(), "WASD to move.",
		"bus emit → overlay resolves &'wasd' → 'WASD to move.' synchronously")
	assert_eq(overlay.get_label().text, "WASD to move.",
		"bus emit → Label.text updates synchronously")
	# After one frame the modulate-tween has stepped — alpha > 0.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(overlay.modulate.a, 0.0,
		"bus emit → overlay alpha rises off 0 (visible delta within 1-2 frames)")


# Tier 2 — bus resolves all 4 reserved beat IDs to their player-journey
# spec text. This is the contract Drew relies on — adding a beat or
# changing a string is a deliberate Drew/Uma decision.
func test_bus_resolves_reserved_beat_ids() -> void:
	assert_eq(_bus().resolve_beat_text(&"wasd"), "WASD to move.",
		"&'wasd' → 'WASD to move.' (player-journey Beat 4)")
	assert_eq(_bus().resolve_beat_text(&"dodge"), "Space to dodge-roll.",
		"&'dodge' → 'Space to dodge-roll.' (player-journey Beat 4)")
	assert_eq(_bus().resolve_beat_text(&"lmb_strike"), "LMB to strike.",
		"&'lmb_strike' → 'LMB to strike.' (player-journey Beat 4)")
	assert_eq(_bus().resolve_beat_text(&"rmb_heavy"), "RMB for heavy strike.",
		"&'rmb_heavy' → 'RMB for heavy strike.' (player-journey Beat 5)")
	# `is_beat_registered` matches the dictionary surface.
	assert_true(_bus().is_beat_registered(&"wasd"), "wasd is registered")
	assert_false(_bus().is_beat_registered(&"unknown_beat"),
		"unregistered beat_id returns false")


# Tier 2 — unregistered beat_id silently no-ops on the overlay (does NOT
# render a blank prompt). This protects against typos in Drew's room script.
func test_bus_emit_unknown_beat_does_not_show_prompt() -> void:
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	# Pre-state — text empty.
	assert_eq(overlay.get_current_text(), "", "current_text empty before emit")
	# Emit an unregistered beat.
	_bus().request_beat(&"definitely_not_a_real_beat", 0)
	# Overlay should NOT have updated current_text — guard against blank-prompt
	# rendering on typos.
	assert_eq(overlay.get_current_text(), "",
		"unregistered beat_id → overlay no-ops (no blank-prompt render)")


# Tier 2 — Main HUD mounts the overlay (integration surface).
# This is the "product completeness ≠ component completeness" guard per
# `team/TESTING_BAR.md` — assert the overlay is reachable via the production
# entry surface, not just instantiable in isolation.
func test_main_hud_mounts_tutorial_overlay() -> void:
	# Reset save slot so the boot-restore path doesn't pollute sibling tests.
	# Mirrors `test_boot.gd::test_main_scene_instantiates` discipline.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn loads")
	var main: Main = packed.instantiate() as Main
	assert_not_null(main, "Main.tscn instantiates as Main")
	add_child_autofree(main)
	# Wait one frame so _ready has run + _build_hud has mounted the overlay.
	await get_tree().process_frame
	var overlay: TutorialPromptOverlay = main.get_tutorial_overlay()
	assert_not_null(overlay, "Main.get_tutorial_overlay returns the mounted overlay")
	# Overlay parent is the HUD CanvasLayer.
	var parent: Node = overlay.get_parent()
	assert_not_null(parent, "overlay has a parent")
	assert_eq(String(parent.name), "HUD",
		"overlay is parented under the HUD CanvasLayer (not InventoryPanel / DescendScreen)")

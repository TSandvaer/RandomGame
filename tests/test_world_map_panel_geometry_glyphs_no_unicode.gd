extends GutTest
## Regression-guard for the geometry-as-glyph rule — M3 Tier 3 W2-T5
## (ticket `86c9y10fv`, paired test E2).
##
## **What this pins:** every visible text element in WorldMapPanel
## (Label, Button, RichTextLabel) carries ONLY ASCII characters. No
## U+2713 `✓`, no arrows (`↔` / `↓` / `→`), no box-drawing, no other
## non-ASCII glyph that would render as tofu in Godot 4.3's HTML5
## default font (per `.claude/docs/html5-export.md` § "Default-font
## glyph coverage").
##
## **Why structural:** the HTML5 tofu trap was caught the HARD way three
## times (PR #179 equipped-item ✓ badge → PR #308 world-map direction
## extends the rule to all UI tally-markers → PR #328 procgen debug-log
## ↔ separator). A test that pins "no non-ASCII glyphs in panel text"
## catches the regression before it ships, regardless of whether the
## author knew about the rule.
##
## **What this does NOT cover:**
##   - Non-text geometry (ColorRect strokes, marker shapes). Those are
##     pinned by `test_world_map_panel_renders_stratum_list.gd` via the
##     "cleared marker has X-cross strokes" + "MarkerBase is ColorRect"
##     assertions.
##   - Text that is generated at runtime from save data (e.g. NPC names
##     authored in `.tres` content). Content drift is a separate failure
##     class; this test ensures the PANEL'S OWN STRINGS are clean.
##
## **Survives reflow:** the test walks every Label / Button / RichTextLabel
## node under the panel and checks its `text` property — does not depend
## on specific node names or layout. A panel refactor that moves UI
## elements around but keeps them text-bearing will still be covered.

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


func test_no_label_carries_non_ascii_glyph_at_initial_render() -> void:
	# Initial render — empty discovery, default selection (S1), default
	# deepest_stratum=1.
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	_assert_no_non_ascii_in_text_nodes(panel)


func test_no_label_carries_non_ascii_glyph_with_discovered_zone() -> void:
	# Discovered render — the zone is rendered as discovered, label color
	# changes from MUTED to BODY, marker composes outline. None of these
	# state changes should introduce non-ASCII text.
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	var player: Node = _make_player_stub()
	add_child_autofree(player)
	await get_tree().process_frame
	panel.set_discovered_zones_for_test({&"s1_z1_outer_cloister": true})
	await get_tree().process_frame
	_assert_no_non_ascii_in_text_nodes(panel)


func test_no_label_carries_non_ascii_glyph_with_cleared_stratum() -> void:
	# Cleared render — the X-cross strokes compose ON TOP of the marker.
	# Per .claude/docs/html5-export.md the X-cross MUST be two rotated
	# ColorRects, NOT a Unicode `✓`. This test catches a regression where
	# someone "simplifies" the geometry-stack to a Label with text "✓".
	var panel: WorldMapPanel = PanelScene.instantiate()
	add_child_autofree(panel)
	var player: Node = _make_player_stub()
	add_child_autofree(player)
	await get_tree().process_frame
	panel.set_deepest_stratum_for_test(2)
	panel.set_discovered_zones_for_test({&"s1_z1_outer_cloister": true})
	await get_tree().process_frame
	_assert_no_non_ascii_in_text_nodes(panel)


# ---- Internal --------------------------------------------------


func _assert_no_non_ascii_in_text_nodes(root: Node) -> void:
	# Walk the panel's tree; collect every Label / Button / RichTextLabel.
	var offenders: Array = []
	_walk_collect_offenders(root, offenders)
	if offenders.size() > 0:
		var lines: Array = []
		for o in offenders:
			lines.append("  %s [%s] -> %s" % [o["path"], o["class"], _escape_for_report(o["text"])])
		fail_test(
			(
				(
					"Non-ASCII glyph(s) found in WorldMapPanel text nodes. "
					+ 'Per `.claude/docs/html5-export.md` § "Default-font glyph '
					+ 'coverage" — these render as notdef "tofu" boxes in '
					+ "HTML5. Use geometry primitives (ColorRect / Line2D / "
					+ "_draw()) for cue glyphs (checkmarks, arrows, indicators) "
					+ "instead of font characters.\n\nOffenders:\n%s"
				)
				% "\n".join(lines)
			)
		)
	# Green assertion so GUT records the pass.
	assert_eq(offenders.size(), 0, "no non-ASCII glyphs in WorldMapPanel text nodes")


func _walk_collect_offenders(n: Node, out: Array) -> void:
	if n is Label:
		_check_text((n as Label).text, n, "Label", out)
	elif n is Button:
		_check_text((n as Button).text, n, "Button", out)
	elif n is RichTextLabel:
		_check_text((n as RichTextLabel).text, n, "RichTextLabel", out)
	for child in n.get_children():
		_walk_collect_offenders(child, out)


func _check_text(text: String, n: Node, kind: String, out: Array) -> void:
	if text.is_empty():
		return
	# Iterate the String as UTF-32 code points. Anything > 127 fails.
	for i in text.length():
		var cp: int = text.unicode_at(i)
		if cp > 127:
			(
				out
				. append(
					{
						"path": str(n.get_path()),
						"class": kind,
						"text": text,
						"first_offender_cp": cp,
					}
				)
			)
			return  # one offender per node is sufficient


func _escape_for_report(s: String) -> String:
	# Escape any control / non-ASCII char into \uXXXX so the test report
	# is readable even when piped through CI's plain-text logs.
	var out: String = '"'
	for i in s.length():
		var cp: int = s.unicode_at(i)
		if cp >= 32 and cp <= 126:
			out += s.substr(i, 1)
		else:
			out += "\\u%04x" % cp
	out += '"'
	return out


func _make_player_stub() -> Node:
	var n: Node = Node.new()
	n.set_script(_make_player_stub_script())
	n.add_to_group("player")
	return n


func _make_player_stub_script() -> Script:
	# Stub uses untyped Dictionary intentionally — see sibling
	# `test_world_map_panel_renders_stratum_list.gd::_make_player_stub_script`
	# for the rationale (inline-GDScript-via-source_code may not parse typed-
	# collection syntax reliably; panel-side lookup tolerates untyped dict
	# with StringName keys).
	var s: GDScript = GDScript.new()
	s.source_code = (
		"extends Node\n"
		+ "var discovered_zones: Dictionary = {}\n"
		+ "var discovered_waypoints: Dictionary = {}\n"
	)
	s.reload()
	return s

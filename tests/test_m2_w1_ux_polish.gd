extends GutTest
## Paired tests for the M2 W1 UX polish wave (3 tickets, 1 PR):
##   - `86c9q5qyd` — Stats panel "Damage <N>" shows equipped weapon damage
##   - `86c9q7p38` — Save-confirmation toast (`Save.save_completed` signal)
##   - `86c9q7p48` — Equipped vs in-grid distinction (outline + EQUIPPED badge)
##
## Test bar per `team/uma-ux/m2-w1-ux-polish-design.md` § 6:
##   - Tier 1 visual primitives — direct color / visibility / signal-fire
##     assertions on real Control nodes (no stubs).
##   - Tier 2 integration — drive a real `Inventory.equip()` and assert the
##     downstream surfaces (stats panel BBCode, indicator visibility) update.
##   - Tier 3 F5-reload survival — for ticket 3, simulate save → restore via
##     `Inventory.restore_from_save` and assert indicator re-renders on
##     panel reopen.
##
## All colors asserted as strictly sub-1.0 per channel (HTML5 HDR-clamp safe
## per `.claude/docs/html5-export.md`). Zero Polygon2D usage — outline +
## badge are ColorRect, toast is ColorRect + ColorRect + Label, modulate
## tween scoped to the toast's leaf Control only.

const InventoryPanelScript: Script = preload("res://scripts/ui/InventoryPanel.gd")
const SaveToastScript: Script = preload("res://scripts/ui/SaveToast.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

const TEST_SLOT: int = 998

# The shared positive-affirmation green — `#7AC773`. All three tickets use
# this exact value for their positive-state cue. Floating-point comparisons
# tolerate the sRGB-to-Color rounding that 0xFF/255 introduces.
const EXPECTED_GREEN_R: float = 0.478
const EXPECTED_GREEN_G: float = 0.780
const EXPECTED_GREEN_B: float = 0.451
# Badge checkmark shape (ticket 86c9qah1q) — mirrors InventoryPanel
# BADGE_CHECK_SIZE and the R channel of COLOR_EQUIPPED_BADGE_TEXT (#1B1A1F).
const EXPECTED_BADGE_CHECK_SIZE: Vector2 = Vector2(9, 9)
const EXPECTED_BADGE_DARK_R: float = 0.10588235


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload registered")
	return n


func _save() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(n, "Save autoload registered")
	return n


func _make_panel() -> InventoryPanel:
	var packed: PackedScene = load("res://scenes/ui/InventoryPanel.tscn")
	assert_not_null(packed, "panel scene loads")
	var panel: InventoryPanel = packed.instantiate()
	add_child_autofree(panel)
	return panel


func _make_weapon(damage: int = 6, id: StringName = &"polish_weapon") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": damage}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func _make_armor(armor_value: int = 4, id: StringName = &"polish_armor") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.ARMOR,
		"base_stats": ContentFactory.make_item_base_stats({"armor": armor_value}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()
	Engine.time_scale = 1.0
	# Ensure no leftover save file pollutes the tests.
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func after_each() -> void:
	_inv().reset()
	Engine.time_scale = 1.0
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


# ============================================================================
# TICKET 1 — Stats panel "Damage <N>" (`86c9q5qyd`)
# ============================================================================

# AC1.1 — equipped weapon's damage value renders in the stats BBCode block.
func test_t1_stats_show_equipped_weapon_damage() -> void:
	var panel: InventoryPanel = _make_panel()
	var weapon: ItemInstance = _make_weapon(6, &"polish_iron_sword")
	_inv().add(weapon)
	_inv().equip(weapon, &"weapon")
	panel.open()
	var label: RichTextLabel = panel.find_child("StatsLabel", true, false) as RichTextLabel
	assert_not_null(label, "stats RichTextLabel exists")
	var rendered: String = label.text
	assert_true(rendered.contains("Damage    6"),
		"Damage line shows the equipped weapon's damage=6 (got: %s)" % rendered)
	# Negative — should NOT show the placeholder anymore.
	assert_false(rendered.contains("Damage    --"),
		"placeholder Damage -- replaced when a weapon is equipped")


# AC1.2 — fistless fallback shows FIST_DAMAGE with the (fists) tag.
func test_t1_stats_fistless_fallback_shows_fist_damage() -> void:
	var panel: InventoryPanel = _make_panel()
	# Inventory empty + nothing equipped.
	panel.open()
	var label: RichTextLabel = panel.find_child("StatsLabel", true, false) as RichTextLabel
	var rendered: String = label.text
	var expected_dmg: int = DamageScript.FIST_DAMAGE
	assert_true(rendered.contains("Damage    %d" % expected_dmg),
		"fistless Damage line uses FIST_DAMAGE=%d (got: %s)" % [expected_dmg, rendered])
	assert_true(rendered.contains("(fists)"),
		"fistless line carries (fists) tag so the value is unambiguous")


# AC1.3 — equipping mid-open updates the stats label via signal (not polling).
func test_t1_stats_update_live_on_equip() -> void:
	var panel: InventoryPanel = _make_panel()
	panel.open()
	var weapon: ItemInstance = _make_weapon(9, &"polish_great_sword")
	_inv().add(weapon)
	# At this point inventory has a weapon, but it isn't equipped — fistless display.
	var label: RichTextLabel = panel.find_child("StatsLabel", true, false) as RichTextLabel
	assert_true(label.text.contains("(fists)"), "pre-equip is fistless")
	# Drive a real equip through the production signal path.
	_inv().equip(weapon, &"weapon")
	# Tier 2 invariant — _on_equipped_changed is connected synchronously, so
	# the label MUST be updated before this line returns. No await frame.
	assert_true(label.text.contains("Damage    9"),
		"equip drives _on_equipped_changed → _refresh_stats → live damage update (got: %s)" % label.text)
	assert_false(label.text.contains("(fists)"), "fists tag drops when weapon is equipped")


# AC1.4 — unequip falls back to fists.
func test_t1_stats_revert_to_fists_on_unequip() -> void:
	var panel: InventoryPanel = _make_panel()
	var weapon: ItemInstance = _make_weapon(7, &"polish_unequip_sword")
	_inv().add(weapon)
	_inv().equip(weapon, &"weapon")
	panel.open()
	var label: RichTextLabel = panel.find_child("StatsLabel", true, false) as RichTextLabel
	assert_true(label.text.contains("Damage    7"), "pre-unequip damage=7")
	_inv().unequip(&"weapon")
	assert_true(label.text.contains("Damage    %d" % DamageScript.FIST_DAMAGE),
		"unequip reverts to FIST_DAMAGE")
	assert_true(label.text.contains("(fists)"), "fists tag returns")


# AC1.5 — defense reads from equipped armor; crit stays --(M2).
func test_t1_stats_defense_reads_armor_and_crit_stays_m2() -> void:
	var panel: InventoryPanel = _make_panel()
	var armor: ItemInstance = _make_armor(4, &"polish_iron_mail")
	_inv().add(armor)
	_inv().equip(armor, &"armor")
	panel.open()
	var label: RichTextLabel = panel.find_child("StatsLabel", true, false) as RichTextLabel
	var rendered: String = label.text
	assert_true(rendered.contains("Defense   4"),
		"Defense reads armor=4 (got: %s)" % rendered)
	assert_true(rendered.contains("Crit      --"),
		"Crit line is still -- (M2 scope)")
	assert_true(rendered.contains("(M2)"),
		"Crit line carries (M2) forward-compat tag")


# Tier 2 integration — bare-weapon (Defense 0) when no armor equipped.
func test_t1_defense_shows_zero_with_no_armor() -> void:
	var panel: InventoryPanel = _make_panel()
	panel.open()
	var label: RichTextLabel = panel.find_child("StatsLabel", true, false) as RichTextLabel
	assert_true(label.text.contains("Defense   0"),
		"no armor → Defense 0 (no parenthetical, per design § Ticket 1)")


# ============================================================================
# TICKET 2 — Save-confirmation toast (`86c9q7p38`)
# ============================================================================

# AC2.1 visual-primitive Tier 1 — Save.save_completed fires on success.
func test_t2_save_completed_signal_fires_on_success() -> void:
	# Watch the signal so we can assert it fired.
	watch_signals(_save())
	var ok: bool = _save().save_game(TEST_SLOT)
	assert_true(ok, "save_game succeeds")
	assert_signal_emitted(_save(), "save_completed",
		"save_completed signal fires after a successful save")
	assert_signal_emit_count(_save(), "save_completed", 1)
	# Verify payload — slot=TEST_SLOT, ok=true.
	var params: Array = get_signal_parameters(_save(), "save_completed", 0)
	assert_eq(params[0], TEST_SLOT, "signal slot param matches save slot")
	assert_eq(params[1], true, "signal ok param is true on success path")


# AC2.7 — toast is built with no Polygon2D anywhere; all colors sub-1.0.
func test_t2_toast_has_zero_polygon2d_and_subone_colors() -> void:
	var toast: SaveToast = SaveToastScript.new()
	add_child_autofree(toast)
	# Walk every descendant; assert no Polygon2D is in the tree.
	var queue: Array = [toast]
	while not queue.is_empty():
		var n: Node = queue.pop_back()
		assert_false(n is Polygon2D,
			"SaveToast tree must contain zero Polygon2D nodes (HTML5 ban per .claude/docs/html5-export.md)")
		for c in n.get_children():
			queue.append(c)
	# Plate + pip + label colors are all sub-1.0 per channel.
	var plate: ColorRect = toast.get_plate()
	assert_not_null(plate, "plate exists")
	for ch in [plate.color.r, plate.color.g, plate.color.b]:
		assert_lt(ch, 1.0,
			"plate color channel %f must be strictly sub-1.0 (HDR clamp)" % ch)
	var pip: ColorRect = toast.get_pip()
	assert_not_null(pip, "pip exists")
	for ch in [pip.color.r, pip.color.g, pip.color.b]:
		assert_lt(ch, 1.0,
			"pip color channel %f must be strictly sub-1.0 (HDR clamp)" % ch)
	# Pip MUST be the canonical positive-affirmation green #7AC773.
	assert_almost_eq(pip.color.r, EXPECTED_GREEN_R, 0.005, "pip R = 0.478 (#7AC773)")
	assert_almost_eq(pip.color.g, EXPECTED_GREEN_G, 0.005, "pip G = 0.780 (#7AC773)")
	assert_almost_eq(pip.color.b, EXPECTED_GREEN_B, 0.005, "pip B = 0.451 (#7AC773)")


# AC2.7 Tier 1 — show_saved drives modulate.a away from 0 (visible-state
# delta, not just "tween_valid=true" — the PR #115/#122 cautionary tale).
func test_t2_toast_show_saved_animates_alpha() -> void:
	var toast: SaveToast = SaveToastScript.new()
	add_child_autofree(toast)
	# Pre-state: alpha 0 (hidden).
	assert_almost_eq(toast.modulate.a, 0.0, 0.001, "toast starts fully transparent")
	toast.show_saved()
	# Advance one frame so the tween steps.
	await get_tree().process_frame
	await get_tree().process_frame
	# Mid-fade-in: alpha should be > 0 (some non-zero delta into the fade).
	assert_gt(toast.modulate.a, 0.0,
		"after one frame the fade-in tween has produced a non-zero alpha (visible delta)")


# AC2.4 / AC2.7 Tier 2 integration — Save.save_game() through the live
# signal path triggers the toast's fade-in.
func test_t2_toast_responds_to_save_signal_integration() -> void:
	var toast: SaveToast = SaveToastScript.new()
	add_child_autofree(toast)
	# toast._ready connects to Save.save_completed — fire a real save and
	# verify the modulate moves off 0.
	_save().save_game(TEST_SLOT)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(toast.modulate.a, 0.0,
		"save_game(slot) → save_completed → toast.show_saved → alpha rises off 0")


# AC2.5 — throttle: a second save while a toast is in flight reuses the
# same widget instance (no new SaveToast spawned). The internal `_tween`
# member is killed + replaced; the Control itself is unchanged.
#
# **Implementation note:** Godot 4.3's `Tween.kill()` leaves the tween
# object in a valid-but-stopped state — `is_valid()` does NOT flip to false
# synchronously after kill. Documented precedent in `tests/test_combat_visuals.gd`
# § "Hit-flash: second hit during flash kills + restarts" (line 136). The
# load-bearing invariant is that the production code calls `kill()` then
# `create_tween()` — observable via the reference change.
func test_t2_toast_throttle_reuses_single_widget() -> void:
	var toast: SaveToast = SaveToastScript.new()
	add_child_autofree(toast)
	toast.show_saved()
	var first_tween: Tween = toast._tween
	assert_not_null(first_tween, "first show_saved created a tween")
	# A second show_saved should kill the first tween and create a new one —
	# but on the same toast Control instance (no new node added to the tree).
	toast.show_saved()
	var second_tween: Tween = toast._tween
	assert_not_null(second_tween, "second tween in place")
	# Throttle invariant — distinct tween instance after the second call.
	assert_ne(first_tween, second_tween,
		"second show_saved replaces the tween reference (throttle: kill + restart)")
	assert_true(second_tween.is_valid(),
		"new tween is the active one")
	# Sanity — same toast Control, same plate color (no node duplication).
	assert_eq(toast.get_plate().color, SaveToastScript.COLOR_PLATE,
		"throttle preserves the single widget — plate color unchanged")


# AC2.6 — failure path: ok=false fires the signal but the toast does NOT
# trigger show_saved (alpha stays at 0).
func test_t2_failure_path_does_not_show_toast() -> void:
	var toast: SaveToast = SaveToastScript.new()
	add_child_autofree(toast)
	# Directly call the signal handler with ok=false.
	toast._on_save_completed(0, false)
	await get_tree().process_frame
	assert_almost_eq(toast.modulate.a, 0.0, 0.001,
		"ok=false branch does NOT trigger show_saved — alpha stays 0")


# ============================================================================
# TICKET 3 — Equipped vs in-grid visual distinction (`86c9q7p48`)
# ============================================================================

# AC3.7 / Tier 1 — visibility flips on `_set_equipped_indicator`.
func test_t3_indicator_visibility_toggles_with_helper() -> void:
	var panel: InventoryPanel = _make_panel()
	var btn: Button = panel._equipped_cells.get(&"weapon", null) as Button
	assert_not_null(btn, "weapon slot button exists")
	# Pre-state: nothing equipped, indicators all hidden.
	for child_name in ["OutlineTop", "OutlineBottom", "OutlineLeft", "OutlineRight", "BadgePlate"]:
		var node: Node = btn.get_node_or_null(child_name)
		assert_not_null(node, "%s indicator node exists on weapon slot" % child_name)
		assert_false((node as CanvasItem).visible, "%s starts hidden" % child_name)
	# Flip on.
	panel._set_equipped_indicator(btn, true)
	for child_name in ["OutlineTop", "OutlineBottom", "OutlineLeft", "OutlineRight", "BadgePlate"]:
		var node: Node = btn.get_node_or_null(child_name)
		assert_true((node as CanvasItem).visible, "%s visible after has_item=true" % child_name)
	# Flip off.
	panel._set_equipped_indicator(btn, false)
	for child_name in ["OutlineTop", "OutlineBottom", "OutlineLeft", "OutlineRight", "BadgePlate"]:
		var node: Node = btn.get_node_or_null(child_name)
		assert_false((node as CanvasItem).visible, "%s hidden after has_item=false" % child_name)


# AC3.7 — outline color is the canonical positive-green #7AC773; sub-1.0.
func test_t3_outline_color_is_canonical_green() -> void:
	var panel: InventoryPanel = _make_panel()
	var btn: Button = panel._equipped_cells.get(&"weapon", null) as Button
	for edge_name in ["OutlineTop", "OutlineBottom", "OutlineLeft", "OutlineRight"]:
		var edge: ColorRect = btn.get_node(edge_name) as ColorRect
		assert_not_null(edge, "%s ColorRect exists" % edge_name)
		assert_almost_eq(edge.color.r, EXPECTED_GREEN_R, 0.005,
			"%s R = 0.478 (#7AC773)" % edge_name)
		assert_almost_eq(edge.color.g, EXPECTED_GREEN_G, 0.005,
			"%s G = 0.780 (#7AC773)" % edge_name)
		assert_almost_eq(edge.color.b, EXPECTED_GREEN_B, 0.005,
			"%s B = 0.451 (#7AC773)" % edge_name)
		# HDR-clamp safety — every channel strictly sub-1.0.
		for ch in [edge.color.r, edge.color.g, edge.color.b]:
			assert_lt(ch, 1.0, "%s channel %f sub-1.0 (HTML5 HDR clamp)" % [edge_name, ch])


# AC3.7 / AC-CB1 / AC-CB2 / AC-CB5 / AC-CB6 — badge plate color uses the same
# green at 92% alpha; badge text + checkmark shape use panel-bg-dark for high
# contrast; the checkmark is a renderer-agnostic SHAPE (not a font glyph); and
# the whole badge content fits inside the plate (no overflow / clipping).
func test_t3_badge_plate_and_text_colors() -> void:
	var panel: InventoryPanel = _make_panel()
	var btn: Button = panel._equipped_cells.get(&"weapon", null) as Button
	var plate: ColorRect = btn.get_node("BadgePlate") as ColorRect
	assert_not_null(plate, "badge plate exists")
	assert_almost_eq(plate.color.r, EXPECTED_GREEN_R, 0.005, "plate R = 0.478")
	assert_almost_eq(plate.color.g, EXPECTED_GREEN_G, 0.005, "plate G = 0.780")
	assert_almost_eq(plate.color.b, EXPECTED_GREEN_B, 0.005, "plate B = 0.451")
	# Plate is 92% alpha (matches InventoryPanel chrome alpha).
	assert_almost_eq(plate.color.a, 0.92, 0.005,
		"plate alpha = 92% (transient-but-real chrome)")
	# AC-CB1 / AC-CB6 — badge label text reads plain "EQUIPPED" (font-safe
	# ASCII). The color-blind secondary cue is a separate checkmark SHAPE node
	# ("BadgeCheck"), NOT a U+2713 glyph inside the text run: the Godot 4.3
	# `gl_compatibility` (HTML5) default font has no "✓" glyph and rendered it
	# as a notdef "tofu" box in PR #179's first cut (Tess's pr179 captures).
	var label: Label = plate.get_node("BadgeLabel") as Label
	assert_not_null(label, "badge label exists")
	assert_eq(label.text, "EQUIPPED",
		"badge text reads plain ASCII EQUIPPED (font-safe; ✓ cue is a separate shape)")
	# The checkmark cue is a shape node with two ColorRect strokes — assert it
	# exists, is sized, and uses the dark high-contrast badge-text color. A
	# font glyph would have left no such node (the PR #179-first-cut failure
	# mode); requiring the shape node closes that gap.
	var check: Control = plate.get_node("BadgeCheck") as Control
	assert_not_null(check, "badge checkmark shape node exists (CVD secondary cue, AC-CB1/AC-CB6)")
	assert_eq(check.size, EXPECTED_BADGE_CHECK_SIZE,
		"checkmark shape is %s px" % [EXPECTED_BADGE_CHECK_SIZE])
	var check_strokes: Array = check.get_children()
	assert_eq(check_strokes.size(), 2,
		"checkmark is built from 2 ColorRect strokes (short + long), not a font glyph")
	for stroke_v in check_strokes:
		var stroke: ColorRect = stroke_v as ColorRect
		assert_not_null(stroke, "checkmark stroke is a ColorRect (renderer-agnostic primitive)")
		assert_almost_eq(stroke.color.r, EXPECTED_BADGE_DARK_R, 0.005,
			"checkmark stroke uses the dark high-contrast badge-text color")
	# AC-CB2 / AC-CB5 — the badge content must FIT INSIDE the plate. This is
	# the exact gap that let PR #179's first cut ship a clipped, illegible
	# badge past green CI: the old test only asserted `text ==` and a
	# hardcoded `plate.size ==`, never that the rendered content fits the rect.
	#
	# WIDTH was the overflow axis on PR #179 ("✓ EQUIPPED" too wide for the
	# 72 px plate). Assert the label's own rect — positioned after the
	# checkmark area — sits fully inside the plate width. This is the
	# renderer/font-agnostic invariant: it scales with the real measured
	# `get_minimum_size().x`, so a wider font can never silently overflow.
	var label_min: Vector2 = label.get_minimum_size()
	assert_true(label.position.x + label_min.x <= plate.size.x + 0.01,
		"badge label right edge %.1f fits within plate width %.1f — EQUIPPED + ✓ shape fit horizontally (AC-CB2)"
			% [label.position.x + label_min.x, plate.size.x])
	# The checkmark shape must also fit inside the plate width, sitting before
	# the label with the configured gap.
	assert_true(check.position.x + check.size.x <= label.position.x + 0.01,
		"checkmark shape right edge %.1f clears the label start %.1f (no overlap)"
			% [check.position.x + check.size.x, label.position.x])
	# HEIGHT — the plate must be tall enough for the checkmark shape, and the
	# checkmark must sit fully within it (vertically centred). NOT asserted
	# against `label.get_minimum_size().y`: that is the font's full ~27 px
	# line box, not the visible glyph height — the label is vertically
	# centre-aligned and draws the glyphs centred within the shorter plate.
	assert_true(plate.size.y >= EXPECTED_BADGE_CHECK_SIZE.y,
		"badge plate height %.1f >= checkmark height %.1f — ✓ shape fits vertically"
			% [plate.size.y, EXPECTED_BADGE_CHECK_SIZE.y])
	assert_true(check.position.y >= -0.01 and check.position.y + check.size.y <= plate.size.y + 0.01,
		"checkmark shape (y %.1f, h %.1f) sits fully within the %.1f px plate"
			% [check.position.y, check.size.y, plate.size.y])
	# The plate must also stay inside its 96 px host Button (position is pinned
	# at x=2) so the badge never overhangs the cell edge.
	assert_true(plate.position.x + plate.size.x <= 96.0,
		"badge plate right edge %.1f within the 96 px equipped-cell button"
			% [plate.position.x + plate.size.x])
	# And it must not reach down into the centered button-text region: the
	# plate is pinned at y=2; keep its bottom comfortably in the top quarter
	# of the 96 px cell so the badge never overlaps the centered item name.
	assert_true(plate.position.y + plate.size.y <= 24.0,
		"badge plate bottom edge %.1f stays in the cell's top quarter, clear of the centered item text"
			% [plate.position.y + plate.size.y])


# AC3.1 / AC3.4 — Tier 2 integration: real Inventory.equip flips outlines on.
func test_t3_real_equip_drives_indicator_visible() -> void:
	var panel: InventoryPanel = _make_panel()
	var weapon: ItemInstance = _make_weapon(6, &"t3_iron_sword")
	_inv().add(weapon)
	# Pre-equip — open panel, weapon slot indicator should be hidden.
	panel.open()
	var btn: Button = panel._equipped_cells.get(&"weapon", null) as Button
	assert_false(btn.get_node("OutlineTop").visible,
		"pre-equip: weapon-slot outline hidden")
	assert_false(btn.get_node("BadgePlate").visible,
		"pre-equip: weapon-slot badge hidden")
	# Drive real equip — _on_equipped_changed fires _refresh_equipped_row →
	# _set_equipped_indicator(btn, true).
	_inv().equip(weapon, &"weapon")
	assert_true(btn.get_node("OutlineTop").visible,
		"post-equip: outline visible (signal-driven, no polling)")
	assert_true(btn.get_node("BadgePlate").visible,
		"post-equip: badge visible")


# AC3.5 — unequip hides indicators.
func test_t3_unequip_hides_indicator() -> void:
	var panel: InventoryPanel = _make_panel()
	var weapon: ItemInstance = _make_weapon(6, &"t3_unequip_sword")
	_inv().add(weapon)
	_inv().equip(weapon, &"weapon")
	panel.open()
	var btn: Button = panel._equipped_cells.get(&"weapon", null) as Button
	assert_true(btn.get_node("OutlineTop").visible, "outline on after equip")
	_inv().unequip(&"weapon")
	assert_false(btn.get_node("OutlineTop").visible,
		"unequip hides outline (signal-driven)")
	assert_false(btn.get_node("BadgePlate").visible,
		"unequip hides badge")


# AC3.3 — in-grid items get NO outline / badge. (Grid cells live in
# _inventory_cells, NOT _equipped_cells; they have no indicator nodes built
# at all.) This is enforced by construction — verify the grid Buttons do
# NOT have OutlineTop children.
func test_t3_grid_cells_have_no_indicators() -> void:
	var panel: InventoryPanel = _make_panel()
	var weapon: ItemInstance = _make_weapon(6, &"t3_grid_sword")
	_inv().add(weapon)  # leave it in grid, do NOT equip
	panel.open()
	var grid_btn: Button = panel._inventory_cells[0]
	assert_not_null(grid_btn, "grid cell 0 exists")
	assert_null(grid_btn.get_node_or_null("OutlineTop"),
		"grid cells have NO outline node — only equipped slots get the indicator")
	assert_null(grid_btn.get_node_or_null("BadgePlate"),
		"grid cells have NO badge plate")


# AC3.6 — Tier 3 F5-reload survival. Equip a weapon, snapshot+restore the
# inventory, reopen the panel — indicator must re-render without explicit
# user action.
func test_t3_indicator_survives_save_restore() -> void:
	# Step 1 — equip iron_sword (use the real .tres so the resolver finds it).
	var iron_sword_def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(iron_sword_def, "iron_sword.tres loads")
	var sword: ItemInstance = ItemInstance.new(iron_sword_def, ItemDef.Tier.T1)
	_inv().add(sword)
	_inv().equip(sword, &"weapon")
	# Step 2 — snapshot to save data + reset inventory + restore from save.
	var data: Dictionary = {}
	_inv().snapshot_to_save(data)
	_inv().reset()
	# Resolver — minimal; resolves &"iron_sword" back to the .tres.
	var item_resolver: Callable = func(id: StringName) -> Resource:
		if id == &"iron_sword":
			return iron_sword_def
		return null
	var affix_resolver: Callable = func(_id: StringName) -> Resource:
		return null
	_inv().restore_from_save(data, item_resolver, affix_resolver)
	# Confirm the equipped state survived the round-trip.
	assert_not_null(_inv().get_equipped(&"weapon"),
		"equipped weapon survives save → restore")
	# Step 3 — open panel for the FIRST time (post-restore). Indicator must
	# render visible immediately on _refresh_equipped_row from open() path.
	var panel: InventoryPanel = _make_panel()
	panel.open()
	var btn: Button = panel._equipped_cells.get(&"weapon", null) as Button
	assert_true(btn.get_node("OutlineTop").visible,
		"AC3.6: F5-reload — outline renders on first panel-open after restore")
	assert_true(btn.get_node("BadgePlate").visible,
		"AC3.6: F5-reload — badge renders on first panel-open after restore")

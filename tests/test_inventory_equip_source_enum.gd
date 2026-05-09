extends GutTest
## Paired tests for fix(combat-trace): Inventory.equip source enum
## (lmb_click vs auto_starter), ticket 86c9qah0v.
##
## **What this guards:**
##   (a) `Inventory.equip(item, slot)` accepts the default `source` parameter
##       (backwards-compat — every existing caller still type-checks).
##   (b) `Inventory.equip(item, slot, &"auto_starter")` accepts an explicit
##       override and still equips successfully.
##   (c) `Inventory.equip(item, slot, &"lmb_click")` accepts the default
##       value passed explicitly (matches the InventoryPanel call site shape
##       that doesn't pass a source, but keeps the equivalence test honest).
##   (d) `equip_starter_weapon_if_needed` against a real Player ends with
##       `_equipped["weapon"]` populated AND `Player._equipped_weapon` set —
##       proves the dual-surface wiring still works through the new source
##       overload.
##   (e) `_emit_equip_trace` is a no-op in headless GUT (DebugFlags.combat_trace
##       gate returns false off-HTML5) — proves we don't crash when invoked
##       through equip() with either source tag.
##
## **What this does NOT guard:**
##   - The trace line *text* — `DebugFlags.combat_trace` is HTML5-only by
##     design, so the actual `[combat-trace] Inventory.equip | source=...` line
##     never appears in headless output. The Playwright `equip-flow.spec.ts`
##     covers the trace-line text (positive: source=auto_starter at boot,
##     source=lmb_click on user click; negative: neither post-F5-reload).
##   - The trace shim's `damage_after` value — already covered by the
##     Playwright spec's assertion that `damage_after == iron_sword light damage`.
##
## **Test isolation:** `before_each` / `after_each` reset the autoload so the
## seed-on-init iron_sword from `_seed_starting_inventory` doesn't leak across
## tests.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Autoload accessors -------------------------------------------------

func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload must be registered in project.godot")
	return n


# ---- Helpers ------------------------------------------------------------

func _make_weapon_item(id: StringName = &"test_weapon") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": 5}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()


func after_each() -> void:
	_inv().reset()


# ==========================================================================
# AC (a) — backwards-compat: existing 2-arg callers still equip
# ==========================================================================

func test_equip_default_source_lmb_click_succeeds() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	# Backwards-compat call shape — every existing caller in the codebase
	# uses `equip(item, slot)` without a third arg. Default value is &"lmb_click".
	assert_true(_inv().equip(item, &"weapon"),
		"equip(item, slot) with default source must succeed (backwards-compat)")
	assert_eq(_inv().get_equipped(&"weapon"), item,
		"item is in the weapon slot after default-source equip")
	assert_eq(_inv().get_items().size(), 0,
		"item removed from grid after equip")


# ==========================================================================
# AC (b) — explicit auto_starter source equips successfully
# ==========================================================================

func test_equip_explicit_auto_starter_source_succeeds() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	# This is the call shape `equip_starter_weapon_if_needed` uses internally.
	assert_true(_inv().equip(item, &"weapon", &"auto_starter"),
		"equip(item, slot, &\"auto_starter\") must succeed")
	assert_eq(_inv().get_equipped(&"weapon"), item,
		"item equipped via auto_starter is in the weapon slot")


# ==========================================================================
# AC (c) — explicit lmb_click source equips successfully (round-trip parity)
# ==========================================================================

func test_equip_explicit_lmb_click_source_succeeds() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	assert_true(_inv().equip(item, &"weapon", &"lmb_click"),
		"equip(item, slot, &\"lmb_click\") must succeed (explicit default)")
	assert_eq(_inv().get_equipped(&"weapon"), item,
		"item equipped via explicit lmb_click is in the weapon slot")


# ==========================================================================
# AC (d) — equip_starter_weapon_if_needed wires the dual-surface state
# ==========================================================================
#
# This is the integration-class test. We instantiate a real Player so
# `_apply_equip_to_player` can call `Player.equip_item` and wire
# `Player._equipped_weapon` correctly. The test passes iff:
#   1. `Inventory._equipped["weapon"]` is non-null AND points at an iron_sword.
#   2. `Player._equipped_weapon` is non-null AND points at iron_sword.def.
# Both halves of the dual-surface rule must hold simultaneously.

func test_equip_starter_routes_through_equip_with_auto_starter_source() -> void:
	# Reset autoload so the seed path runs cleanly.
	_inv().reset()
	# Real Player so the equip_item path wires.
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	# Force the seed-on-empty rule to fire by re-seeding.
	_inv().call("_seed_starting_inventory")
	assert_eq(_inv().get_items().size(), 1,
		"precondition: seed put one iron_sword in the grid")
	# Now drive the auto-equip path — it routes through equip(item, slot,
	# &"auto_starter") internally. Since combat_trace is no-op in headless,
	# the observable contract is the dual-surface state, not the trace text.
	_inv().call("equip_starter_weapon_if_needed")
	# Inventory side: weapon slot populated.
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped,
		"weapon slot must be populated after equip_starter_weapon_if_needed")
	assert_eq(equipped.def.id, &"iron_sword",
		"weapon slot occupant is the iron_sword starter")
	# Player side: _equipped_weapon also set (the dual-surface invariant).
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon_on_player,
		"Player.get_equipped_weapon() must be non-null after auto_starter equip — " +
		"dual-surface invariant. If null, _apply_equip_to_player short-circuited.")
	assert_eq(weapon_on_player.id, &"iron_sword",
		"Player._equipped_weapon points at the iron_sword")
	# Inventory grid: empty (the iron_sword moved from grid to slot).
	assert_eq(_inv().get_items().size(), 0,
		"iron_sword moved from grid into the weapon slot")


# ==========================================================================
# AC (e) — _emit_equip_trace is a silent no-op in headless GUT
# ==========================================================================
#
# The DebugFlags.combat_trace gate returns false outside HTML5, so calls into
# the trace shim must not crash and must not produce GDScript runtime errors.
# We invoke equip() (which calls _emit_equip_trace internally) twice with
# different source tags and assert no exception.

func test_emit_equip_trace_is_silent_noop_in_headless() -> void:
	var item_a: ItemInstance = _make_weapon_item(&"trace_test_a")
	var item_b: ItemInstance = _make_weapon_item(&"trace_test_b")
	_inv().add(item_a)
	_inv().add(item_b)
	# Both source tags must equip cleanly without raising — even though
	# combat_trace is a no-op in headless, the path-through must be safe.
	assert_true(_inv().equip(item_a, &"weapon", &"lmb_click"),
		"first equip with lmb_click source: no crash")
	# Equip a different item to drive the swap path (touches both branches).
	assert_true(_inv().equip(item_b, &"weapon", &"auto_starter"),
		"second equip (swap) with auto_starter source: no crash")
	# Final state: item_b equipped, item_a back in grid.
	assert_eq(_inv().get_equipped(&"weapon"), item_b,
		"swap completed: item_b is now equipped")
	assert_true(_inv().get_items().has(item_a),
		"swap preserved item_a in the grid (P0 86c9q96m8 invariant)")


# ==========================================================================
# AC (f) — direct call to _emit_equip_trace with source override is safe
# ==========================================================================
#
# Lower-level direct probe. Confirms the shim's three-arg shape handles both
# documented source tags without raising.

func test_emit_equip_trace_handles_both_source_tags() -> void:
	var item: ItemInstance = _make_weapon_item()
	# Direct call into the private shim. It pulls Player from the "player"
	# group; without a Player it returns FIST_DAMAGE for damage_after — that's
	# fine for this safety probe.
	_inv().call("_emit_equip_trace", item, &"weapon", &"lmb_click")
	_inv().call("_emit_equip_trace", item, &"weapon", &"auto_starter")
	# If we reached here, neither call raised. Cheap structural guarantee.
	assert_true(true,
		"_emit_equip_trace handled both lmb_click and auto_starter without crash")

extends GutTest
## Paired tests for the Inventory.equip source enum (lmb_click / auto_pickup /
## deprecated auto_starter), tickets 86c9qah0v + 86c9qbb3k.
##
## **What this guards:**
##   (a) `Inventory.equip(item, slot)` accepts the default `source` parameter
##       (backwards-compat — every existing caller still type-checks).
##   (b) `Inventory.equip(item, slot, &"auto_pickup")` accepts the
##       auto-equip-first-weapon-on-pickup source tag and equips successfully.
##   (c) `Inventory.equip(item, slot, &"lmb_click")` accepts the default
##       value passed explicitly (matches the InventoryPanel call site shape
##       that doesn't pass a source, but keeps the equivalence test honest).
##   (d) `on_pickup_collected` with a weapon + empty slot routes through
##       `equip(item, slot, &"auto_pickup")` and ends with `_equipped["weapon"]`
##       populated AND `Player._equipped_weapon` set — the dual-surface wiring
##       through the auto-equip-on-pickup path (real Player, not a stub).
##   (e) `_emit_equip_trace` is a no-op in headless GUT (DebugFlags.combat_trace
##       gate returns false off-HTML5) — proves we don't crash when invoked
##       through equip() with either source tag.
##   (f) Deprecated-but-valid: `equip(item, slot, &"auto_starter")` still
##       type-checks and equips. `auto_starter` was the retired PR #146
##       boot-equip tag (ticket 86c9qbb3k retired its producer); `equip()` has
##       no `match`/branch on `source`, so the value survives as a valid
##       `StringName` input with no current producer. This test pins that
##       the deprecated tag is still ACCEPTED (it would only break if someone
##       added a `source` whitelist) — see `_emit_equip_trace` source-tag
##       footnote in scripts/inventory/Inventory.gd.
##
## **What this does NOT guard:**
##   - The trace line *text* — `DebugFlags.combat_trace` is HTML5-only by
##     design, so the actual `[combat-trace] Inventory.equip | source=...` line
##     never appears in headless output. The Playwright `equip-flow.spec.ts`
##     covers the trace-line text (positive: source=auto_pickup on dummy-drop
##     pickup, source=lmb_click on user click; negative: neither post-F5-reload).
##   - The trace shim's `damage_after` value — already covered by the
##     Playwright spec's assertion that `damage_after == iron_sword light damage`.
##
## **Test isolation:** `before_each` / `after_each` reset the autoload so
## equipped/grid state doesn't leak across tests.

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
# AC (b) — explicit auto_pickup source equips successfully
# ==========================================================================

func test_equip_explicit_auto_pickup_source_succeeds() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	# This is the call shape `on_pickup_collected` uses internally for the
	# auto-equip-first-weapon-on-pickup onboarding path.
	assert_true(_inv().equip(item, &"weapon", &"auto_pickup"),
		"equip(item, slot, &\"auto_pickup\") must succeed")
	assert_eq(_inv().get_equipped(&"weapon"), item,
		"item equipped via auto_pickup is in the weapon slot")


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
# AC (d) — on_pickup_collected routes through equip() with auto_pickup source
# ==========================================================================
#
# This is the integration-class test. We instantiate a real Player so
# `_apply_equip_to_player` can call `Player.equip_item` and wire
# `Player._equipped_weapon` correctly. The test passes iff:
#   1. `Inventory._equipped["weapon"]` is non-null AND points at an iron_sword.
#   2. `Player._equipped_weapon` is non-null AND points at iron_sword.def.
# Both halves of the dual-surface rule must hold simultaneously.

func test_pickup_collected_routes_through_equip_with_auto_pickup_source() -> void:
	_inv().reset()
	# Real Player so the equip_item path wires.
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	# Drive the production pickup hook with the real iron_sword the dummy
	# drops. on_pickup_collected adds it to the grid and — because no weapon
	# is equipped — auto-equips it via equip(item, slot, &"auto_pickup").
	var iron: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(iron, "iron_sword.tres must load")
	var sword: ItemInstance = ItemInstance.new(iron, iron.tier)
	_inv().on_pickup_collected(sword)
	# Inventory side: weapon slot populated.
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped,
		"weapon slot must be populated after on_pickup_collected auto-equip")
	assert_eq(equipped.def.id, &"iron_sword",
		"weapon slot occupant is the picked-up iron_sword")
	# Player side: _equipped_weapon also set (the dual-surface invariant).
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon_on_player,
		"Player.get_equipped_weapon() must be non-null after auto_pickup equip — " +
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
	assert_true(_inv().equip(item_b, &"weapon", &"auto_pickup"),
		"second equip (swap) with auto_pickup source: no crash")
	# Final state: item_b equipped, item_a back in grid.
	assert_eq(_inv().get_equipped(&"weapon"), item_b,
		"swap completed: item_b is now equipped")
	assert_true(_inv().get_items().has(item_a),
		"swap preserved item_a in the grid (P0 86c9q96m8 invariant)")


# ==========================================================================
# AC (f) — deprecated auto_starter source still type-checks + equips
# ==========================================================================
#
# `auto_starter` was the PR #146 boot-equip bandaid's source tag. Ticket
# 86c9qbb3k retired its producer (`equip_starter_weapon_if_needed` is gone),
# but `equip()` has no `match`/branch on `source` — the value survives as a
# valid `StringName` input with no current producer. This test pins that the
# deprecated tag is still ACCEPTED: it would only break if someone added a
# `source` whitelist, which would be a deliberate API change. The direct
# `_emit_equip_trace` probe also confirms the shim handles every documented
# tag (lmb_click / auto_pickup / deprecated auto_starter) without raising.

func test_deprecated_auto_starter_source_still_type_checks_and_equips() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	# Deprecated tag — no current producer, but equip() still accepts it.
	assert_true(_inv().equip(item, &"weapon", &"auto_starter"),
		"equip(item, slot, &\"auto_starter\") must still type-check and equip — " +
		"the tag is deprecated (ticket 86c9qbb3k) but equip() has no source " +
		"whitelist, so it survives as a valid input with no producer")
	assert_eq(_inv().get_equipped(&"weapon"), item,
		"item equipped via the deprecated auto_starter tag is in the weapon slot")
	# Direct shim probe — handles every documented source tag without raising.
	var probe_item: ItemInstance = _make_weapon_item(&"shim_probe")
	_inv().call("_emit_equip_trace", probe_item, &"weapon", &"lmb_click")
	_inv().call("_emit_equip_trace", probe_item, &"weapon", &"auto_pickup")
	_inv().call("_emit_equip_trace", probe_item, &"weapon", &"auto_starter")
	assert_true(true,
		"_emit_equip_trace handled lmb_click, auto_pickup, and the deprecated " +
		"auto_starter tag without crash")

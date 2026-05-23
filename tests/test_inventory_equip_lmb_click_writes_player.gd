extends GutTest
## Paired GUT regression-guard for the Inventory.equip LMB-click path —
## pins the dual-surface invariant at the engine layer so headless CI catches
## P0 86c9q96m8 regressions BEFORE the slower Playwright surface does.
##
## **Ticket 86c9y8fqw** (filed from Tess's chronic-baseline triage as
## "bucket-b regression"). **Triage conclusion: not a regression** — the
## three failing runs cited in the triage doc (`26187844079`, `26099336967`,
## `25986375819`, all 2026-05-17 → 2026-05-20) predate the PR #317 spec-anchor
## fix AND the PR #323 modal-input-gate engine fix. The most-recent main
## Playwright run (`26294689527`, 2026-05-22, post-fix) shows equip-flow
## GREEN. The ticket's hypothesis ("LMB-click path mutated Inventory but
## skipped Player") is empirically REFUTED by the cited runs' own trace
## lines: every failing run logged
## `[combat-trace] Inventory.equip | item=iron_sword slot=weapon
## source=lmb_click damage_after=6` — and `damage_after=6` is computed by
## `_compute_post_equip_damage` reading `Player.get_equipped_weapon()`, so
## Player._equipped_weapon WAS set at equip time. The subsequent
## `Hitbox.hit damage=1` line was the spurious unequip-leak swing (PR #323
## fixed the leak at the engine layer by gating attack-input on the modal-
## input predicate).
##
## **What THIS file pins** (sister to the auto_pickup integration test in
## `test_inventory_equip_source_enum.gd::test_pickup_collected_routes_through_equip_with_auto_pickup_source`):
##
## The user-driven LMB-click path —
## `Inventory.equip(item, &"weapon")` with the default `&"lmb_click"` source
## — fully wires the dual surface:
##   1. `Inventory._equipped["weapon"]` references the equipped instance.
##   2. `Player._equipped_weapon` references the same ItemDef.
##   3. `Player.get_equipped_weapon()` returns the same ItemDef.
##   4. The swap path preserves the previously-equipped item back into the
##      inventory grid (P0 86c9q96m8 — the original "second equipped weapon
##      vanished" bug). Both surfaces stay consistent across swap.
##   5. The fistless→equipped transition flips `Player._equipped_weapon`
##      from null to a real ItemDef and emits `equipped_weapon_changed`.
##
## If a future refactor breaks ANY of these (e.g. `_apply_equip_to_player`
## short-circuits, `Player.equip_item` skips the `_equipped_weapon` writeback,
## `_handle_inventory_click` routes through a code path that bypasses
## `Inventory.equip`), one of the assertions below fails in headless CI
## within ~1.5 min — without waiting for the release-build → Playwright
## chain (~15 min on the fast path).
##
## **Cross-references:**
##   - Sister test: `test_inventory_equip_source_enum.gd::test_pickup_collected_routes_through_equip_with_auto_pickup_source`
##     (auto_pickup path; this file is the lmb_click path).
##   - Playwright: `tests/playwright/specs/equip-flow.spec.ts` § Phase 2.5
##     (HTML5 dual-surface coverage; this file is the headless equivalent).
##   - Closed P0: `86c9q96m8` (original 2026-05-09 equip-vanish bug).
##   - Spec-anchor fix: PR #317 (commit `7e122bd`).
##   - Engine-gate fix: PR #323 (commit `2779647`, modal-input-gate).
##   - Triage doc: `tests/playwright/CHRONIC_BASELINE_TRIAGE.md` § bucket-b.
##   - Memory: `flake-vs-regression-triage` (PR #348 rerun-same-SHA precedent;
##     same shape — initial "regression" hypothesis refuted by empirical
##     evidence).

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Autoload accessors -------------------------------------------------


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload must be registered in project.godot")
	return n


# ---- Helpers ------------------------------------------------------------


func _make_iron_sword() -> ItemInstance:
	# Use the real iron_sword resource so damage/tier propagate as production
	# would. `_apply_equip_to_player` reads `item.def` — using the real
	# resource also doubles as a ContentRegistry path-load smoke test.
	var iron: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(iron, "iron_sword.tres must load (ContentRegistry should resolve)")
	return ItemInstance.new(iron, iron.tier)


func _make_secondary_weapon(id: StringName = &"secondary_sword") -> ItemInstance:
	# Synthesized via ContentFactory so the swap path has a DIFFERENT-instance
	# weapon to land in the slot. Distinct from the real iron_sword resource.
	var def: ItemDef = (
		ContentFactory
		. make_item_def(
			{
				"id": id,
				"slot": ItemDef.Slot.WEAPON,
				"base_stats": ContentFactory.make_item_base_stats({"damage": 8}),
			}
		)
	)
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()


func after_each() -> void:
	_inv().reset()


# ==========================================================================
# AC 1 — LMB-click equip (default source) writes through to Player
# ==========================================================================
#
# The ticket's stated hypothesis. Pinning it at the engine layer means a future
# regression that re-introduces the "LMB-click mutates Inventory but skips
# Player" bug class (the original P0 86c9q96m8) fails in headless CI ~1.5 min
# instead of in Playwright ~15 min.


func test_lmb_click_equip_writes_player_equipped_weapon() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)

	var sword: ItemInstance = _make_iron_sword()
	_inv().add(sword)

	# Pre-condition: Player is fistless. The fistless→equipped transition
	# below is what the P0 86c9q96m8 regression-class broke (the new equipped
	# weapon was silently dropped during the transition).
	assert_null(
		player.get_equipped_weapon(), "Player must start fistless — pre-equip _equipped_weapon is null"
	)

	# Default-source equip — matches `InventoryPanel._handle_inventory_click`'s
	# call shape `inv.equip(item, target)` (no explicit `source` arg, default
	# `&"lmb_click"`).
	assert_true(_inv().equip(sword, &"weapon"), "LMB-click equip succeeds")

	# Inventory surface — slot populated, grid empty.
	var equipped_in_inv: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped_in_inv, "Inventory._equipped[weapon] must be populated")
	assert_eq(equipped_in_inv, sword, "Inventory._equipped[weapon] references the LMB-equipped sword")
	assert_eq(_inv().get_items().size(), 0, "Inventory grid is empty (sword moved to slot)")

	# Player surface — the dual-surface invariant. THIS IS THE LOAD-BEARING
	# ASSERTION FOR P0 86c9q96m8. If a future refactor breaks the writeback
	# (Inventory.equip stops calling _apply_equip_to_player, or
	# Player.equip_item stops setting _equipped_weapon), THIS LINE FAILS.
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(
		weapon_on_player,
		(
			"DUAL-SURFACE INVARIANT BROKEN (P0 86c9q96m8 regression class): "
			+ "Player._equipped_weapon is null after LMB-click equip. "
			+ "Inventory.equip mutated Inventory but did NOT write back to Player. "
			+ "Check Inventory._apply_equip_to_player → Player.equip_item → "
			+ "_equipped_weapon assignment chain."
		)
	)
	assert_eq(
		weapon_on_player.id,
		&"iron_sword",
		"Player._equipped_weapon points at the LMB-equipped iron_sword (not a stale weapon)"
	)


# ==========================================================================
# AC 2 — Explicit `&"lmb_click"` source equip also writes through to Player
# ==========================================================================
#
# Same as AC 1 but with the source tag passed explicitly. Pins that the
# default-arg path and the explicit-arg path produce identical behavior —
# the spec's positive assertion `source=lmb_click` in the trace line depends
# on this equivalence holding.


func test_explicit_lmb_click_source_writes_player_equipped_weapon() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)

	var sword: ItemInstance = _make_iron_sword()
	_inv().add(sword)
	assert_null(player.get_equipped_weapon(), "Player starts fistless")

	# Explicit lmb_click source — mirrors what a future caller might do for
	# clarity. The behavior must be identical to the default-source path.
	assert_true(
		_inv().equip(sword, &"weapon", &"lmb_click"), 'explicit-source LMB equip succeeds'
	)

	assert_eq(_inv().get_equipped(&"weapon"), sword, "Inventory slot populated")
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(
		weapon_on_player, "Player._equipped_weapon is set after explicit-lmb_click equip"
	)
	assert_eq(weapon_on_player.id, &"iron_sword", "Player weapon is iron_sword")


# ==========================================================================
# AC 3 — equip-swap path: both surfaces stay in lockstep
# ==========================================================================
#
# Sponsor M1 RC re-soak attempt 5 (the bug that filed the original P0):
# equipping a second weapon while one was already equipped dropped the
# previously-equipped weapon on the floor (silent loss). PR #159 fixed it by
# preserving the swap order in `Inventory.equip` (erase new item from grid
# BEFORE _unequip_internal so the freed grid slot has room for the old
# equipped item to land in).
#
# This test pins both halves of the swap:
#   1. Inventory side: old item lands in the grid, new item lands in the slot.
#   2. Player side: _equipped_weapon flips from old.def to new.def.


func test_equip_swap_preserves_dual_surface_consistency() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)

	var sword_a: ItemInstance = _make_iron_sword()
	var sword_b: ItemInstance = _make_secondary_weapon(&"secondary_sword")
	_inv().add(sword_a)
	_inv().add(sword_b)

	# Equip A first.
	assert_true(_inv().equip(sword_a, &"weapon"), "first equip succeeds")
	assert_eq(_inv().get_equipped(&"weapon"), sword_a, "sword_a in slot post-equip")
	assert_eq(player.get_equipped_weapon(), sword_a.def, "Player tracks sword_a.def post-equip A")
	assert_eq(_inv().get_items().size(), 1, "only sword_b in grid post-equip A")

	# Equip B — triggers the swap path. The P0 86c9q96m8 fix MUST keep
	# sword_a in the grid after the swap (no silent loss).
	assert_true(_inv().equip(sword_b, &"weapon"), "swap equip succeeds")
	assert_eq(_inv().get_equipped(&"weapon"), sword_b, "sword_b in slot post-swap")
	assert_eq(player.get_equipped_weapon(), sword_b.def, "Player tracks sword_b.def post-swap")
	# Critical P0 86c9q96m8 invariant: the previously-equipped item lands back
	# in the grid. Pre-fix, sword_a was silently dropped here.
	assert_true(
		_inv().get_items().has(sword_a),
		(
			"P0 86c9q96m8 invariant: sword_a (previously equipped) must be "
			+ "preserved in the grid post-swap. Pre-fix this item was silently lost."
		)
	)
	assert_eq(_inv().get_items().size(), 1, "exactly one item in grid (sword_a) post-swap")


# ==========================================================================
# AC 4 — equipped_weapon_changed signal fires on LMB-click equip
# ==========================================================================
#
# HUD listeners depend on `equipped_weapon_changed` to refresh the
# weapon-stat panel. If `Player.equip_item` ever stops emitting the signal
# (a refactor "we're already setting _equipped_weapon, the signal is
# redundant"), the HUD goes stale until the next state-machine tick. Pin
# the signal fires on the LMB-click path so a missed-emit regression is
# caught at the engine layer.


func test_lmb_click_equip_emits_equipped_weapon_changed() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	watch_signals(player)

	var sword: ItemInstance = _make_iron_sword()
	_inv().add(sword)

	assert_true(_inv().equip(sword, &"weapon"), "LMB equip succeeds")
	assert_signal_emitted(
		player,
		"equipped_weapon_changed",
		(
			"Player.equipped_weapon_changed must fire on LMB-click equip — HUD "
			+ "depends on this for the weapon-stat refresh."
		)
	)


# ==========================================================================
# AC 5 — unequip clears Player._equipped_weapon (mirror of AC 1 reverse)
# ==========================================================================
#
# The spec's Phase 2.5 clicks the equipped slot first (to unequip) and then
# clicks the grid cell (to re-equip). For the post-equip swing to deal
# damage=6, `Player._equipped_weapon` MUST be re-set after the unequip
# cleared it. This test pins that the unequip half of that cycle correctly
# clears Player._equipped_weapon to null (otherwise the re-equip would be a
# no-op that didn't really test the writeback path).


func test_unequip_clears_player_equipped_weapon() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)

	var sword: ItemInstance = _make_iron_sword()
	_inv().add(sword)
	assert_true(_inv().equip(sword, &"weapon"), "equip succeeds")
	assert_not_null(player.get_equipped_weapon(), "Player has sword equipped")

	# Unequip via the same `Inventory.unequip(slot)` call the
	# `_handle_equipped_click(&"weapon", MOUSE_BUTTON_LEFT)` path uses.
	var unequipped: ItemInstance = _inv().unequip(&"weapon") as ItemInstance
	assert_eq(unequipped, sword, "unequip returns the previously-equipped sword")

	# Inventory side: slot empty, grid has the sword back.
	assert_null(_inv().get_equipped(&"weapon"), "Inventory weapon slot empty post-unequip")
	assert_true(_inv().get_items().has(sword), "sword landed back in grid post-unequip")

	# Player side: _equipped_weapon cleared. This is the load-bearing
	# pre-condition for the LMB re-equip path in the Playwright spec.
	assert_null(
		player.get_equipped_weapon(),
		(
			"DUAL-SURFACE INVARIANT (unequip half): Player._equipped_weapon must be "
			+ "null after unequip. If non-null, the re-equip path's dual-surface "
			+ "assertion becomes meaningless (no transition to observe)."
		)
	)

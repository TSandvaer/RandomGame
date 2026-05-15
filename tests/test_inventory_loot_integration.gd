extends GutTest
## Integration: MobLootSpawner -> Pickup -> Inventory.
##
## Per Devon run-007 dispatch:
##   1. MobLootSpawner spawns pickups; Inventory ingests them.
##   2. Multiple drops in quick succession all picked up correctly.
##   3. Pickup near full inventory: graceful capacity check.
##
## **Ticket 86c9qbb3k note:** `Inventory.on_pickup_collected` now AUTO-EQUIPS
## the first WEAPON the player picks up (auto-equip-first-weapon-on-pickup —
## the onboarding path that retired the PR #146 boot-equip bandaid). Tests 1
## and 2 here exercise the MobLootSpawner → Pickup → Inventory ROUTING, which
## is orthogonal to equip behaviour — so they drop ARMOR items (armor never
## auto-equips on pickup) to keep the routing assertions clean. Test 4 is the
## dedicated auto-equip-on-pickup-via-this-path coverage.

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")
const PickupScript: Script = preload("res://scripts/loot/Pickup.gd")


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload registered")
	return n


func _make_room_root() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child_autofree(n)
	return n


func _build_table_with(item: ItemDef, count: int = 1) -> LootTableDef:
	var entries: Array[LootEntry] = []
	for i in count:
		entries.append(ContentFactory.make_loot_entry(item, 1.0, 0))
	return ContentFactory.make_loot_table({"entries": entries, "roll_count": count})


func before_each() -> void:
	_inv().reset()


func after_each() -> void:
	_inv().reset()


# =======================================================================
# Test 1 — MobLootSpawner -> Inventory.add fires (via Pickup signal)
# =======================================================================

func test_spawner_drop_routes_to_inventory_via_pickup() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(11)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	# ARMOR item — armor never auto-equips on pickup, so the routing assertion
	# (item lands in the grid) is clean (ticket 86c9qbb3k).
	var item_def: ItemDef = ContentFactory.make_item_def({
		"id": &"int_armor", "slot": ItemDef.Slot.ARMOR,
	})
	var table: LootTableDef = _build_table_with(item_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1, "one drop spawned")
	# Wire each pickup to Inventory's pickup hook (production path).
	_inv().auto_collect_pickups(spawned)
	# Now simulate the player walking onto the pickup -> emits picked_up.
	# Pickup.picked_up is emitted by `_on_body_entered`. We bypass physics by
	# directly emitting from the Pickup; the pickup-hook adds to inventory.
	(spawned[0] as Pickup).emit_signal("picked_up", (spawned[0] as Pickup).item, spawned[0])
	assert_eq(_inv().get_items().size(), 1, "item ingested from spawner -> pickup")
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, item_def.id)


# =======================================================================
# Test 2 — Multiple drops in quick succession all picked up correctly
# =======================================================================

func test_multiple_drops_all_picked_up() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(22)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	# ARMOR items — armor never auto-equips on pickup, so all N drops land in
	# the grid and the count assertion stays clean (ticket 86c9qbb3k).
	var item_def: ItemDef = ContentFactory.make_item_def({
		"id": &"int_burst", "slot": ItemDef.Slot.ARMOR,
	})
	var table: LootTableDef = _build_table_with(item_def, 3)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_gt(spawned.size(), 0, "at least one drop")
	_inv().auto_collect_pickups(spawned)
	for p_v in spawned:
		var p: Pickup = p_v as Pickup
		p.emit_signal("picked_up", p.item, p)
	assert_eq(_inv().get_items().size(), spawned.size(),
		"every spawned drop ended up in inventory")


# =======================================================================
# Test 3 — Pickup near full inventory: graceful capacity check
# =======================================================================

func test_pickup_near_full_inventory_gracefully_rejects() -> void:
	# Fill the inventory to the cap.
	for i in 24:
		var d: ItemDef = ContentFactory.make_item_def({
			"id": StringName("filler_%d" % i),
			"slot": ItemDef.Slot.WEAPON,
		})
		_inv().add(ItemInstance.new(d, ItemDef.Tier.T1))
	assert_true(_inv().is_full(), "inventory full")

	# Spawn one drop and try to ingest.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(33)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)
	var item_def: ItemDef = ContentFactory.make_item_def({"id": &"overflow_weapon"})
	var table: LootTableDef = _build_table_with(item_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})
	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1, "spawner still spawns regardless of inventory")

	_inv().auto_collect_pickups(spawned)
	watch_signals(_inv())
	var pickup: Pickup = spawned[0] as Pickup
	pickup.emit_signal("picked_up", pickup.item, pickup)
	# Capacity respected — inventory still 24 items.
	assert_eq(_inv().get_items().size(), 24, "full inventory does not overflow")
	assert_signal_emitted(_inv(), "add_rejected")
	# Ticket 86c9u33h1 invariant: a rejected add must NOT silently destroy the
	# Pickup. Pre-fix, Pickup._on_body_entered queue_freed itself unconditionally
	# (independent of add()'s result) — and that destruction propagated through
	# `Inventory.on_pickup_collected → add() → false` with no ground-leave or
	# toast: the item was just gone. Post-fix the Pickup must remain alive
	# (`is_instance_valid` true, `is_queued_for_deletion` false) so the player
	# can free a slot and re-collect it.
	assert_true(is_instance_valid(pickup),
		"Pickup must NOT be destroyed when add() rejected the item (full grid) — " +
		"silent-drop is the bug ticket 86c9u33h1 fixes")
	assert_false(pickup.is_queued_for_deletion(),
		"Pickup must NOT be queued for deletion after rejected add — " +
		"the player must be able to re-collect after freeing a slot")
	# Cleanup: pickup is not parented (deferred add_child never landed) and the
	# autofree'd room won't catch it. Free explicitly so test cleanup is clean.
	pickup.free()


# =======================================================================
# Test 4 — auto-equip-first-weapon-on-pickup via the MobLootSpawner path
# =======================================================================

func test_weapon_drop_auto_equips_first_weapon_on_pickup() -> void:
	# Ticket 86c9qbb3k: when a WEAPON is picked up and no weapon is equipped,
	# Inventory.on_pickup_collected auto-equips it. This exercises that through
	# the full MobLootSpawner → Pickup → Inventory path (the same path the
	# Stage-2b dummy drop walks, just via the loot-table spawner).
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(44)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	# A weapon drop (default slot is WEAPON).
	var weapon_def: ItemDef = ContentFactory.make_item_def({"id": &"drop_weapon"})
	var table: LootTableDef = _build_table_with(weapon_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1, "one weapon drop spawned")
	_inv().auto_collect_pickups(spawned)
	# Precondition: no weapon equipped before the pickup.
	assert_null(_inv().get_equipped(&"weapon"), "no weapon equipped pre-pickup")
	# Player walks onto the pickup.
	(spawned[0] as Pickup).emit_signal("picked_up", (spawned[0] as Pickup).item, spawned[0])
	# The weapon must have auto-equipped — not just landed in the grid.
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped,
		"first weapon picked up auto-equips (ticket 86c9qbb3k onboarding rule)")
	assert_eq(equipped.def.id, &"drop_weapon", "the auto-equipped weapon is the dropped one")
	assert_eq(_inv().get_items().size(), 0,
		"the auto-equipped weapon moved from grid into the slot — grid is empty")


# =======================================================================
# Test 5 — full-grid Pickup rejection does NOT auto-equip (ticket 86c9u33h1)
# =======================================================================

func test_full_grid_pickup_does_not_auto_equip_or_destroy() -> void:
	# Ticket 86c9u33h1 — coordination check on PR #194's auto-equip path:
	# when add() rejects (grid full), the auto-equip-first-weapon-on-pickup
	# branch must NOT fire, AND the Pickup must NOT be silently destroyed.
	# Pre-fix, the Pickup queue_freed itself unconditionally; the auto-equip
	# branch was correctly gated by `if not add(item): return` in
	# on_pickup_collected so it never fired on rejection — but the silent-
	# destroy propagated. Post-fix both invariants must hold simultaneously.
	#
	# Set up: fill the inventory to 24/24 with NON-weapons (armor) so the
	# weapon slot stays empty. Drop a weapon. add() rejects on full grid;
	# the weapon must NOT auto-equip, and the Pickup must persist on ground.
	for i in 24:
		var d: ItemDef = ContentFactory.make_item_def({
			"id": StringName("filler_armor_%d" % i),
			"slot": ItemDef.Slot.ARMOR,
		})
		_inv().add(ItemInstance.new(d, ItemDef.Tier.T1))
	assert_true(_inv().is_full(), "inventory full of armor")
	assert_null(_inv().get_equipped(&"weapon"),
		"precondition: no weapon equipped (so auto-equip would fire if not gated)")

	# Spawn a weapon drop.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(55)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)
	var weapon_def: ItemDef = ContentFactory.make_item_def({"id": &"rejected_weapon"})
	var table: LootTableDef = _build_table_with(weapon_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})
	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1)

	_inv().auto_collect_pickups(spawned)
	var pickup: Pickup = spawned[0] as Pickup
	pickup.emit_signal("picked_up", pickup.item, pickup)

	# Invariant A — the weapon must NOT auto-equip on a rejected add.
	assert_null(_inv().get_equipped(&"weapon"),
		"add() rejected → weapon slot stays empty (auto-equip is gated by " +
		"`if not add(item): return` in on_pickup_collected)")
	# Invariant B — the Pickup must NOT be silently destroyed (ticket 86c9u33h1).
	assert_true(is_instance_valid(pickup),
		"Pickup must persist on ground when add() rejects (no silent drop)")
	assert_false(pickup.is_queued_for_deletion(),
		"Pickup must NOT be queued for deletion after rejected add")
	pickup.free()


# =======================================================================
# Test 6 — edge probe: full grid → free a slot → re-collect succeeds
# =======================================================================

func test_full_grid_then_free_slot_pickup_re_collects() -> void:
	# Ticket 86c9u33h1 edge probe: the player approaches a Pickup with the
	# grid at 24/24 (rejection branch fires; Pickup stays on ground), then
	# drops an item to free a slot, then re-collects the Pickup. Post-fix
	# the Pickup should still be alive and a second `picked_up` emission
	# should land in the now-free slot.
	for i in 24:
		var d: ItemDef = ContentFactory.make_item_def({
			"id": StringName("filler_armor_%d" % i),
			"slot": ItemDef.Slot.ARMOR,
		})
		_inv().add(ItemInstance.new(d, ItemDef.Tier.T1))
	assert_true(_inv().is_full())

	# Spawn the loot drop.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(66)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)
	var item_def: ItemDef = ContentFactory.make_item_def({
		"id": &"recovered_loot", "slot": ItemDef.Slot.ARMOR,
	})
	var table: LootTableDef = _build_table_with(item_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})
	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1)
	_inv().auto_collect_pickups(spawned)
	var pickup: Pickup = spawned[0] as Pickup

	# Round 1 — full grid: pickup is rejected and stays on the ground.
	pickup.emit_signal("picked_up", pickup.item, pickup)
	assert_eq(_inv().get_items().size(), 24, "round 1: still full, item rejected")
	assert_true(is_instance_valid(pickup), "round 1: pickup persists")
	assert_false(pickup.is_queued_for_deletion(), "round 1: pickup not freed")

	# Player drops one item to free a slot.
	var dropped: ItemInstance = _inv().get_items()[0]
	assert_true(_inv().remove(dropped), "drop one item to free a slot")
	assert_eq(_inv().get_items().size(), 23, "grid now has a free slot")

	# Round 2 — re-emit picked_up (simulating walk-off + walk-back-on, which
	# in production is the player physically moving away then back; in the
	# test we emit the signal directly since `_on_body_entered` is the only
	# producer and we've already exercised its single-event semantics
	# elsewhere). add() now succeeds; the Pickup is consumed.
	pickup.emit_signal("picked_up", pickup.item, pickup)
	assert_eq(_inv().get_items().size(), 24, "round 2: pickup landed in the freed slot")
	# Find our new item by id (filler items are filler_armor_*; ours is
	# recovered_loot).
	var found: bool = false
	for it_v: Variant in _inv().get_items():
		var it: ItemInstance = it_v as ItemInstance
		if it != null and it.def != null and it.def.id == &"recovered_loot":
			found = true
			break
	assert_true(found, "the recovered_loot item is in the inventory after round 2")
	# Pickup is consumed: queue_freed (still valid this frame, but queued).
	assert_true(pickup.is_queued_for_deletion(),
		"round 2: pickup is queue_freed by Inventory.on_pickup_collected on success")


# =======================================================================
# Bonus probe — direct ingest_rolls helper handles batched roll arrays
# =======================================================================

func test_ingest_rolls_handles_batches() -> void:
	var rolls: Array = []
	for i in 5:
		var d: ItemDef = ContentFactory.make_item_def({
			"id": StringName("batch_%d" % i),
			"slot": ItemDef.Slot.WEAPON,
		})
		rolls.append(ItemInstance.new(d, ItemDef.Tier.T1))
	var accepted: int = _inv().ingest_rolls(rolls)
	assert_eq(accepted, 5, "all 5 rolls accepted")
	assert_eq(_inv().get_items().size(), 5)

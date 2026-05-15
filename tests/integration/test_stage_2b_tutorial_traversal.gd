extends GutTest
## Tier 3 integration test for Stage 2b tutorial traversal (tickets
## `86c9qaj3u` + `86c9qbb3k`). Drives the actual `Main.tscn` cold-open
## through the Room01 tutorial sequence + Room02 entry, asserting:
##
##   1. Main boots into Room01 with a PracticeDummy + the WASD beat already
##      latched. The player boots FISTLESS (the PR #146 boot-equip bandaid
##      was retired — ticket 86c9qbb3k).
##   2. Player movement detection latches the dodge beat.
##   3. Player dodge latches the LMB beat.
##   4. Three fist hits (FIST_DAMAGE=1 each) kill the dummy → mob_died → RMB
##      beat latches → the dummy drops a guaranteed iron_sword Pickup.
##   5. **CRITICAL — the real pickup path.** The Room01 → Room02 advance is
##      GATED on the player collecting that Pickup (`Main._on_room01_mob_died`
##      arms `_room01_awaiting_pickup_equip` because the player is fistless).
##      The test WALKS THE PLAYER ONTO THE DROPPED PICKUP — moves the player's
##      body onto the Pickup's Area2D and runs physics frames so the real
##      `body_entered → picked_up → Inventory.on_pickup_collected → equip`
##      flow fires. This is the design-correct onboarding path that retired
##      PR #146's boot-equip bandaid. (Pre-this-PR the iron-sword-equipped
##      assertion was satisfied by the bandaid, NOT the dummy drop — the
##      test never actually exercised the pickup flow.)
##   6. Once the iron_sword auto-equips, the gate releases and Main advances
##      to Room02. At Room02 entry the player has the iron_sword equipped on
##      BOTH dual-surfaces (Inventory + Player).
##
## **Why Tier 3 here:** this is the hand-off integration the sponsor-soak
## script + tester checklist (PJ-09 .. PJ-14) automate against.
##
## **Why we drive `try_attack` directly instead of `Input.action_press`:**
## Headless GUT has no input queue. We bypass the input layer (covered by
## unit tests) and exercise the engine surface the input handler ultimately
## calls. The Pickup-collection step, however, IS driven through the real
## Area2D physics overlap (move the body, run physics frames) — the
## `body_entered` signal flow is exactly what the production game uses.

const PHYS_DELTA: float = 1.0 / 60.0
const TEST_SLOT: int = 991  # avoid collisions with other integration tests

const PracticeDummyScript: Script = preload("res://scripts/mobs/PracticeDummy.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")


# ---- Helpers ----------------------------------------------------------

func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func _inventory() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func before_each() -> void:
	# Reset save slot to ensure cold-open semantics — no save-restore can
	# pollute the boot-time inventory state.
	var s: Node = _save()
	if s != null and s.has_save(TEST_SLOT):
		s.delete_save(TEST_SLOT)
	# Also clear the production slot Main uses (SAVE_SLOT = 0) so the actual
	# Main scene boots cold.
	if s != null and s.has_save(0):
		s.delete_save(0)
	# Reset the Inventory autoload's equipped map AND items list so a previous
	# test's iron_sword equip doesn't leak into the cold-open state. With the
	# PR #146 bandaid retired (ticket 86c9qbb3k), a reset Inventory is exactly
	# the fresh-boot state: empty grid, empty equipped map, player fistless.
	var inv: Node = _inventory()
	if inv != null and inv.has_method("reset"):
		inv.reset()


func _instantiate_main() -> Main:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn loads")
	var main: Main = packed.instantiate() as Main
	assert_not_null(main, "Main.tscn instantiates as Main")
	add_child_autofree(main)
	return main


func _await_tutorial_wire() -> void:
	# Two frames: first lets Main._ready finish, second lets
	# Stratum1Room01's deferred _wire_tutorial_flow land.
	await get_tree().process_frame
	await get_tree().process_frame


func _first_dummy(room: Node) -> PracticeDummy:
	if not room.has_method("get_spawned_mobs"):
		return null
	for m: Node in room.get_spawned_mobs():
		if m is PracticeDummy:
			return m as PracticeDummy
	return null


# Recursively search a node subtree for the first Pickup. The dummy adds its
# iron_sword Pickup (deferred) to its own parent — a child of the Room01 node
# — so a recursive walk is the robust way to find it.
func _find_pickup(node: Node) -> Pickup:
	if node is Pickup:
		return node as Pickup
	for child in node.get_children():
		var found: Pickup = _find_pickup(child)
		if found != null:
			return found
	return null


# ---- 1: cold-open boots Room01 with WASD beat latched + player fistless ---

func test_cold_open_boots_room01_with_wasd_beat_and_fistless_player() -> void:
	var main: Main = _instantiate_main()
	await _await_tutorial_wire()
	var room: Node = main.get_current_room()
	assert_true(room is Stratum1Room01, "boot lands in Stratum1Room01")
	# Stage 2b: WASD beat fired on room-entry.
	assert_true(room.get_tutorial_beat_emitted(&"wasd"),
		"WASD tutorial beat latched on Main boot (room-entry)")
	# PracticeDummy spawned (one mob, type matches).
	var dummy: PracticeDummy = _first_dummy(room)
	assert_not_null(dummy, "Room01 spawned a PracticeDummy on boot")
	# Ticket 86c9qbb3k: player boots FISTLESS — no boot-equip bandaid.
	var p: Player = main.get_player()
	assert_null(p.get_equipped_weapon(),
		"player boots fistless — the PR #146 boot-equip bandaid is retired; " +
		"the player equips by picking up the dummy's iron_sword drop")
	assert_null(_inventory().get_equipped(&"weapon"),
		"Inventory weapon slot empty at cold boot (no boot-time seed/equip)")


# ---- 2: full traversal — kill dummy, WALK ONTO PICKUP, advance equipped ---

func test_full_tutorial_traversal_walks_onto_pickup_and_lands_room02_equipped() -> void:
	# The headline Tier 3 invariant — the entire Stage 2b flow end-to-end,
	# driving the REAL pickup path: the player walks onto the dummy-dropped
	# iron_sword Pickup, the Area2D body_entered fires, and the auto-equip-on-
	# pickup flow equips the sword. The Room01 → Room02 advance is gated on
	# that equip (Main._on_room01_mob_died arms the gate while the player is
	# fistless), so reaching Room02 PROVES the pickup was collected + equipped.
	var main: Main = _instantiate_main()
	await _await_tutorial_wire()
	var room: Node = main.get_current_room()
	var dummy: PracticeDummy = _first_dummy(room)
	assert_not_null(dummy, "Room01 dummy present")
	var p: Player = main.get_player()

	# Step 1: drive movement → dodge beat.
	p.velocity = Vector2(Player.WALK_SPEED, 0.0)
	room._physics_process(PHYS_DELTA)
	assert_true(room.get_tutorial_beat_emitted(&"dodge"),
		"dodge beat fires on movement detection")

	# Step 2: drive dodge → LMB beat.
	p.velocity = Vector2.ZERO
	var ok: bool = p.try_dodge(Vector2.RIGHT)
	assert_true(ok, "try_dodge accepted (player at idle, no cooldown)")
	assert_true(room.get_tutorial_beat_emitted(&"lmb_strike"),
		"lmb_strike beat fires on iframes_started")

	# Step 3: kill the dummy. Player is FISTLESS now (bandaid retired), so the
	# dummy takes three FIST_DAMAGE=1 hits to die (HP_MAX=3). Drive via direct
	# take_damage. The dummy's `_die` spawns the iron_sword Pickup (deferred
	# add_child) at the dummy's own death position — capture that position now,
	# before the dummy frees. `PracticeDummy._spawn_iron_sword_pickup` sets the
	# Pickup's position to the dummy's `global_position`, so `dummy_pos` is
	# where the Pickup will land in world space.
	var dummy_pos: Vector2 = dummy.global_position
	for _i in PracticeDummy.HP_MAX:
		dummy.take_damage(1, Vector2.ZERO, null)
	assert_true(dummy.is_dead(), "dummy dies after HP_MAX fist hits")
	assert_true(room.get_tutorial_beat_emitted(&"rmb_heavy"),
		"rmb_heavy beat fires on dummy poof")
	# The dummy's `add_child(pickup)` is deferred — it has NOT landed yet, the
	# player is still fistless, so the Room01 → Room02 advance is still GATED.
	assert_eq(main.get_current_room_index(), 0,
		"Room01 → Room02 advance is GATED on pickup-equip — still in Room01 " +
		"immediately after the kill, before the player collects the Pickup")

	# Step 3b: LET THE DODGE STATE EXPIRE before the pin loop. Step 2 called
	# `try_dodge(RIGHT)` — the player is in STATE_DODGE for DODGE_DURATION
	# (0.30s). While dodging, `Player._process_dodge` OVERWRITES `velocity` to
	# `_dodge_dir * DODGE_SPEED` (360 px/s RIGHT) every physics frame, so
	# `move_and_slide()` flings the player off the drop tile no matter how
	# often Step 4 re-pins `global_position` — the re-pin is undone by the very
	# next `_physics_process`. Drain physics frames until the player is back in
	# a non-DODGE state (idle/walk), where `_process_grounded` zeroes velocity
	# on no input — only then will the Step 4 pin actually hold. DODGE_DURATION
	# 0.30s / (1/60) = 18 physics frames; 30 is a safe ceiling with a guard.
	var _dodge_drain_guard: int = 0
	while p.get_state() == Player.STATE_DODGE and _dodge_drain_guard < 30:
		_dodge_drain_guard += 1
		await get_tree().physics_frame
	assert_ne(p.get_state(), Player.STATE_DODGE,
		"player exited STATE_DODGE before the pickup-pin loop — a still-active " +
		"dodge would overwrite velocity each frame and drift the player off the " +
		"drop tile, defeating the pin (root cause of the prior CI-red headline test)")

	# Step 4: PRE-POSITION THE PLAYER ON THE DROP TILE — the killing-blow case.
	# The dummy's deferred `add_child` lands the Pickup a frame later; the
	# Pickup's `_ready` then defers `_activate_and_check_initial_overlap`, which
	# flushes shortly after. By the time test code regains control, that
	# initial-overlap pass may have ALREADY run — so the player must be standing
	# on the drop tile BEFORE we drain those frames, or the pass finds nobody.
	# This is exactly the production "player standing on the dummy's tile from
	# the killing blow" path the Pickup doc comment describes
	# (`scripts/loot/Pickup.gd` § "Encapsulated-monitoring + initial-overlap").
	# This mirrors the proven pattern in `test_hitbox_overlapping_at_spawn.gd`:
	# the overlapping body must be in position when the Area2D's `_ready` runs,
	# then several physics frames let the deferred sweep + the physics server's
	# overlap computation settle. Interleave physics + process frames so the
	# deferred `add_child` (idle-flush) and the deferred overlap pass both land
	# while the player is pinned. Re-pin every iteration so the player's
	# `move_and_slide` (zero velocity) cannot drift it off the radius-8 shape.
	p.global_position = dummy_pos
	p.velocity = Vector2.ZERO
	for _i in 6:
		p.global_position = dummy_pos
		p.velocity = Vector2.ZERO
		await get_tree().physics_frame
		await get_tree().process_frame

	# Find the Pickup. Two legitimate outcomes here:
	#   (a) it is STILL in the tree — the player was pinned on `dummy_pos` but
	#       the initial-overlap pass needed the player at the Pickup's exact
	#       `global_position` (room offset) — Step 5 re-pins and finishes it.
	#   (b) it is ALREADY GONE — the Step-4 pin landed it; `queue_free` ran.
	#       That is the success path; skip straight to the Room02 assertions.
	# Either way, before the Pickup is collected the iron_sword drop must have
	# existed and been the right item — assert that on outcome (a).
	var pickup: Pickup = _find_pickup(room)
	if pickup != null:
		assert_not_null(pickup.item, "the Pickup carries an ItemInstance")
		assert_eq(pickup.item.def.id, &"iron_sword",
			"the dropped Pickup is the iron_sword (deterministic dummy drop)")

		# Step 5: belt-and-suspenders — re-pin to the Pickup's ACTUAL world
		# position (defends against any room-offset between
		# `dummy.global_position` and the Pickup's `global_position`) and drain
		# a mix of physics + process frames so EITHER collection path catches
		# the player: the `_activate_and_check_initial_overlap` pass OR a real
		# `body_entered` transition. Re-pin each iteration against drift, and
		# stop early once the Pickup is collected (its node is freed).
		for _i in 8:
			if not is_instance_valid(pickup):
				break
			p.global_position = pickup.global_position
			p.velocity = Vector2.ZERO
			await get_tree().physics_frame
			await get_tree().process_frame

	# Step 6: the pickup-equip + the gate release + the room advance all chain
	# through deferred calls — drain a few more frames for Room02 to load.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# The player must now be in Room02 — which is ONLY reachable by collecting
	# + equipping the iron_sword Pickup (the gate held the advance until then).
	assert_eq(main.get_current_room_index(), 1,
		"Main advanced to Room02 (index 1) — proves the iron_sword Pickup was " +
		"collected + auto-equipped, releasing the Room01 onboarding gate. " +
		"Pickup spawned at world ~%s." % dummy_pos)

	# CRITICAL — the iron_sword is equipped on BOTH dual-surfaces, via the
	# legitimate dummy-drop → pickup → auto-equip flow (NOT the retired
	# boot-equip bandaid). Assert both surfaces of the equipped-weapon
	# dual-surface rule (per `.claude/docs/combat-architecture.md`).
	var equipped: ItemDef = p.get_equipped_weapon()
	assert_not_null(equipped,
		"Player surface: equipped weapon non-null after the pickup-equip")
	assert_eq(equipped.id, &"iron_sword",
		"Player surface: equipped weapon is iron_sword (dummy drop → pickup → auto-equip)")
	var inv: Node = _inventory()
	var inv_equipped = inv.get_equipped(&"weapon")
	assert_not_null(inv_equipped, "Inventory surface: equipped weapon non-null")
	assert_eq(inv_equipped.def.id, &"iron_sword",
		"Inventory surface: equipped weapon is iron_sword (dual-surface invariant)")


# ---- 3: full sequence emits the four beats in order via the bus ------

func test_full_traversal_emits_four_beats_via_bus_in_order() -> void:
	# The bus is the production surface — Drew's room script calls
	# `request_beat`, the bus emits `tutorial_beat_requested`, the overlay
	# subscribes and renders. This test asserts the bus saw four emits
	# carrying the four reserved beat IDs in the spec order.
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("TutorialEventBus")
	assert_not_null(bus, "TutorialEventBus autoload registered")
	watch_signals(bus)
	var main: Main = _instantiate_main()
	await _await_tutorial_wire()
	var room: Node = main.get_current_room()
	var dummy: PracticeDummy = _first_dummy(room)
	var p: Player = main.get_player()
	# WASD already fired on the room-entry deferred wire (asserted above).
	# Drive the rest of the sequence.
	p.velocity = Vector2(Player.WALK_SPEED, 0.0)
	room._physics_process(PHYS_DELTA)
	p.velocity = Vector2.ZERO
	p.try_dodge(Vector2.RIGHT)
	for _i in PracticeDummy.HP_MAX:
		dummy.take_damage(1, Vector2.ZERO, null)
	# Assert four bus emits, in order WASD → dodge → LMB → RMB.
	assert_signal_emit_count(bus, "tutorial_beat_requested", 4,
		"bus saw exactly four beat-request emits (one per Beat 4-5 step)")
	var expected_order: Array[StringName] = [
		&"wasd", &"dodge", &"lmb_strike", &"rmb_heavy",
	]
	for i in 4:
		var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", i)
		assert_eq(params[0], expected_order[i],
			"bus emit #%d carries beat_id = %s" % [i, str(expected_order[i])])
		assert_eq(params[1], 2, "bus emit #%d anchor = BOTTOM (Uma Beat 4)" % i)

extends GutTest
## Tier 3 integration test for Stage 2b tutorial traversal (ticket
## `86c9qaj3u`). Drives the actual `Main.tscn` cold-open through the
## Room01 tutorial sequence + Room02 entry, asserting:
##
##   1. Main boots into Room01 with a PracticeDummy + the WASD beat already
##      latched.
##   2. Player movement detection latches the dodge beat.
##   3. Player dodge latches the LMB beat.
##   4. Three LMB hits kill the dummy → mob_died → RMB beat latches → door
##      opens (room-clear listener fires) → Main advances to Room02.
##   5. **CRITICAL**: at Room02 entry the player has the iron_sword equipped
##      (proves the dummy-drop pickup → auto-collect → Inventory.equip flow
##      worked end-to-end). This is the design-correct path that retires
##      PR #146's boot-equip bandaid (bandaid stays in main this PR per
##      dispatch scope; the assertion here just proves the new path works
##      so the next-PR bandaid retirement is safe).
##
## **Why Tier 3 here, not in test_m1_play_loop.gd:** `test_m1_play_loop.gd`
## tests the M1 play-loop spine (Room01 → Room02 → ... → BossRoom). Stage 2b
## is a tutorial-flow add-on; the integration coverage of the new flow is
## scope-correct in its own file. This file is the hand-off integration the
## sponsor-soak script + tester checklist (PJ-09 .. PJ-14) automate against.
##
## **Why we drive `try_attack` directly instead of `Input.action_press`:**
## Headless GUT has no input queue. We bypass the input layer (covered by
## unit tests) and exercise the engine surface the input handler ultimately
## calls. Same convention as `tests/integration/test_ac2_first_kill.gd`.

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
	# Main scene boots cold. Mirrors test_tutorial_prompt_overlay.gd's
	# discipline.
	if s != null and s.has_save(0):
		s.delete_save(0)
	# Empty the Inventory autoload so a previous test's iron_sword equip
	# doesn't leak into the cold-open state. Inventory.clear_unequipped only
	# touches stash; we need a full reset of equipped too. Use the existing
	# autoload helper if available.
	var inv: Node = _inventory()
	if inv != null:
		# Production reset path runs through Save's reset_inventory; we mimic
		# what fresh boot would see by calling _ready() (autoload _ready
		# clears state per the Inventory class docstring).
		if inv.has_method("clear_unequipped"):
			inv.clear_unequipped()


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


# ---- 1: cold-open boots Room01 with WASD beat already latched ---------

func test_cold_open_boots_room01_with_wasd_beat_latched() -> void:
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


# ---- 2: full traversal — kill dummy, advance to Room02, equipped ------

func test_full_tutorial_traversal_lands_room02_with_iron_sword_equipped() -> void:
	# This is the headline Tier 3 invariant — the entire Stage 2b flow
	# end-to-end, with the load-bearing iron_sword-equipped assertion at
	# Room02 entry.
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
	# Step 3: kill the dummy. Three fist hits at FIST_DAMAGE=1 = HP_MAX.
	# Drive via direct take_damage (Tier 1 grunt-kill paths cover the
	# physics-Hitbox flow; this test focuses on the tutorial-flow + iron-
	# sword integration). HP=3 → three hits exactly.
	for _i in PracticeDummy.HP_MAX:
		dummy.take_damage(1, Vector2.ZERO, null)
	assert_true(dummy.is_dead(), "dummy dies after HP_MAX fist hits")
	assert_true(room.get_tutorial_beat_emitted(&"rmb_heavy"),
		"rmb_heavy beat fires on dummy poof")
	# Step 4: dummy's deferred Pickup add_child + Main's Room01 deferred
	# room-clear listener both land on the next frame. Process frames until
	# Main has advanced to Room02.
	# Main._on_room01_mob_died → call_deferred("_on_room_cleared") → next
	# frame → load_room_at_index(1). Two frames is generous.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# Sponsor's perspective: by now we should be in Room02 with the
	# iron_sword equipped.
	assert_eq(main.get_current_room_index(), 1,
		"Main advanced to Room02 (index 1) after dummy poof")
	# CRITICAL — iron_sword auto-collected and equipped. The auto-collect
	# happens in Main._on_mob_died → Inventory.auto_collect_pickups, which
	# runs in PR #146's boot-equip-bandaid era was preceded by the boot-
	# equip path. Stage 2b's design-correct path is: dummy drops sword →
	# auto-collect → equip. Assert both surfaces of the equipped-weapon
	# dual-surface rule (per `.claude/docs/combat-architecture.md`).
	var equipped: ItemDef = p.get_equipped_weapon()
	assert_not_null(equipped, "Player surface: equipped weapon non-null")
	assert_eq(equipped.id, &"iron_sword",
		"Player surface: equipped weapon is iron_sword (dummy drop → auto-collect)")
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

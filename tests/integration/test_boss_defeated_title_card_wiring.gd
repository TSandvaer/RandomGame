extends GutTest
## M3-T4 — defeat title card wiring integration.
##
## Verifies that emitting `Stratum1BossRoom.boss_defeated(boss, pos)` from a
## real Main scene tree instantiates a `BossDefeatedTitleCard` child under
## Main with the correct templated title text.
##
## **Why this is integration-scoped, not unit-scoped.** The unit-test file
## (`tests/test_boss_defeated_title_card.gd`) drives the card's `show_for`
## directly and covers the card's internals. This file is the CONTRACT pin
## between Main + Stratum1BossRoom + the card — it catches a regression
## where:
##   - Main fails to subscribe to `boss_defeated` (the `is_connected` guard
##     accidentally short-circuits a fresh wire)
##   - The PackedScene path constant drifts
##   - The card's instantiation crashes during `add_child`
##   - A future refactor splits the `boss_defeated` signal payload shape
##
## **Bug class this catches (PR #216 regression-guard line):** "boss died
## but no title card appeared on screen in the HTML5 release-build."
## The unit-tests pass with a typed boss stub; this test exercises the
## REAL Stratum1Boss → real Stratum1BossRoom → real Main wire-up.

const TEST_SLOT: int = 991  # avoid collision with test_m1_play_loop (994) etc.


func _instantiate_main() -> Main:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var main: Main = packed.instantiate() as Main
	# Reset autoloads to clean state between integration runs.
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	add_child_autofree(main)
	return main


func _reset_autoloads() -> void:
	var levels: Node = _autoload("Levels")
	if levels != null and levels.has_method("reset"):
		levels.reset()
	var stats: Node = _autoload("PlayerStats")
	if stats != null and stats.has_method("reset"):
		stats.reset()
	var inv: Node = _autoload("Inventory")
	if inv != null and inv.has_method("reset"):
		inv.reset()
	var sp: Node = _autoload("StratumProgression")
	if sp != null and sp.has_method("reset"):
		sp.reset()


func _autoload(name: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(name)


func _save() -> Node:
	return _autoload("Save")


# ---- Spec test: Main wires boss_defeated → card instantiation --------

func test_boss_defeated_spawns_title_card_under_main() -> void:
	# Loads Main, advances to the boss room, then synthetically emits the
	# room's `boss_defeated(boss, pos)` signal — proving the wiring from
	# Stratum1BossRoom → Main → BossDefeatedTitleCard is intact.
	#
	# We DON'T drive the whole 8-room play loop to reach the boss death —
	# `test_m1_play_loop.gd` already does the heavyweight end-to-end run.
	# This test isolates the M3-T4 wiring delta and runs in <1s.
	var main: Main = _instantiate_main()
	# Jump straight to the boss room via Main's test surface.
	main.load_room_index(8)
	# Settle a few frames so the room's `call_deferred("_assemble_room_fixtures")`
	# lands and `_wire_room_signals(boss_room, 8)` runs.
	for i in range(5):
		await get_tree().process_frame

	# Main holds the current room in `_world` (Node2D root). The boss room
	# is the only Stratum1BossRoom child during the boss-room phase.
	var world: Node = main.get_node_or_null("World")
	assert_not_null(world, "Main.World child must exist after Main._ready")
	var boss_room: Stratum1BossRoom = null
	for child in world.get_children():
		if child is Stratum1BossRoom:
			boss_room = child as Stratum1BossRoom
			break
	assert_not_null(boss_room, "Stratum1BossRoom must load when room index 8 is requested")

	var boss: Stratum1Boss = boss_room.get_boss()
	assert_not_null(boss, "boss room must spawn a Stratum1Boss")

	# Synthetically emit boss_defeated. This is the same signal the boss's
	# `_die()` chain fires — bypassing the actual fight is sound because
	# the card subscribes via the room's signal, not the boss's.
	var pre_card_count: int = _count_cards_under(main)
	boss_room.boss_defeated.emit(boss, boss.global_position)
	# `_on_boss_defeated` runs synchronously inside the emit; the card is
	# `add_child`ed in the same call. Yield one frame so the card's
	# `_ready` has a chance to build its labels.
	await get_tree().process_frame

	var post_card_count: int = _count_cards_under(main)
	assert_eq(post_card_count, pre_card_count + 1,
		"exactly one BossDefeatedTitleCard must be added under Main when boss_defeated fires")

	var card: BossDefeatedTitleCard = _find_card_under(main)
	assert_not_null(card, "the spawned card must be discoverable under Main")
	# Title text must template from the boss's MobDef.display_name —
	# "Warden of the Outer Cloister" → "Warden" → "The Warden falls."
	assert_eq(card.get_title_label().text, "The Warden falls.",
		"title text templated from boss.mob_def.display_name first-word")
	assert_eq(card.get_subtitle_label().text, "STRATUM 1 CLEARED",
		"subtitle hard-coded for M1")


# ---- Helpers ----------------------------------------------------------

func _count_cards_under(main: Node) -> int:
	var n: int = 0
	for child in main.get_children():
		if child is BossDefeatedTitleCard:
			n += 1
	return n


func _find_card_under(main: Node) -> BossDefeatedTitleCard:
	for child in main.get_children():
		if child is BossDefeatedTitleCard:
			return child as BossDefeatedTitleCard
	return null

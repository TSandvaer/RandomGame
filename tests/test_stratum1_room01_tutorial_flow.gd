extends GutTest
## Tier 2 paired tests for Stratum1Room01's tutorial-beat emission flow
## (Stage 2b — ticket `86c9qaj3u`). Verifies the room script emits the
## reserved beat IDs to TutorialEventBus in the correct order:
##
##   1. On room-entry (post-_ready deferred call) → `&"wasd"`
##   2. On player movement detected (velocity > threshold) → `&"dodge"`
##   3. On first dodge (Player.iframes_started) → `&"lmb_strike"`
##   4. On dummy death (PracticeDummy.mob_died) → `&"rmb_heavy"`
##
## **Why Tier 2 here, not Tier 3:** Tier 1 (PracticeDummy primitives) is in
## `test_practice_dummy.gd`. Tier 3 (full Room01 cold-open traversal +
## iron_sword equipped on Room02 entry) lives in
## `tests/integration/test_stratum1_room01_tutorial_flow.gd`. This file is
## the middle layer — wiring + signal contract.

const Stratum1Room01Script: Script = preload("res://scripts/levels/Stratum1Room01.gd")
const PracticeDummyScript: Script = preload("res://scripts/mobs/PracticeDummy.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Helpers ----------------------------------------------------------

func _bus() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("TutorialEventBus")


func _load_room() -> Stratum1Room01:
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	var room: Stratum1Room01 = packed.instantiate()
	add_child_autofree(room)
	return room


func _spawn_player_in_group() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	# Player._ready adds itself to the "player" group; verify pre-condition.
	assert_true(p.is_in_group("player"),
		"Player added itself to 'player' group on _ready (precondition for room.wire)")
	return p


# Wait for the room's `call_deferred("_wire_tutorial_flow")` to land — runs
# on the NEXT frame after _ready returns. Two process_frames is generous.
func _await_tutorial_wire() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# ---- 1: room-entry fires WASD beat ------------------------------------

func test_room_entry_fires_wasd_beat() -> void:
	# Player must be in the tree (in "player" group) BEFORE the room's
	# deferred wire fires, otherwise `_player` resolves to null. Mirrors the
	# Main._spawn_player → _load_room_at_index ordering.
	_spawn_player_in_group()
	# Watch the bus for the request_beat → tutorial_beat_requested emit.
	var bus: Node = _bus()
	watch_signals(bus)
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# WASD beat fired exactly once on room entry.
	assert_true(room.get_tutorial_beat_emitted(&"wasd"),
		"WASD latch flipped on room-entry deferred wire")
	assert_signal_emit_count(bus, "tutorial_beat_requested", 1,
		"bus saw exactly one beat-request emit (the WASD beat)")
	var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", 0)
	assert_eq(params[0], &"wasd", "first emit carries beat_id = &'wasd'")
	# Drew passes BOTTOM (=2) per Uma Beat 4 "centered low."
	assert_eq(params[1], 2, "anchor = BOTTOM (Uma Beat 4 spec)")


# ---- 2: WASD beat is one-shot (idempotent on re-trigger) --------------

func test_wasd_beat_is_one_shot() -> void:
	_spawn_player_in_group()
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# Manually re-fire the WASD path — must no-op (latch flipped).
	var fired_again: bool = room._emit_beat(Stratum1Room01.BEAT_WASD)
	assert_false(fired_again,
		"second WASD emit attempt is a no-op (latch flipped on first fire)")


# ---- 3: movement detection fires dodge beat --------------------------

func test_movement_detected_fires_dodge_beat() -> void:
	var p: Player = _spawn_player_in_group()
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# Pre-state: dodge latch is false.
	assert_false(room.get_tutorial_beat_emitted(&"dodge"),
		"dodge beat NOT fired pre-movement")
	# Drive the player above MOVEMENT_THRESHOLD_SQ velocity.
	# WALK_SPEED = 120 px/s → 120²=14400 >> 900 (threshold² = 30² = 900).
	p.velocity = Vector2(Player.WALK_SPEED, 0.0)
	# Tick the room's _physics_process so the polling fires.
	room._physics_process(1.0 / 60.0)
	assert_true(room.get_tutorial_beat_emitted(&"dodge"),
		"dodge beat fires once player velocity crosses MOVEMENT_THRESHOLD_SQ")


# ---- 4: idle player does NOT trigger dodge beat ----------------------

func test_idle_player_does_not_fire_dodge_beat() -> void:
	var p: Player = _spawn_player_in_group()
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# Player at rest — velocity below threshold (zero).
	p.velocity = Vector2.ZERO
	# Tick a generous number of frames; dodge must NOT fire.
	for _i in 60:
		room._physics_process(1.0 / 60.0)
	assert_false(room.get_tutorial_beat_emitted(&"dodge"),
		"dodge beat does NOT fire while player is idle (sub-threshold velocity)")


# ---- 5: dodge fires LMB beat via iframes_started signal ---------------

func test_dodge_fires_lmb_strike_beat() -> void:
	var p: Player = _spawn_player_in_group()
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# Pre-state: LMB latch is false.
	assert_false(room.get_tutorial_beat_emitted(&"lmb_strike"),
		"lmb_strike beat NOT fired pre-dodge")
	# Trigger a dodge — Player.try_dodge fires iframes_started.
	var ok: bool = p.try_dodge(Vector2.RIGHT)
	assert_true(ok, "try_dodge accepted (player at rest, no cooldown)")
	# Signal handler runs synchronously on emit.
	assert_true(room.get_tutorial_beat_emitted(&"lmb_strike"),
		"lmb_strike beat fires when iframes_started fires (Player.try_dodge path)")


# ---- 6: dummy death fires RMB beat -----------------------------------

func test_dummy_death_fires_rmb_heavy_beat() -> void:
	_spawn_player_in_group()
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# Find the spawned dummy.
	var dummy: PracticeDummy = null
	for m: Node in room.get_spawned_mobs():
		if m is PracticeDummy:
			dummy = m as PracticeDummy
			break
	assert_not_null(dummy, "Room01 spawned a PracticeDummy")
	# Pre-state: RMB latch is false.
	assert_false(room.get_tutorial_beat_emitted(&"rmb_heavy"),
		"rmb_heavy beat NOT fired pre-dummy-death")
	# Drive lethal damage on the dummy.
	dummy.take_damage(PracticeDummy.HP_MAX, Vector2.ZERO, null)
	# mob_died emits synchronously inside _die.
	assert_true(room.get_tutorial_beat_emitted(&"rmb_heavy"),
		"rmb_heavy beat fires when dummy poofs (PracticeDummy.mob_died path)")


# ---- 7: full beat sequence — WASD → dodge → LMB → RMB ---------------

func test_full_beat_sequence_in_order() -> void:
	# This is the headline Tier 2 invariant — the four beats fire in the
	# spec order across one Room01 traversal. Assert the per-beat latches
	# flip in sequence; the bus's signal-emit count is asserted in test 1.
	var p: Player = _spawn_player_in_group()
	var room: Stratum1Room01 = _load_room()
	await _await_tutorial_wire()
	# 1. WASD on room-entry.
	assert_true(room.get_tutorial_beat_emitted(&"wasd"), "step 1: WASD")
	# 2. Movement → dodge prompt.
	p.velocity = Vector2(Player.WALK_SPEED, 0.0)
	room._physics_process(1.0 / 60.0)
	assert_true(room.get_tutorial_beat_emitted(&"dodge"), "step 2: dodge")
	# 3. Dodge → LMB prompt.
	p.velocity = Vector2.ZERO  # snap back so try_dodge can fire (state idle)
	var ok: bool = p.try_dodge(Vector2.RIGHT)
	assert_true(ok, "try_dodge accepted")
	assert_true(room.get_tutorial_beat_emitted(&"lmb_strike"), "step 3: LMB")
	# 4. Dummy poof → RMB prompt.
	var dummy: PracticeDummy = null
	for m: Node in room.get_spawned_mobs():
		if m is PracticeDummy:
			dummy = m as PracticeDummy
			break
	assert_not_null(dummy)
	dummy.take_damage(PracticeDummy.HP_MAX, Vector2.ZERO, null)
	assert_true(room.get_tutorial_beat_emitted(&"rmb_heavy"), "step 4: RMB")


# ---- 8: room with no player gracefully no-ops ------------------------

func test_room_with_no_player_does_not_crash_on_wire() -> void:
	# Defensive: tests that load the room scene without a Player in the tree
	# (e.g. test_stratum1_room.gd's geometry tests) must not crash on the
	# deferred tutorial wire. The wire fires WASD unconditionally (player-
	# independent) and skips the iframes_started subscription when player is
	# null — this verifies the null-player branch.
	var room: Stratum1Room01 = _load_room()
	# DO NOT spawn a player. Wait for the deferred wire.
	await _await_tutorial_wire()
	# WASD still fires (player-independent emit).
	assert_true(room.get_tutorial_beat_emitted(&"wasd"),
		"WASD fires even with no player in tree (player-independent emit)")
	# dodge / LMB don't fire — no player ref to subscribe to.
	assert_false(room.get_tutorial_beat_emitted(&"dodge"))
	assert_false(room.get_tutorial_beat_emitted(&"lmb_strike"))


# ---- 9: TutorialPromptOverlay defaults reconciled with Uma Beat 4 ----

func test_overlay_defaults_match_uma_beat_4_spec() -> void:
	# Tess PR #164 review note: the scaffold shipped with CENTER_TOP anchor
	# default + 75% plate alpha + 100% text alpha. Uma Beat 4 spec is
	# bottom-center + no panel + 60% text opacity. Stage 2b reconciles the
	# defaults so the overlay surfaces Drew's beats per spec without the
	# per-call anchor/color override.
	var OverlayScript: Script = load("res://scripts/ui/TutorialPromptOverlay.gd")
	var overlay: TutorialPromptOverlay = OverlayScript.new()
	add_child_autofree(overlay)
	# Default anchor is BOTTOM.
	assert_eq(overlay.get_current_anchor(), TutorialPromptOverlay.AnchorPos.BOTTOM,
		"overlay default anchor = BOTTOM (Uma Beat 4 'centered low')")
	# Plate alpha is 0 (no panel background).
	var plate: ColorRect = overlay.get_plate()
	assert_almost_eq(plate.color.a, 0.0, 0.001,
		"plate alpha = 0 (Uma Beat 4 'no panel background')")
	# Text alpha is 60% — assert via the script-level constant which is the
	# single source of truth (label's theme_color override is set FROM this
	# const in `_build_ui`, so checking the const + the construction path
	# is the load-bearing invariant; reading the override back through Label
	# theme APIs is brittle in headless GUT).
	assert_almost_eq(TutorialPromptOverlay.COLOR_TEXT.a, 0.6, 0.001,
		"COLOR_TEXT alpha = 60% (Uma Beat 4 'white text 60% opacity')")

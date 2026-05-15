extends GutTest
## Pair test for the `[combat-trace] Player._die` + `[combat-trace]
## Main.apply_death_rule` diagnostic lines (ticket 86c9u397c, Drew, 2026-05-15).
##
## **Why these two trace lines are load-bearing.** The 86c9u397c bug brief
## hypothesised a "death-path sibling-freeze" — that one mob's `_die` chain
## ran a non-deferred Area2D mutation that silenced surviving siblings'
## `_physics_process`. Empirical investigation against a release build of
## `40a8a7d` showed the actual cause was different: in Room 05's 3-mob
## combat the PLAYER dies (3 concurrent chasers deal damage faster than
## near-spawn click-spam can clear them), the M1 death rule reloads Room 01,
## and Room 05's surviving mobs are FREED by the room-load — not frozen.
##
## The hypothesis was unfalsifiable from the trace alone because:
##   - `Player._die` had no `[combat-trace]` line — Player death was invisible
##   - `Main.apply_death_rule` had no `[combat-trace]` line — room reload
##     was invisible
##   - Surviving mobs' `.pos` traces stop (mobs were freed) — looks like freeze
##   - Player keeps swinging in Room 01 — looks like "Player alive"
##   - Player.pos jumps to `DEFAULT_PLAYER_SPAWN = (240, 200)` — looks like
##     "Player at center of Room 05" (it's actually the respawn teleport)
##
## With these two trace lines, any future investigation in the "mob freeze"
## class can disambiguate Player-death-driven mob disappearance from a real
## physics-flush sibling-freeze in one grep over the trace stream.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- CombatTraceSpy infra (mirrors test_grunt.gd / test_charger.gd) ----

class CombatTraceSpy:
	extends Node
	var calls: Array = []  # Array of [tag, msg]
	func combat_trace(tag: String, msg: String = "") -> void:
		calls.append([tag, msg])
	func has_tag(tag: String) -> bool:
		for c: Array in calls:
			if c[0] == tag:
				return true
		return false
	func msg_for(tag: String) -> String:
		for c: Array in calls:
			if c[0] == tag:
				return c[1]
		return ""


func _install_combat_trace_spy() -> CombatTraceSpy:
	var root: Node = get_tree().root
	var real: Node = root.get_node_or_null("DebugFlags")
	assert_not_null(real, "DebugFlags autoload must exist to swap for the spy")
	real.name = "DebugFlags__real_parked_diepair"
	var spy: CombatTraceSpy = CombatTraceSpy.new()
	spy.name = "DebugFlags"
	root.add_child(spy)
	return spy


func _restore_debug_flags(spy: CombatTraceSpy) -> void:
	var root: Node = get_tree().root
	root.remove_child(spy)
	spy.free()
	var parked: Node = root.get_node_or_null("DebugFlags__real_parked_diepair")
	if parked != null:
		parked.name = "DebugFlags"


func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# ---- 1: Player._die emits the diagnostic trace line --------------------

func test_player_die_emits_combat_trace_line() -> void:
	# Player taking damage equal to max HP (lethal) must fire the
	# `[combat-trace] Player._die` line so any future "mobs froze" investigation
	# can rule out player death by a single grep over the trace stream.
	var p: Player = _make_player_in_tree()
	p.global_position = Vector2(123, 456)  # known coords — assert payload
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	# Lethal damage: take max HP. take_damage → _die when hp_current == 0.
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	var emitted: bool = spy.has_tag("Player._die")
	var msg: String = spy.msg_for("Player._die")
	_restore_debug_flags(spy)
	assert_true(emitted,
		"REGRESSION-86c9u397c: Player._die must emit a [combat-trace] line. " +
		"Without it, a Player-death + M1-death-rule room reload presents the " +
		"exact same trace shape as a sibling-mob _physics_process freeze, and " +
		"investigations chase the wrong root cause (the 86c9u397c brief is the " +
		"cautionary tale).")
	assert_string_contains(msg, "hp=0",
		"Player._die payload must include 'hp=0' so the trace pinpoints the " +
		"lethal-damage moment unambiguously")
	assert_string_contains(msg, "pos=(123,456)",
		"Player._die payload must carry the death position so investigations " +
		"can correlate against the room geometry")


# ---- 2: Player._die is one-shot per life (mirrors player_died signal) --

func test_player_die_combat_trace_is_one_shot_per_life() -> void:
	# Player.gd already guards `player_died.emit` with `_is_dead` so multi-hit
	# collapse can't double-emit. The combat-trace line is emitted INSIDE that
	# same guard, so it inherits the one-shot semantics. This pins the contract.
	var p: Player = _make_player_in_tree()
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	# Second hit on a dead player — short-circuited by `_is_dead` in take_damage.
	p.take_damage(999, Vector2.ZERO, null)
	# Force a second `_die` call directly — also short-circuited by `_is_dead`.
	p._die()
	var die_count: int = 0
	for c: Array in spy.calls:
		if c[0] == "Player._die":
			die_count += 1
	_restore_debug_flags(spy)
	assert_eq(die_count, 1,
		"Player._die [combat-trace] must emit exactly once per life — same " +
		"one-shot semantics as the player_died signal it pairs with")


# ---- 3: trace fires BEFORE player_died.emit --------------------------

func test_player_die_trace_precedes_player_died_signal() -> void:
	# Trace ordering matters: the `[combat-trace] Player._die` line must hit the
	# log BEFORE `player_died` listeners run. If a listener (Main._on_player_died
	# → call_deferred("apply_death_rule")) runs first and that handler also
	# emits a trace, an investigator scanning chronologically would see the
	# respawn line ahead of the death line. Asserting the order keeps the
	# trace stream causally readable.
	var p: Player = _make_player_in_tree()
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	# Listener that records the call order (relative to spy.calls.size()).
	var listener_die_index: Array[int] = [-1]
	p.player_died.connect(func(_pos: Vector2) -> void:
		listener_die_index[0] = spy.calls.size()
	)
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	# By the time the listener fired, the trace must already be in spy.calls.
	# (spy.calls.size() at the listener-call moment == 1 means: exactly one
	# call had landed before the signal listener — that call was Player._die.)
	var trace_idx: int = -1
	for i in range(spy.calls.size()):
		if (spy.calls[i] as Array)[0] == "Player._die":
			trace_idx = i
			break
	_restore_debug_flags(spy)
	assert_ne(trace_idx, -1, "Player._die trace was emitted")
	assert_lt(trace_idx, listener_die_index[0],
		"Player._die [combat-trace] line must precede player_died signal " +
		"emission — chronological trace readers expect cause before effect")

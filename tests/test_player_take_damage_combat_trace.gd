extends GutTest
## Pair test for the `[combat-trace] Player.take_damage` HP curve trace
## (ticket 86c9uf1x8, Drew, 2026-05-16 Room 05 investigation).
##
## **Why this trace line is load-bearing.** The Player._die / apply_death_rule
## diagnostic pair landed in ticket 86c9u397c (PR #198) was sufficient to
## answer "did the Player die?" — but not "WHEN was the lethal hit, what
## cluster of hits drove the HP to zero, which mob class was the lethal
## source?". Without the HP-curve trace, a release-build trace stream of a
## Room 05 death looks like:
##
##   [combat-trace] Player.pos | pos=(174,200) state=idle  (×30)
##   [combat-trace] Player.swing_wedge | spawned ...        (×N)
##   [combat-trace] Charger.take_damage | amount=6 ...      (×M)
##   [combat-trace] Player._die | hp=0 pos=(174,200) — ...  (×1)
##
## — the Player went from "alive doing things" to "dead at hp=0" with no
## intermediate signal. Investigators can't distinguish "one big lethal
## charge" from "steady chip damage over 8 cycles" from "an unbroken
## cluster of 3 hits past iframes" — and the fix shape for each is
## different (cornered-flee, harness-retreat, or game-side iframe extend).
##
## With this trace, every damage tick emits an explicit HP delta line,
## mirroring the mob `<Mob>.take_damage | amount=N hp=before->after` shape.
## A release-build trace stream can now be grep'd directly for the lethal
## hit's predecessor (`hp=12->6`, `hp=6->0`) and post-mortem reconstructs
## the damage curve unambiguously. Mirrors the Charger.take_damage trace
## shape (combat-architecture.md § "[combat-trace] diagnostic shim") so the
## harness post-mortem regex set treats Player and mob hits symmetrically.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- CombatTraceSpy infra (mirrors test_player_die_combat_trace.gd) ----

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
	func count_tag(tag: String) -> int:
		var n: int = 0
		for c: Array in calls:
			if c[0] == tag:
				n += 1
		return n
	func msgs_for(tag: String) -> Array[String]:
		var out: Array[String] = []
		for c: Array in calls:
			if c[0] == tag:
				out.append(c[1])
		return out


func _install_combat_trace_spy() -> CombatTraceSpy:
	var root: Node = get_tree().root
	var real: Node = root.get_node_or_null("DebugFlags")
	assert_not_null(real, "DebugFlags autoload must exist to swap for the spy")
	real.name = "DebugFlags__real_parked_takedmgpair"
	var spy: CombatTraceSpy = CombatTraceSpy.new()
	spy.name = "DebugFlags"
	root.add_child(spy)
	return spy


func _restore_debug_flags(spy: CombatTraceSpy) -> void:
	var root: Node = get_tree().root
	root.remove_child(spy)
	spy.free()
	var parked: Node = root.get_node_or_null("DebugFlags__real_parked_takedmgpair")
	if parked != null:
		parked.name = "DebugFlags"


func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# ---- 1: Player.take_damage emits the HP curve trace -------------------

func test_player_take_damage_emits_combat_trace_with_hp_curve() -> void:
	# A non-lethal hit must emit a `[combat-trace] Player.take_damage` line
	# with the HP-curve payload (`amount=N hp=before->after`). Without it,
	# post-mortem analysis of a release-build Room 05 death has no signal
	# for the damage curve — only the lethal moment is traced.
	var p: Player = _make_player_in_tree()
	p.global_position = Vector2(174, 200)  # Sponsor's empirical death position
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(4, Vector2.ZERO, null)  # Charger base damage = 4
	var emitted: bool = spy.has_tag("Player.take_damage")
	var msgs: Array[String] = spy.msgs_for("Player.take_damage")
	_restore_debug_flags(spy)
	assert_true(emitted,
		"DIAG-86c9uf1x8: Player.take_damage must emit a [combat-trace] line " +
		"on every non-lethal hit. Without it, post-mortem of a Room 05 multi-" +
		"chaser death cannot reconstruct the HP curve and the fix-shape " +
		"decision (harness retreat vs. game-side iframe extend vs. balance " +
		"tweak) is blind.")
	assert_eq(msgs.size(), 1, "Exactly one trace line per damage tick")
	var msg: String = msgs[0]
	assert_string_contains(msg, "amount=4",
		"Payload must carry the post-clean damage amount so the trace " +
		"correlates with mob-side damage values")
	assert_string_contains(msg, "hp=100->96",
		"Payload must carry the HP curve (before->after) so the post-mortem " +
		"can reconstruct exactly when each hit landed and by how much")
	assert_string_contains(msg, "pos=(174,200)",
		"Payload must carry the player position at hit time so the trace " +
		"correlates with room geometry (Sponsor's empirical Room 05 death " +
		"position is (174,200) — 66px west of DEFAULT_PLAYER_SPAWN)")


# ---- 2: invulnerable-skip does NOT emit a trace -----------------------

func test_player_take_damage_does_not_trace_when_invulnerable() -> void:
	# When the player is in i-frames (dodge or post-hit-iframes), take_damage
	# returns early before mutating HP. The trace must NOT fire in that path —
	# otherwise an iframe-blocked hit would appear in the curve and inflate
	# the apparent damage rate. (Mirrors the existing `_is_dead` guard's
	# silent return.)
	var p: Player = _make_player_in_tree()
	# Force iframes on via the public dodge path.
	p.try_dodge(Vector2.RIGHT)
	assert_true(p.is_invulnerable(),
		"Precondition: dodge must enter iframes")
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(10, Vector2.ZERO, null)
	var emitted: bool = spy.has_tag("Player.take_damage")
	_restore_debug_flags(spy)
	assert_false(emitted,
		"Player.take_damage trace must NOT fire while invulnerable — an " +
		"iframe-blocked hit produced no HP change, so emitting a curve " +
		"line would inflate the apparent damage rate in post-mortem")
	assert_eq(p.hp_current, p.hp_max,
		"HP must remain unchanged when invulnerable — guard precondition")


# ---- 3: dead-state-skip does NOT emit a trace --------------------------

func test_player_take_damage_does_not_trace_when_dead() -> void:
	# Once the player is dead, subsequent take_damage calls early-return
	# before mutating HP. The trace must NOT fire — a corpse can't take
	# damage, and an emission here would muddy the lethal-hit identification.
	var p: Player = _make_player_in_tree()
	# Kill the player.
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	assert_true(p.is_dead(),
		"Precondition: lethal hit puts player in dead state")
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(10, Vector2.ZERO, null)
	var emitted: bool = spy.has_tag("Player.take_damage")
	_restore_debug_flags(spy)
	assert_false(emitted,
		"Player.take_damage trace must NOT fire on a dead player — the " +
		"_is_dead guard rejects the hit before HP mutation, and a trace " +
		"line would mislead post-mortem analysis")


# ---- 4: lethal hit traces BEFORE Player._die ---------------------------

func test_player_take_damage_trace_precedes_player_die_trace() -> void:
	# Ordering matters: on a lethal hit, the HP-curve trace must hit the log
	# BEFORE the Player._die trace. A reader scanning chronologically
	# expects "hp=N->0" first, then "Player._die | hp=0 pos=...". Otherwise
	# the lethal damage amount is invisible at the death-line moment.
	var p: Player = _make_player_in_tree()
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	var take_dmg_idx: int = -1
	var die_idx: int = -1
	for i in range(spy.calls.size()):
		var tag: String = (spy.calls[i] as Array)[0]
		if tag == "Player.take_damage" and take_dmg_idx == -1:
			take_dmg_idx = i
		elif tag == "Player._die" and die_idx == -1:
			die_idx = i
	_restore_debug_flags(spy)
	assert_ne(take_dmg_idx, -1, "Player.take_damage trace must fire on lethal hit")
	assert_ne(die_idx, -1, "Player._die trace must fire on lethal hit")
	assert_lt(take_dmg_idx, die_idx,
		"Player.take_damage trace must precede Player._die trace — a " +
		"chronological reader sees 'amount=N hp=N->0' before 'Player._die', " +
		"so the lethal damage amount is visible at the death-line moment")


# ---- 5: source name is carried in the payload --------------------------

func test_player_take_damage_trace_carries_source_name() -> void:
	# The source node's name (Charger / Grunt / etc.) is the load-bearing
	# attribution signal for "which mob killed the player". Without it, a
	# post-mortem of a Room 05 death can't tell a Charger heavy charge from
	# a Grunt melee chip — and the fix shape depends on which (Charger's
	# 280 knockback drives positional drift; Grunt's 60-speed crowd doesn't).
	var p: Player = _make_player_in_tree()
	var src: Node = Node.new()
	src.name = "CharlieTheCharger"
	add_child_autofree(src)
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(4, Vector2.ZERO, src)
	var msg: String = spy.msgs_for("Player.take_damage")[0]
	_restore_debug_flags(spy)
	assert_string_contains(msg, "src=CharlieTheCharger",
		"Payload must carry the source node's name so the post-mortem can " +
		"attribute each hit to a specific mob class (Charger vs. Grunt — " +
		"different fix shapes for each)")


# ---- 6: null-source case doesn't crash ---------------------------------

func test_player_take_damage_trace_handles_null_source() -> void:
	# Some `take_damage` call sites pass `null` for source (test paths,
	# scripted damage). The trace must handle this without crashing —
	# fall back to a sentinel like "Unknown" so the trace line is still
	# emitted (the HP curve is still load-bearing) but with no source tag.
	var p: Player = _make_player_in_tree()
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	p.take_damage(4, Vector2.ZERO, null)
	var emitted: bool = spy.has_tag("Player.take_damage")
	var msg: String = spy.msgs_for("Player.take_damage")[0]
	_restore_debug_flags(spy)
	assert_true(emitted,
		"Trace must fire even when source is null — the HP curve is " +
		"the load-bearing signal, source is metadata")
	assert_string_contains(msg, "src=",
		"Payload must still include a src= tag (e.g. 'src=Unknown') so " +
		"the field count is uniform across all damage events — a missing " +
		"field would break greppable parsing")

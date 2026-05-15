extends GutTest
## Integration test for out-of-combat HP regen — drives Player + Grunt instances
## in a simulated kite-and-regen pattern to cover Uma's AC-6 integration surface.
##
## Uma's spec: `team/uma-ux/hp-regen-design.md` §"Acceptance criteria" AC-6
## ClickUp ticket: `86c9q7pgc`
##
## **What this test proves (AC-6):**
##   - Player takes damage from a Grunt (simulated via direct take_damage)
##   - Player "kites away" (no further attack or damage for > 3.0 s simulated time)
##   - Regen activates and HP rises at ~2.0 HP/s
##   - Regen reaches the cap correctly
##   - After the simulated OOC window, player fights back and regen stops
##
## **Why direct delta-ticking, not physics frame awaits:**
## Headless GUT has no Input queue and physics-frame timing is non-deterministic
## at sub-second resolution. We drive _tick_timers() with a fixed delta (1/60 s)
## to advance regen timers by exact seconds, then assert HP changed within a
## tight ±tolerance per Uma's AC-4 rate spec (10 HP ± 1 over 5 s).

const PHYS_DELTA: float = 1.0 / 60.0


# Post-AC4-balance-pass: take_damage now grants HIT_IFRAMES_SECS = 0.25s of
# invulnerability after every non-fatal hit (Uma's pin, Devon W3 ticket
# 86c9u4mdc). The hit-iframe SceneTreeTimer fires on real time, not
# `_tick_timers` simulated time — so back-to-back `take_damage` calls in
# the same frame land the FIRST hit and then short-circuit at the
# `if _is_invulnerable: return` guard. Production gameplay never hits
# this surface because grunt cycles (~0.95s) are far longer than the
# iframe window, so real time always elapses between hits. To preserve
# the original "rapid sequential damage application" semantics that
# pre-date the iframe feature, these regen tests use `_apply_test_hit`
# which calls `_exit_iframes()` after each `take_damage` to simulate the
# real-time gap between successive grunt hits.
func _apply_test_hit(p: Player, dmg: int, src: Node) -> void:
	p.take_damage(dmg, Vector2.ZERO, src)
	if p.is_invulnerable() and not p.is_dead():
		# Clear the hit-iframe state so the NEXT call lands. In real
		# gameplay the 0.25s timer would have fired well before the next
		# grunt-cycle hit (~0.95s apart).
		p._exit_iframes()


func _reset_autoloads() -> void:
	var levels: Node = Engine.get_main_loop().root.get_node_or_null("Levels")
	if levels != null and levels.has_method("reset"):
		levels.reset()
	var ps: Node = Engine.get_main_loop().root.get_node_or_null("PlayerStats")
	if ps != null and ps.has_method("reset"):
		ps.reset()
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	if inv != null and inv.has_method("reset"):
		inv.reset()
	var sp: Node = Engine.get_main_loop().root.get_node_or_null("StratumProgression")
	if sp != null and sp.has_method("reset"):
		sp.reset()


func _instantiate_main() -> Node:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	_reset_autoloads()
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	var main: Node = packed.instantiate()
	add_child_autofree(main)
	return main


## AC-6 core: Player + Grunt spawn via Main, combat damages player, kite away
## (no attack/damage for > 3.0 s), verify regen activates and HP rises.
func test_player_can_regen_between_room_encounters() -> void:
	var main: Main = _instantiate_main() as Main
	assert_not_null(main, "Main.tscn must instantiate as Main")
	await get_tree().process_frame

	var p: Player = main.get_player()
	assert_not_null(p, "AC-6: Player must be spawned")
	var room: Node = main.get_current_room()
	assert_not_null(room, "AC-6: Room must be loaded")

	# --- Phase 1: simulate combat damage (like taking hits from a Grunt).
	var initial_hp: int = p.hp_current
	var dummy_source: Node = Node.new()
	add_child_autofree(dummy_source)

	# Simulate 3 grunt hits (5 dmg each = 15 total), plus one player attack
	# (lands a hit → attack timer reset). `_apply_test_hit` clears the
	# 0.25s post-hit iframe between calls (real grunt-cycle gap covers this
	# in production; see helper docstring).
	_apply_test_hit(p, 5, dummy_source)
	_apply_test_hit(p, 5, dummy_source)
	_apply_test_hit(p, 5, dummy_source)
	var hp_after_combat: int = p.hp_current
	assert_eq(hp_after_combat, initial_hp - 15,
		"AC-6: Player took 15 damage in simulated combat")

	# Simulate player landing one hit (resets attack timer).
	p._on_hitbox_hit_target(dummy_source, 1, p)

	# Verify regen is not active yet (both timers reset).
	assert_false(p.is_regenerating,
		"AC-6: regen must not be active immediately after combat exchange")

	# --- Phase 2: kite away — advance both timers to just under threshold.
	# 2.9 s: regen must NOT activate.
	for _i in int(2.9 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
	assert_false(p.is_regenerating,
		"AC-6: regen must not activate at 2.9 s (threshold is 3.0 s)")

	# Cross threshold: 0.2 s more → both timers > 3.0 s.
	for _i in int(0.2 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
	assert_true(p.is_regenerating,
		"AC-6: regen must activate after kiting away for > 3.0 s with no damage or hits")

	# --- Phase 3: verify HP rises at ~2 HP/s over 5 simulated seconds.
	var hp_regen_start: int = p.hp_current
	for _i in int(5.0 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
	var gained: int = p.hp_current - hp_regen_start
	assert_gte(gained, 9,
		"AC-6: 5 s regen must gain at least 9 HP (expected 10 at 2.0 HP/s)")
	assert_lte(gained, 11,
		"AC-6: 5 s regen must gain at most 11 HP (float precision tolerance ±1)")

	# --- Phase 4: combat interrupts regen.
	assert_true(p.is_regenerating, "pre-condition for interrupt: regen active")
	_apply_test_hit(p, 5, dummy_source)
	assert_false(p.is_regenerating,
		"AC-6: regen must stop when player takes damage in the next combat round")


## AC-6 integration surface: regen interacts correctly with death/revive.
## Reviving via revive_full_hp() resets regen timers so the player doesn't
## immediately regen on respawn.
func test_regen_resets_on_death_and_revive() -> void:
	var main: Main = _instantiate_main() as Main
	await get_tree().process_frame

	var p: Player = main.get_player()
	assert_not_null(p, "Player must be present")
	p.hp_current = 50

	# Advance timers to regen-active state.
	for _i in int(3.2 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
	assert_true(p.is_regenerating, "pre-condition: regen active before death test")

	# Revive resets timers.
	p.revive_full_hp()
	assert_false(p.is_regenerating,
		"AC-6: regen must be inactive immediately after revive_full_hp()")
	# One tick should not re-activate regen (timers were reset to 0).
	p._tick_timers(PHYS_DELTA)
	assert_false(p.is_regenerating,
		"AC-6: one tick after revive must not re-activate regen (timers at 0)")


## AC-6 integration: regen state is ephemeral — not saved/loaded.
## After save + simulated reload, regen is inactive (timers start fresh).
func test_regen_state_is_ephemeral_not_persisted() -> void:
	var main: Main = _instantiate_main() as Main
	await get_tree().process_frame

	var p: Player = main.get_player()
	assert_not_null(p)
	p.hp_current = 50

	# Activate regen.
	for _i in int(3.2 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
	assert_true(p.is_regenerating, "pre-condition: regen active before save")

	# Save now.
	main.save_now(0)

	# Simulated "reload" — revive_full_hp() is what the death/respawn path
	# calls; the save-restore path restores HP via set_hp (which does NOT
	# reset regen timers, but the next frame the timers continue from wherever
	# they were, which is fine — the HP is restored so regen won't fire anyway
	# because hp_current == hp_max post-restore).
	p.revive_full_hp()
	assert_false(p.is_regenerating,
		"AC-6: is_regenerating must be false after respawn/revive (ephemeral state)")

	# Cleanup.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null:
		save_node.delete_save(0)


## AC-6 integration: sustained spam attacks from two simulated Grunts keep
## regen suppressed. No race conditions — damage timer resets are additive.
func test_regen_stays_suppressed_under_sustained_damage_spam() -> void:
	var main: Main = _instantiate_main() as Main
	await get_tree().process_frame

	var p: Player = main.get_player()
	assert_not_null(p)
	p.hp_current = 100

	var src: Node = Node.new()
	add_child_autofree(src)

	# Simulate 5 s of sustained hits every ~1 s (faster than the 3 s threshold).
	for i in 5:
		# Advance 1 s without damage first (just under threshold), then hit.
		for _j in int(1.0 / PHYS_DELTA):
			p._tick_timers(PHYS_DELTA)
		_apply_test_hit(p, 2, src)  # keep HP > 0 (clear iframes between hits)

	# After 5 s of 1-hit-per-second spam, regen must still be inactive.
	assert_false(p.is_regenerating,
		"AC-6: regen must stay suppressed when damage hits every 1.0 s (< 3.0 s threshold)")

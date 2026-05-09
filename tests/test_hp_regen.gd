extends GutTest
## Paired Tier 1 tests for out-of-combat HP regen — covers AC-1 through AC-5
## and AC-7 (visual-primitive shimmer invariant).
##
## Uma's spec: `team/uma-ux/hp-regen-design.md`
## ClickUp ticket: `86c9q7pgc`
##
## **Testing strategy:**
## We drive Player._tick_timers() directly rather than awaiting wall-clock time.
## This advances the regen timers by an exact `delta` without waiting for
## physics frames, giving deterministic assertions independent of headless GUT
## scheduler jitter.
##
## The shimmer test (AC-7) drives Main.tscn programmatically so the HUD is
## live and the regen_active_changed signal is wired.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")

const PHYS_DELTA: float = 1.0 / 60.0

# Helpers ------------------------------------------------------------------

func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


## Advance both regen timers past their thresholds by ticking the full
## physics-process loop `n_ticks` times with a given delta. This simulates
## "standing idle for (n_ticks * delta) seconds."
func _tick_idle(p: Player, delta: float, ticks: int) -> void:
	for _i in ticks:
		p._tick_timers(delta)


## Pre-satisfy both regen timers by advancing them just over 3.0 s.
## Shortcut to put the player in the "regen-eligible" state without calling
## take_damage or try_attack.
func _pre_satisfy_regen_timers(p: Player) -> void:
	# 3.1 s > 3.0 s threshold for both timers.
	_tick_idle(p, PHYS_DELTA, int(3.2 / PHYS_DELTA))


# ---- AC-1: regen activates after 3 s of no damage + no hits -----------

func test_regen_activates_after_3s_of_no_damage_no_hit() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_current = 50  # not at max so regen can fire
	assert_false(p.is_regenerating, "regen must be inactive at spawn")

	# Advance both timers to just under the threshold — regen must NOT activate.
	_tick_idle(p, PHYS_DELTA, int(2.9 / PHYS_DELTA))
	assert_false(p.is_regenerating,
		"AC-1: regen must NOT activate before 3.0 s threshold")

	# Cross thresholds + run long enough for the carry accumulator to credit
	# at least one HP tick. At 2.0 HP/s with PHYS_DELTA = 1/60, the integer
	# part of `gained = REGEN_RATE_HP_PER_SEC * delta` is 0 every frame, so the
	# carry accumulator must accumulate >= 1.0 before HP rises. That takes
	# ~30 ticks (0.5 s). Use 0.7 s to give headroom for the assertion (Tess CR
	# feedback bug 2 — original 0.3 s window was below the 0.5 s carry threshold).
	_tick_idle(p, PHYS_DELTA, int(0.7 / PHYS_DELTA))
	assert_true(p.is_regenerating,
		"AC-1: regen must activate after both timers exceed 3.0 s")
	assert_gt(p.hp_current, 50,
		"AC-1: hp_current must increase after regen activates")


# ---- AC-2 (damage): regen stops immediately on damage taken -----------

func test_regen_stops_immediately_on_damage_taken() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_current = 50

	# Satisfy timers → regen active.
	_pre_satisfy_regen_timers(p)
	assert_true(p.is_regenerating, "pre-condition: regen active")

	# Take damage — regen must stop and damage timer resets.
	var dummy_source: Node = Node.new()
	add_child_autofree(dummy_source)
	p.take_damage(5, Vector2.ZERO, dummy_source)
	assert_false(p.is_regenerating,
		"AC-2: regen must stop immediately on damage taken")
	# HP must NOT increase on the next tick (regen is off).
	var hp_after_damage: int = p.hp_current
	_tick_idle(p, PHYS_DELTA, 1)
	assert_eq(p.hp_current, hp_after_damage,
		"AC-2: HP must not increase the tick after damage (regen stopped)")
	# Timer-restart assertion: simulating 2.9 s more without damage must NOT
	# resume regen (damage timer was reset to 0 on take_damage).
	_tick_idle(p, PHYS_DELTA, int(2.9 / PHYS_DELTA))
	assert_false(p.is_regenerating,
		"AC-2: regen must not resume at 2.9 s after damage (timer reset, threshold is 3.0 s)")


# ---- AC-2 (hit-landed): regen stops immediately on hit landed ----------

func test_regen_stops_immediately_on_hit_landed() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_current = 50

	# Satisfy timers → regen active.
	_pre_satisfy_regen_timers(p)
	assert_true(p.is_regenerating, "pre-condition: regen active before hit-landed")

	# Simulate a player hitbox landing a hit — call _on_hitbox_hit_target
	# directly (the same path _spawn_hitbox connects to hit_target signal).
	p._on_hitbox_hit_target(Node.new(), 1, p)
	assert_false(p.is_regenerating,
		"AC-2 (hit-landed): regen must stop immediately when player lands a hit")
	# Timer-restart assertion: 2.9 s more must NOT resume regen (attack timer reset).
	_tick_idle(p, PHYS_DELTA, int(2.9 / PHYS_DELTA))
	assert_false(p.is_regenerating,
		"AC-2 (hit-landed): regen must not resume at 2.9 s after hit (timer reset)")


# ---- AC-3 (Uma AC-4): regen rate is exactly REGEN_RATE_HP_PER_SEC -----

func test_regen_rate_is_2_hp_per_sec() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_current = 50
	p.hp_max = 100

	# Pre-satisfy timers.
	_pre_satisfy_regen_timers(p)
	assert_true(p.is_regenerating, "pre-condition: regen active for rate test")

	var hp_at_regen_start: int = p.hp_current
	# Simulate exactly 5 seconds of regen ticks.
	_tick_idle(p, PHYS_DELTA, int(5.0 / PHYS_DELTA))

	# Expected gain: 5 * 2.0 = 10 HP. Float accumulation across frames
	# means we allow ±1 HP per Uma's AC-4 precision tolerance.
	var gained: int = p.hp_current - hp_at_regen_start
	assert_gte(gained, 9,
		"AC-3: 5 s regen must gain at least 9 HP (expected 10 at 2.0 HP/s)")
	assert_lte(gained, 11,
		"AC-3: 5 s regen must gain at most 11 HP (float precision tolerance ±1)")


# ---- AC-4 (Uma AC-5): regen caps at HP_MAX; no overheal ---------------

func test_regen_caps_at_hp_max_no_overheal() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_max = 100
	p.hp_current = 99  # one HP below max

	# Pre-satisfy timers.
	_pre_satisfy_regen_timers(p)
	assert_true(p.is_regenerating, "pre-condition: regen active for cap test")

	# Simulate 5 s — more than enough to regen that 1 HP and then some.
	var exceeded_max: bool = false
	for _i in int(5.0 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
		if p.hp_current > p.hp_max:
			exceeded_max = true

	assert_false(exceeded_max,
		"AC-4: hp_current must NEVER exceed hp_max at any intermediate tick")
	assert_eq(p.hp_current, p.hp_max,
		"AC-4: hp_current must equal hp_max after sustained regen past cap")
	# Regen should be inactive once hp == hp_max.
	assert_false(p.is_regenerating,
		"AC-4: is_regenerating must be false when hp_current == hp_max")


# ---- AC-5: regen_active_changed signal fires on transitions -----------

func test_regen_active_changed_signal_fires_on_activation() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_current = 50
	watch_signals(p)

	_pre_satisfy_regen_timers(p)
	assert_true(p.is_regenerating, "regen activated")
	assert_signal_emitted_with_parameters(p, "regen_active_changed", [true],
		"AC-5: regen_active_changed(true) must fire on activation")


func test_regen_active_changed_signal_fires_on_damage_interrupt() -> void:
	var p: Player = _make_player_in_tree()
	p.hp_current = 50
	_pre_satisfy_regen_timers(p)
	assert_true(p.is_regenerating, "pre-condition: regen active")

	watch_signals(p)
	var src: Node = Node.new()
	add_child_autofree(src)
	p.take_damage(5, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(p, "regen_active_changed", [false],
		"AC-5: regen_active_changed(false) must fire when damage interrupts regen")


func test_regen_not_active_at_full_hp() -> void:
	# Regen should never activate when already at full HP.
	var p: Player = _make_player_in_tree()
	p.hp_current = p.hp_max  # already full
	_pre_satisfy_regen_timers(p)
	assert_false(p.is_regenerating,
		"regen must not activate when hp_current == hp_max")


# ---- AC-7: visual-primitive test — shimmer ColorRect modulate != rest --
# Drives Main.tscn so the HUD is live and the regen_active_changed signal
# is wired to the HpBarShimmer node. Asserts observable modulate delta.

func _instantiate_main() -> Node:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	var main: Node = packed.instantiate()
	add_child_autofree(main)
	return main


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


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


## AC-7 (Tier 1 visual-primitive invariant): shimmer modulate must differ from
## rest when regen is active. `target_color != Color(1,1,1,0)` is the
## load-bearing assertion — a tween that does nothing (or tweens to the same
## value) fails here.
##
## Tier 2 (visible-draw node): asserts the modulate is on HpBarShimmer
## (the ColorRect), NOT on the parent vitals Control or the HUD CanvasLayer.
## Cascade lesson: modulate(1,1,1,X) * child_modulate is only observable if the
## ColorRect itself is the tween target.
func test_regen_shimmer_colorect_modulate_differs_from_rest_when_regen_active() -> void:
	var main: Main = _instantiate_main() as Main
	assert_not_null(main, "Main.tscn must instantiate as Main")
	await get_tree().process_frame

	var shimmer: ColorRect = main.get_hp_bar_shimmer()
	assert_not_null(shimmer,
		"AC-7 Tier 2: HpBarShimmer ColorRect must be accessible via Main.get_hp_bar_shimmer()")
	assert_true(shimmer is ColorRect,
		"AC-7 Tier 2: shimmer node must be a ColorRect (not Polygon2D or parent node)")

	# Rest state: shimmer must be fully transparent (alpha = 0) at boot.
	var rest_modulate: Color = shimmer.modulate
	assert_almost_eq(rest_modulate.a, 0.0, 0.01,
		"AC-7: HpBarShimmer modulate.a must be 0.0 at rest (fully transparent)")

	# Activate regen: set HP below max, advance both regen timers past threshold.
	var p: Player = main.get_player()
	assert_not_null(p, "AC-7: player must be accessible")
	p.hp_current = 50
	# Advance regen timers by calling _tick_timers directly — avoids physics_frame
	# dependency that would race the signal handler.
	for _i in int(3.2 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)

	# Wait a frame for the signal handler to run and start the tween.
	await get_tree().process_frame

	# Tier 1 invariant: shimmer modulate must differ from rest (alpha 0).
	# The tween was started — after one process_frame the first property step
	# should have made alpha > 0.
	assert_true(shimmer.modulate.a > 0.0,
		"AC-7 Tier 1: HpBarShimmer modulate.a must be > 0.0 when regen is active (shimmer visible)")
	assert_ne(shimmer.modulate, Color(1.0, 1.0, 1.0, 0.0),
		"AC-7 Tier 1: target_modulate != rest_modulate — shimmer must produce observable delta")
	assert_true(main.get_player().is_regenerating,
		"AC-7: is_regenerating must be true when both timers exceeded")


func test_regen_shimmer_returns_to_rest_on_damage() -> void:
	var main: Main = _instantiate_main() as Main
	await get_tree().process_frame

	var shimmer: ColorRect = main.get_hp_bar_shimmer()
	assert_not_null(shimmer)
	var p: Player = main.get_player()
	p.hp_current = 50

	# Activate regen.
	for _i in int(3.2 / PHYS_DELTA):
		p._tick_timers(PHYS_DELTA)
	await get_tree().process_frame
	assert_true(p.is_regenerating, "pre-condition: regen active for shimmer-off test")

	# Take damage → regen_active_changed(false) → shimmer snaps to rest.
	var src: Node = Node.new()
	add_child_autofree(src)
	p.take_damage(5, Vector2.ZERO, src)
	await get_tree().process_frame

	assert_false(p.is_regenerating, "regen must stop after damage")
	assert_almost_eq(shimmer.modulate.a, 0.0, 0.01,
		"AC-7: shimmer modulate.a must snap to 0.0 when regen deactivates")

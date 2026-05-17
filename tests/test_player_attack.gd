extends GutTest
## Tests for Player.try_attack() — light/heavy attack hitbox spawning,
## state transitions, recovery timing, and dodge-cancels-recovery.
##
## These tests share their gut tree with the hitbox child being added,
## so we autofree the player node to keep test isolation clean.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")


func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	# add_child_autofree triggers _ready automatically.
	return p


# --- 1: light attack spawns hitbox with light tuning ----------------------

func test_light_attack_spawns_hitbox_with_correct_payload() -> void:
	var p: Player = _make_player_in_tree()
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_not_null(hb, "light attack must spawn a hitbox")
	# Bare-instantiated player (no equipped weapon) -> fist damage = 1.
	# Validated separately in test_damage.gd; this assertion ties the wiring
	# (hitbox.damage = formula output) without re-asserting formula constants.
	assert_eq(hb.damage, DamageScript.FIST_DAMAGE, "no weapon -> fist damage 1")
	assert_eq(hb.lifetime, Player.LIGHT_HITBOX_LIFETIME, "light lifetime 0.10")
	assert_eq(hb.team, Hitbox.TEAM_PLAYER, "player attacks belong to player team")
	# Hitbox parented to player so it follows our position.
	assert_eq(hb.get_parent(), p, "hitbox parented to player")


# --- 2: heavy attack uses heavy tuning ------------------------------------

func test_heavy_attack_uses_heavy_tuning() -> void:
	var p: Player = _make_player_in_tree()
	var hb: Hitbox = p.try_attack(Player.ATTACK_HEAVY, Vector2.UP)
	# Bare player + no weapon -> fist (heavy multiplier doesn't apply to
	# fist per Damage.compute_player_damage spec — fist is flat 1).
	assert_eq(hb.damage, DamageScript.FIST_DAMAGE, "no weapon -> fist damage 1 (heavy still flat)")
	assert_eq(hb.lifetime, Player.HEAVY_HITBOX_LIFETIME, "heavy lifetime 0.14")


# --- 3: hitbox positioned at player + facing*reach ------------------------

func test_hitbox_position_uses_facing_reach() -> void:
	var p: Player = _make_player_in_tree()
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	# Local position = facing * reach
	assert_almost_eq(hb.position.x, Player.LIGHT_REACH, 0.001)
	assert_almost_eq(hb.position.y, 0.0, 0.001)


# --- 4: cannot attack mid-dodge -------------------------------------------

func test_attack_blocked_during_dodge() -> void:
	var p: Player = _make_player_in_tree()
	p.try_dodge(Vector2.RIGHT)
	assert_false(p.can_attack(), "can_attack false during dodge")
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_null(hb, "attack during dodge must be rejected (returns null)")


# --- 5: attack recovery blocks immediate re-attack ------------------------

func test_attack_recovery_blocks_immediate_reattack() -> void:
	var p: Player = _make_player_in_tree()
	var first: Hitbox = p.try_attack(Player.ATTACK_HEAVY, Vector2.RIGHT)
	assert_not_null(first)
	# Immediately try another — should be blocked by recovery.
	var second: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_null(second, "follow-up attack during recovery must be rejected")
	# Tick past recovery.
	p._tick_timers(Player.HEAVY_RECOVERY + 0.01)
	assert_true(p.can_attack(), "after recovery elapses, can attack again")


# --- 6: state transitions to attack and back to idle ----------------------

func test_attack_transitions_to_attack_state_then_idle() -> void:
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_LIGHT, Vector2.DOWN)
	assert_eq(p.get_state(), Player.STATE_ATTACK)
	# Tick past recovery; _process_attack returns to idle.
	p._tick_timers(Player.LIGHT_RECOVERY + 0.01)
	p._process_attack(0.0)
	assert_eq(p.get_state(), Player.STATE_IDLE, "attack returns to idle after recovery")


# --- 7: dodge interrupts attack recovery (Hades convention) --------------

func test_dodge_cancels_attack_recovery() -> void:
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_HEAVY, Vector2.RIGHT)
	# Recovery is active; dodge must still succeed.
	assert_true(p.can_dodge(), "dodge can fire even during attack recovery")
	var ok: bool = p.try_dodge(Vector2.LEFT)
	assert_true(ok)
	assert_eq(p.get_state(), Player.STATE_DODGE)
	assert_eq(p._attack_recovery_left, 0.0, "dodge zeroed attack recovery so post-dodge feels clean")


# --- 8: unknown attack kind warns and returns null ------------------------

func test_unknown_attack_kind_returns_null() -> void:
	var p: Player = _make_player_in_tree()
	var hb: Hitbox = p.try_attack(&"poke")
	assert_null(hb, "unknown kind rejected")


# --- 9: attack_spawned signal carries kind and hitbox --------------------

func test_attack_spawned_signal() -> void:
	var p: Player = _make_player_in_tree()
	watch_signals(p)
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.UP)
	assert_signal_emitted_with_parameters(p, "attack_spawned", [Player.ATTACK_LIGHT, hb])


# --- 10: attack uses facing if dir omitted --------------------------------

func test_attack_uses_facing_when_dir_zero() -> void:
	var p: Player = _make_player_in_tree()
	# Set facing via dodge first to a known direction.
	p.try_dodge(Vector2.LEFT)
	p._tick_timers(Player.DODGE_DURATION + Player.DODGE_COOLDOWN + 0.01)
	p._process_dodge(0.0)
	# Now facing should be LEFT.
	assert_eq(p.get_facing(), Vector2.LEFT)
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.ZERO)
	# Hitbox at facing*reach -> -reach,0
	assert_almost_eq(hb.position.x, -Player.LIGHT_REACH, 0.001)


# --- 11: hitbox direction = mouse-derived facing (ticket 86c9uthf0) -------

func test_hitbox_direction_matches_mouse_derived_facing() -> void:
	# Sponsor 2026-05-17 AC1 + AC5: LMB melee swing direction must equal the
	# Player→mouse vector. The mouse-facing pipeline lives in
	# `_update_mouse_facing` (driven each `_physics_process` tick) — this test
	# drives the pure helper directly to set `_facing`, then fires a
	# Vector2.ZERO-dir attack (the shape that `_process_grounded` issues on
	# `attack_light` / `attack_heavy` press) and confirms the resulting
	# hitbox position is at `_facing * REACH`.
	var p: Player = _make_player_in_tree()
	# Simulate "mouse 100 px southeast of player at origin": _facing should
	# resolve to (1/sqrt(2), 1/sqrt(2)).
	p._facing = Player._resolve_facing_from_mouse(
		Vector2(100.0, 100.0), Vector2.ZERO, Vector2.UP
	)
	var expected_axis: float = 1.0 / sqrt(2.0)
	assert_almost_eq(p._facing.x, expected_axis, 0.001, "mouse-derived facing.x")
	assert_almost_eq(p._facing.y, expected_axis, 0.001, "mouse-derived facing.y")
	# Fire a light attack the SAME WAY _process_grounded does — Vector2.ZERO
	# dir so try_attack uses the mouse-derived _facing.
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.ZERO)
	assert_not_null(hb)
	# Hitbox position = facing * LIGHT_REACH.
	assert_almost_eq(hb.position.x, expected_axis * Player.LIGHT_REACH, 0.001,
		"hitbox.x matches mouse-derived facing.x * reach")
	assert_almost_eq(hb.position.y, expected_axis * Player.LIGHT_REACH, 0.001,
		"hitbox.y matches mouse-derived facing.y * reach")
	# Knockback is also facing-aligned (carried through _spawn_hitbox).
	assert_almost_eq(hb.knockback.x, expected_axis * Player.LIGHT_KNOCKBACK, 0.001,
		"knockback.x matches mouse-derived direction")
	assert_almost_eq(hb.knockback.y, expected_axis * Player.LIGHT_KNOCKBACK, 0.001,
		"knockback.y matches mouse-derived direction")


# --- 12: heavy attack also uses mouse-derived facing ----------------------

func test_heavy_hitbox_direction_matches_mouse_derived_facing() -> void:
	# AC2: same as AC1 but for RMB heavy. The mouse-direction wiring is
	# symmetric — both attack kinds route through `try_attack` and pick up
	# `_facing` when dir=ZERO is passed.
	var p: Player = _make_player_in_tree()
	# Mouse 80 px due west.
	p._facing = Player._resolve_facing_from_mouse(
		Vector2(-80.0, 0.0), Vector2.ZERO, Vector2.UP
	)
	assert_eq(p._facing, Vector2.LEFT, "mouse due west → facing LEFT")
	var hb: Hitbox = p.try_attack(Player.ATTACK_HEAVY, Vector2.ZERO)
	assert_almost_eq(hb.position.x, -Player.HEAVY_REACH, 0.001,
		"heavy hitbox at -HEAVY_REACH along facing")
	assert_almost_eq(hb.position.y, 0.0, 0.001)


# --- 13: facing snapshots at swing-spawn (mid-swing mouse changes ignored) -

func test_attack_facing_snapshot_does_not_drift_mid_swing() -> void:
	# Edge case 3 from the ticket: facing should snapshot at swing-spawn,
	# not continuously update during STATE_ATTACK. The `_update_mouse_facing`
	# gate on `_state == STATE_ATTACK` is what enforces this.
	var p: Player = _make_player_in_tree()
	p._facing = Vector2.RIGHT
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.ZERO)
	assert_eq(p.get_state(), Player.STATE_ATTACK, "in STATE_ATTACK post-swing")
	# Hitbox already snapshotted to RIGHT.
	assert_almost_eq(hb.position.x, Player.LIGHT_REACH, 0.001)
	# Pretend the mouse moves 90deg during recovery — call the per-frame
	# update with the player still in STATE_ATTACK.
	p._update_mouse_facing()
	# _facing must remain RIGHT (no overwrite during STATE_ATTACK).
	assert_eq(p._facing, Vector2.RIGHT,
		"mid-swing mouse-facing update is suppressed; swing direction snapshotted")

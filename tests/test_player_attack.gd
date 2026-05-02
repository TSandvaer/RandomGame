extends GutTest
## Tests for Player.try_attack() — light/heavy attack hitbox spawning,
## state transitions, recovery timing, and dodge-cancels-recovery.
##
## These tests share their gut tree with the hitbox child being added,
## so we autofree the player node to keep test isolation clean.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")


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
	assert_eq(hb.damage, Player.LIGHT_DAMAGE, "light damage 8")
	assert_eq(hb.lifetime, Player.LIGHT_HITBOX_LIFETIME, "light lifetime 0.10")
	assert_eq(hb.team, Hitbox.TEAM_PLAYER, "player attacks belong to player team")
	# Hitbox parented to player so it follows our position.
	assert_eq(hb.get_parent(), p, "hitbox parented to player")


# --- 2: heavy attack uses heavy tuning ------------------------------------

func test_heavy_attack_uses_heavy_tuning() -> void:
	var p: Player = _make_player_in_tree()
	var hb: Hitbox = p.try_attack(Player.ATTACK_HEAVY, Vector2.UP)
	assert_eq(hb.damage, Player.HEAVY_DAMAGE, "heavy damage 18")
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

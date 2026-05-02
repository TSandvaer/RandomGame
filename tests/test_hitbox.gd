extends GutTest
## Tests for the Hitbox Area2D damage payload + layer routing + i-frame
## passthrough. Combat correctness in M1 lives or dies on this code, so
## the test inventory is dense.
##
## Edge cases covered:
##   1. Player team gets player_hitbox layer, masks enemy.
##   2. Enemy team gets enemy_hitbox layer, masks player.
##   3. Self-hits are filtered (configure source = a node, hit that node = no-op).
##   4. Each target only takes damage once per hitbox lifetime.
##   5. take_damage forwards the configured damage + knockback + source.
##   6. configure() is callable before add_to_tree.

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")


# Minimal stand-in for an enemy that records take_damage calls.
class FakeTarget:
	extends Node2D
	var hits: Array[Dictionary] = []
	func take_damage(amount: int, kb: Vector2, source: Node) -> void:
		hits.append({"amount": amount, "knockback": kb, "source": source})


# --- 1 + 2: layer routing -------------------------------------------------

func test_player_team_layer_routing() -> void:
	var hb: Hitbox = HitboxScript.new()
	hb.configure(5, Vector2.ZERO, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	# Mask = enemy bit.
	assert_eq(hb.collision_layer, Hitbox.LAYER_PLAYER_HITBOX, "player team -> player_hitbox layer (bit 3)")
	assert_eq(hb.collision_mask, Hitbox.LAYER_ENEMY, "player team mask -> enemy (bit 4)")


func test_enemy_team_layer_routing() -> void:
	var hb: Hitbox = HitboxScript.new()
	hb.configure(5, Vector2.ZERO, 0.1, Hitbox.TEAM_ENEMY, null)
	add_child_autofree(hb)
	assert_eq(hb.collision_layer, Hitbox.LAYER_ENEMY_HITBOX, "enemy team -> enemy_hitbox layer (bit 5)")
	assert_eq(hb.collision_mask, Hitbox.LAYER_PLAYER, "enemy team mask -> player (bit 2)")


# --- 3: self-hit filtered -------------------------------------------------

func test_source_is_never_self_hit() -> void:
	var source: FakeTarget = FakeTarget.new()
	add_child_autofree(source)
	var hb: Hitbox = HitboxScript.new()
	hb.configure(7, Vector2.RIGHT, 0.1, Hitbox.TEAM_PLAYER, source)
	add_child_autofree(hb)
	# Simulate the body_entered signal landing on the source node.
	hb._try_apply_hit(source)
	assert_eq(source.hits.size(), 0, "hitbox must not damage its own source")


# --- 4: single-hit-per-target invariant -----------------------------------

func test_target_only_takes_damage_once() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var hb: Hitbox = HitboxScript.new()
	hb.configure(11, Vector2(3, 0), 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)

	hb._try_apply_hit(enemy)
	hb._try_apply_hit(enemy)
	hb._try_apply_hit(enemy)
	assert_eq(enemy.hits.size(), 1, "single-hit-per-target invariant — multiple overlap signals must collapse")
	assert_true(hb.has_already_hit(enemy), "has_already_hit returns true after first hit")


# --- 5: payload fidelity --------------------------------------------------

func test_take_damage_payload_round_trip() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var hb: Hitbox = HitboxScript.new()
	hb.configure(42, Vector2(99, -5), 0.1, Hitbox.TEAM_PLAYER, source)
	add_child_autofree(hb)

	hb._try_apply_hit(enemy)
	assert_eq(enemy.hits.size(), 1)
	assert_eq(enemy.hits[0]["amount"], 42)
	assert_eq(enemy.hits[0]["knockback"], Vector2(99, -5))
	assert_eq(enemy.hits[0]["source"], source)


# --- 6: configure callable pre-tree ---------------------------------------

func test_configure_before_add_child() -> void:
	# This is the same flow Player._spawn_hitbox uses: configure first,
	# then add_child. Asserts that _ready() picks up the configured
	# layer/mask correctly when the body_entered signal-wiring runs.
	var hb: Hitbox = HitboxScript.new()
	hb.configure(99, Vector2.ZERO, 0.05, Hitbox.TEAM_ENEMY, null)
	# Pre-tree: damage already set, but layer not yet applied (that's
	# done in _ready). Verify after add.
	add_child_autofree(hb)
	assert_eq(hb.damage, 99)
	assert_eq(hb.lifetime, 0.05)
	assert_eq(hb.collision_layer, Hitbox.LAYER_ENEMY_HITBOX)


# --- 7: hit_target signal carries target/damage/source -------------------

func test_hit_target_signal_carries_payload() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var hb: Hitbox = HitboxScript.new()
	hb.configure(7, Vector2.ZERO, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	watch_signals(hb)
	hb._try_apply_hit(enemy)
	assert_signal_emitted_with_parameters(hb, "hit_target", [enemy, 7, null])

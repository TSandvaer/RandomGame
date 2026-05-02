extends GutTest
## Tests for Projectile — paired with `scripts/projectiles/Projectile.gd`.
## Covers single-hit semantics, lifetime expiry (tests assert this so the
## scene can't fill with stale projectiles), and team-routed layer
## separation per Devon's physics-layer decision.
##
## Coverage:
##   1. Configure-then-add-child: damage/lifetime/team picked up by _ready.
##   2. Enemy team layer routing: layer = enemy_hitbox, mask = player + world.
##   3. Player team layer routing: layer = player_hitbox, mask = enemy + world.
##   4. Single-hit invariant: target only takes damage once even if signal
##      fires multiple times (mirrors Hitbox).
##   5. Self-source skip: source never hit by its own projectile.
##   6. Lifetime expiry: projectile queue_frees after `lifetime` seconds
##      and emits `expired` signal.
##   7. Hit also vanishes the projectile (single-hit, no pierce).
##   8. velocity_vec drives translation each physics tick (manual move).
##   9. Negative-direction config still applies — no normalization surprise.
##  10. EDGE: damage forwarded to take_damage including knockback derived
##      from velocity direction.

const ProjectileScript: Script = preload("res://scripts/projectiles/Projectile.gd")


# Minimal stand-in for an enemy that records take_damage calls.
class FakeTarget:
	extends Node2D
	var hits: Array[Dictionary] = []
	func take_damage(amount: int, kb: Vector2, source: Node) -> void:
		hits.append({"amount": amount, "knockback": kb, "source": source})


# ---- 1: configure-then-add-child --------------------------------------

func test_configure_before_add_child() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(11, Vector2(50.0, 0.0), 0.5, Projectile.TEAM_ENEMY, null, 100.0)
	add_child_autofree(p)
	assert_eq(p.damage, 11)
	assert_eq(p.lifetime, 0.5)
	assert_eq(p.team, Projectile.TEAM_ENEMY)
	assert_eq(p.knockback_strength, 100.0)
	# Layers applied during _ready.
	assert_eq(p.collision_layer, Projectile.LAYER_ENEMY_HITBOX, "enemy team -> enemy_hitbox layer (bit 5)")


# ---- 2: enemy team layer routing -----------------------------------

func test_enemy_team_layer_routing() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2.RIGHT * 50.0, 0.5, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	# Layer: enemy_hitbox.
	assert_eq(p.collision_layer, Projectile.LAYER_ENEMY_HITBOX)
	# Mask: player + world (so it vanishes on walls).
	assert_eq(p.collision_mask, Projectile.LAYER_PLAYER | Projectile.LAYER_WORLD)


# ---- 3: player team layer routing -----------------------------------

func test_player_team_layer_routing() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2.RIGHT * 50.0, 0.5, Projectile.TEAM_PLAYER, null)
	add_child_autofree(p)
	assert_eq(p.collision_layer, Projectile.LAYER_PLAYER_HITBOX)
	assert_eq(p.collision_mask, Projectile.LAYER_ENEMY | Projectile.LAYER_WORLD)


# ---- 4: single-hit invariant ---------------------------------------

func test_target_only_takes_damage_once() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var p: Projectile = ProjectileScript.new()
	p.configure(7, Vector2.RIGHT * 90.0, 1.0, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)

	p._try_apply_hit(enemy)
	# The first hit also expires the projectile (single-hit). Calling _try
	# again should be a no-op.
	p._try_apply_hit(enemy)
	p._try_apply_hit(enemy)
	assert_eq(enemy.hits.size(), 1, "single-hit-per-target invariant")


# ---- 5: source never self-hit -------------------------------------

func test_source_never_self_hit() -> void:
	var source: FakeTarget = FakeTarget.new()
	add_child_autofree(source)
	var p: Projectile = ProjectileScript.new()
	p.configure(9, Vector2.RIGHT * 90.0, 1.0, Projectile.TEAM_ENEMY, source)
	add_child_autofree(p)
	p._try_apply_hit(source)
	assert_eq(source.hits.size(), 0, "projectile must not damage its source")


# ---- 6: lifetime expiry --------------------------------------------

func test_lifetime_expiry_emits_signal_and_frees() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2.RIGHT * 50.0, 0.05, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	watch_signals(p)
	# Tick more than the lifetime.
	p._physics_process(0.06)
	assert_signal_emitted(p, "expired", "projectile expires when lifetime runs out")
	# After expire, queue_free is queued. The node won't be free-d until next
	# frame, but our state guard prevents repeat expiry.
	# A second tick after expiry should be a no-op.
	p._physics_process(0.5)
	assert_signal_emit_count(p, "expired", 1, "expired emitted exactly once")


# ---- 7: hit vanishes projectile (no pierce) ----------------------

func test_hit_vanishes_projectile() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var p: Projectile = ProjectileScript.new()
	p.configure(11, Vector2.RIGHT * 50.0, 1.0, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	watch_signals(p)
	p._try_apply_hit(enemy)
	assert_signal_emitted(p, "expired", "single-hit projectile expires on hit")
	# Subsequent _try_apply_hit calls should not damage another target.
	var enemy2: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy2)
	p._try_apply_hit(enemy2)
	assert_eq(enemy2.hits.size(), 0, "projectile cannot pierce a second target after expiry")


# ---- 8: velocity drives translation ------------------------

func test_velocity_drives_translation() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2(100.0, 0.0), 1.0, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	p.position = Vector2.ZERO
	p._physics_process(0.1)  # 0.1s at 100 px/s = 10 px
	assert_almost_eq(p.position.x, 10.0, 0.5, "velocity * delta drives translation")


# ---- 9: negative-direction velocity preserved ----------------

func test_negative_direction_preserved() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2(-90.0, 0.0), 1.0, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	p.position = Vector2.ZERO
	p._physics_process(0.1)
	assert_almost_eq(p.position.x, -9.0, 0.5, "negative-x velocity preserved")


# ---- 10: damage payload includes knockback derived from direction ---

func test_hit_payload_carries_knockback_along_velocity() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var p: Projectile = ProjectileScript.new()
	# 90 px/s along +x; knockback strength 80 -> kb vector (80, 0).
	p.configure(7, Vector2.RIGHT * 90.0, 1.0, Projectile.TEAM_ENEMY, null, 80.0)
	add_child_autofree(p)
	watch_signals(p)
	p._try_apply_hit(enemy)
	assert_eq(enemy.hits.size(), 1)
	assert_eq(enemy.hits[0]["amount"], 7)
	var kb: Vector2 = enemy.hits[0]["knockback"]
	assert_almost_eq(kb.x, 80.0, 0.001, "kb scaled along normalized velocity dir")
	assert_almost_eq(kb.y, 0.0, 0.001)
	assert_signal_emitted_with_parameters(p, "hit_target", [enemy, 7, null])


# ---- 11: hit_target signal payload ---------------------

func test_hit_target_signal_carries_payload() -> void:
	var enemy: FakeTarget = FakeTarget.new()
	add_child_autofree(enemy)
	var src: Node2D = autofree(Node2D.new())
	var p: Projectile = ProjectileScript.new()
	p.configure(13, Vector2.RIGHT * 80.0, 1.0, Projectile.TEAM_ENEMY, src)
	add_child_autofree(p)
	watch_signals(p)
	p._try_apply_hit(enemy)
	assert_signal_emitted_with_parameters(p, "hit_target", [enemy, 13, src])


# ---- 12: zero-velocity projectile still expires by lifetime ---------

func test_zero_velocity_still_expires() -> void:
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2.ZERO, 0.05, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	watch_signals(p)
	p._physics_process(0.1)
	assert_signal_emitted(p, "expired", "even a stationary projectile expires by lifetime")


# ---- 13: hit on world body (no take_damage method) still vanishes ---

func test_hit_world_geometry_vanishes_without_damage() -> void:
	# A Node2D without a `take_damage` method stands in for a wall body.
	var wall: Node2D = autofree(Node2D.new())
	var p: Projectile = ProjectileScript.new()
	p.configure(5, Vector2.RIGHT * 90.0, 1.0, Projectile.TEAM_ENEMY, null)
	add_child_autofree(p)
	watch_signals(p)
	# The mask routes world (LAYER_WORLD) into the body_entered path; here
	# we exercise _try_apply_hit directly with a non-damageable target.
	p._try_apply_hit(wall)
	# No `hit_target` because the target couldn't be damaged.
	assert_signal_not_emitted(p, "hit_target", "world body absorbs projectile silently")
	# But it DOES expire — a wall stops the projectile.
	assert_signal_emitted(p, "expired", "world body expires the projectile")

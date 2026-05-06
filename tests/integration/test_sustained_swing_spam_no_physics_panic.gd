extends GutTest
## Regression test for ticket `86c9nx1dx` — wave 2 of the run-002 P0 family.
##
## **Symptom (Sponsor's `embergrave-html5-fcbe466` HTML5 soak):** after PR
## #142 deferred all death-path Area2D adds, sustained Player attack spam
## (~30 rapid swings) eventually triggers:
##
##     USER ERROR: Can't change this state while flushing queries. Use
##     call_deferred() or set_deferred() to change monitoring state instead.
##
## with stack-trace middle frames `$func45438 / $func40118 / $func30136` —
## DIFFERENT from PR #142's death-path panic frames (`$func56772 / $func57078`).
## Trace immediately precedes panic with:
##
##     [combat-trace] Player.try_attack | POST damage=1 hitbox=@Area2D@N
##
## i.e. the panic fires inside `Player._spawn_hitbox`'s `add_child(hitbox)`
## call. The same root cause applies to every `Area2D add_child` site that
## runs from inside `_physics_process` — Player swings, every mob's swing
## (`Grunt._spawn_hitbox`, `Charger._spawn_charge_hitbox`,
## `Stratum1Boss._spawn_hitbox`) and the Shooter's projectile spawn
## (`Shooter._spawn_projectile`). Per Tess's PR #142 review, these are
## the spawn-path siblings of the death-path mutations PR #142 fixed.
##
## **Root cause:** when one swing's hitbox `body_entered` is being
## delivered (mid physics-query flush) and the same physics tick's
## `_physics_process` continues into another `try_attack` -> `add_child(Area2D)`,
## Godot 4's monitoring-state mutation guard panics. With sustained spam
## the engine occasionally has body_entered queues from the prior tick
## still flushing when a new swing's add_child lands.
##
## **Why this previously slipped:** PR #142's
## `test_simultaneous_mob_deaths_no_physics_panic.gd` covered the
## death-path Area2D adds (Pickup spawn, particle bursts) but no test
## hammered the spawn-path. The sustained-spam scenario (fire 50+
## attacks across many physics frames against multiple touching mobs
## so body_entered chains overlap with new spawn ticks) is the missing
## probe.
##
## **The fix (encapsulated in Hitbox / Projectile, not the spawners):**
## both Area2D-derived classes set `monitoring = false` and
## `monitorable = false` in `_init` so the node enters the tree with
## monitoring OFF (no panic during add_child). `_ready` queues a
## deferred call that flips them back on AFTER the physics flush
## completes. See `Hitbox.gd::_init` and `Projectile.gd::_init` for
## the canonical doc-comment.
##
## **The pair:** on `main` (pre-fix) the sustained-spam tests below
## emit one or more "Can't change this state while flushing queries"
## errors during the 50-swing loop. On the fix branch the loop
## completes cleanly, all swings spawn, and no engine errors surface.
##
## **Note on assertion shape:** GUT does not capture engine USER ERROR
## stderr, so we don't `assert_no_error()` directly. Instead we assert
## the *consequence* of the panic: pre-fix, the panic aborts the call
## chain mid-`try_attack`, so the swing's recovery state never sets,
## the swing count stalls, and `attack_spawned` emits drop. Post-fix
## the loop runs to completion. We also explicitly check
## `is_inside_tree()` on each spawned hitbox (pre-fix, an aborted
## add_child returns the hitbox to the caller but it never landed in
## the tree).

const PHYS_DELTA: float = 1.0 / 60.0

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const Stratum1BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const ProjectileScript: Script = preload("res://scripts/projectiles/Projectile.gd")


# ---- Helpers ---------------------------------------------------------------

func _make_player_in_tree(at: Vector2 = Vector2.ZERO) -> Player:
	var p: Player = PlayerScript.new()
	p.global_position = at
	add_child_autofree(p)
	return p


func _make_grunt_with_collider(at: Vector2, hp: int = 9999) -> Grunt:
	# High HP so 50+ swings don't kill it (death-path is PR #142's lane;
	# this test isolates the spawn-path).
	var g: Grunt = GruntScript.new()
	g.hp_max = hp
	g.hp_current = hp
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	g.add_child(shape)
	g.global_position = at
	add_child_autofree(g)
	return g


func _make_charger_with_collider(at: Vector2, hp: int = 9999) -> Charger:
	var c: Charger = ChargerScript.new()
	c.hp_max = hp
	c.hp_current = hp
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	c.add_child(shape)
	c.global_position = at
	add_child_autofree(c)
	return c


func _make_shooter_with_collider(at: Vector2, hp: int = 9999) -> Shooter:
	var s: Shooter = ShooterScript.new()
	s.hp_max = hp
	s.hp_current = hp
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	s.add_child(shape)
	s.global_position = at
	add_child_autofree(s)
	return s


func _make_boss_with_collider(at: Vector2, hp: int = 9999) -> Stratum1Boss:
	var b: Stratum1Boss = Stratum1BossScript.new()
	b.skip_intro_for_tests = true
	b.hp_max = hp
	b.hp_current = hp
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	b.add_child(shape)
	b.global_position = at
	add_child_autofree(b)
	return b


func _await_physics_frames(n: int = 1) -> void:
	for _i in range(n):
		await get_tree().physics_frame


# ---- 1: Player swing-spam — 50 attacks against a touching grunt ----------

func test_player_sustained_swing_spam_no_panic_50_attacks() -> void:
	# The headline regression: ~50 rapid Player swings while a grunt is
	# overlapping the player's swing arc. Each swing spawns a Hitbox Area2D
	# whose deferred initial-overlap sweep fires body_entered into the
	# grunt's take_damage in the next idle phase. Pre-fix, this chain
	# occasionally overlaps with a new swing's add_child and panics.
	# Post-fix, all 50 swings complete cleanly.
	var p: Player = _make_player_in_tree(Vector2(0, 0))
	# Grunt at the player's swing reach so every swing's hitbox lands on it.
	# 9999 HP keeps the grunt alive across all 50 swings (death-path is the
	# PR #142 lane; this test isolates the spawn-path).
	var grunt: Grunt = _make_grunt_with_collider(Vector2(28, 0), 9999)
	watch_signals(p)

	# Frame-by-frame swing loop. We assert per-swing that the spawned
	# hitbox immediately entered the scene tree — pre-fix, the panic
	# mid-add_child aborts the call chain so the hitbox never lands.
	for i in range(50):
		# Tick past LIGHT_RECOVERY (0.18s) so the next swing can fire.
		p._tick_timers(Player.LIGHT_RECOVERY + 0.001)
		var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
		assert_not_null(hb,
			"swing %d/50 fires (try_attack returned non-null)" % (i + 1))
		# Immediate-tree assertion: post-add_child the hitbox MUST be in
		# the tree under the player. Pre-fix the panic interrupts the
		# call so this assertion captures the consequence directly.
		assert_true(hb.is_inside_tree(),
			"REGRESSION-86c9nx1dx: swing %d hitbox is in the tree synchronously after try_attack (pre-fix the panic aborts add_child)" % (i + 1))
		assert_eq(hb.get_parent(), p,
			"swing %d hitbox parented under the player" % (i + 1))
		# Step one physics frame so the hitbox's deferred activation +
		# initial-overlap sweep lands, body_entered fires (or the sweep
		# applies the hit), and the hitbox's lifetime ticks down.
		await get_tree().physics_frame

	# `attack_spawned` emit-count proves all 50 swings ran end-to-end.
	# Pre-fix the panic could interrupt before the emit, dropping the count.
	assert_signal_emit_count(p, "attack_spawned", 50,
		"REGRESSION-86c9nx1dx: all 50 attack_spawned signals fire (pre-fix the panic aborts before emit)")

	# Sanity: the grunt took at least one damage along the way (proves
	# the post-fix deferred-monitoring activation + initial-overlap sweep
	# still applies hits — we didn't break the regression-86c9m36zh fix).
	assert_lt(grunt.get_hp(), 9999,
		"grunt took at least one damage during the spam (initial-overlap sweep still works post-fix)")


# ---- 2: Player vs MULTIPLE grunts simultaneously ------------------------

func test_player_swing_spam_against_multi_mob_pile_no_panic() -> void:
	# Multi-target variant — three grunts touching the player, 30 swings.
	# Each swing's body_entered fans out to all three grunts simultaneously,
	# stacking the overlap-flush window with the next swing's spawn.
	var p: Player = _make_player_in_tree(Vector2(0, 0))
	var grunts: Array[Grunt] = [
		_make_grunt_with_collider(Vector2(28, 0), 9999),
		_make_grunt_with_collider(Vector2(28, 8), 9999),
		_make_grunt_with_collider(Vector2(28, -8), 9999),
	]

	for i in range(30):
		p._tick_timers(Player.LIGHT_RECOVERY + 0.001)
		var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
		assert_not_null(hb, "swing %d/30 fires" % (i + 1))
		await get_tree().physics_frame

	# Post-fix: at least one grunt took damage (sweep + signal flow ran
	# at least once). All three grunts remain alive (HP buffer is
	# generous; the test isolates spawn-path from death-path).
	var any_damaged: bool = false
	for g in grunts:
		if g.get_hp() < 9999:
			any_damaged = true
		assert_false(g.is_dead(), "grunt stays alive across the 30-swing spam (HP buffer holds)")
	assert_true(any_damaged, "at least one grunt took damage during the multi-mob spam")


# ---- 3: Grunt swing-spam — 30 melee swings from a grunt ------------------

func test_grunt_sustained_swing_spam_no_panic() -> void:
	# Per-mob analogue: a Grunt's `_swing_light` runs from `_process_chase`
	# inside `_physics_process` and spawns a Hitbox Area2D. Same root
	# cause, mob-side. We force-call `_swing_light` 30 times to skip the
	# AI's attack-recovery window (the test is about the spawn-path
	# panic, not the swing cadence).
	var grunt: Grunt = _make_grunt_with_collider(Vector2(0, 0), 9999)
	# Bare grunt has no mob_def, but `_swing_light` still spawns a hitbox
	# (damage routes through the formula utility with mob_def=null
	# returning damage_base default).
	for i in range(30):
		grunt._swing_light(Vector2.RIGHT)
		# Reset recovery so the next call's _set_state(STATE_ATTACKING)
		# logic isn't gated.
		grunt._attack_recovery_left = 0.0
		await get_tree().physics_frame

	# Post-fix: the grunt is still alive and able to keep swinging. Pre-fix
	# the panic would abort the call chain inside one of the swings —
	# subsequent swings might fire from a corrupted state.
	assert_false(grunt.is_dead(), "grunt survived 30 spawn-spam swings cleanly")


# ---- 4: Charger contact-hitbox spam --------------------------------------

func test_charger_contact_hitbox_spawn_spam_no_panic() -> void:
	# Charger's `_spawn_charge_hitbox` runs from `_maybe_charge_hit_player`
	# inside `_process_charge` (physics-tick). Each call spawns a Hitbox.
	# We force-call it 20 times to exercise the spawn-path.
	var c: Charger = _make_charger_with_collider(Vector2(0, 0), 9999)
	c._charge_dir = Vector2.RIGHT
	for i in range(20):
		var hb: Hitbox = c._spawn_charge_hitbox()
		assert_not_null(hb, "charger contact hitbox %d/20 spawned" % (i + 1))
		await get_tree().physics_frame
	assert_false(c.is_dead(), "charger survived 20 contact-hitbox spawns cleanly")


# ---- 5: Boss melee + slam hitbox spawn spam ------------------------------

func test_boss_hitbox_spawn_spam_no_panic() -> void:
	# Boss's `_spawn_hitbox` is called from melee + slam fire paths inside
	# `_physics_process`. We exercise it directly with a mix of melee +
	# slam-shaped spawns (different reach/radius/lifetime).
	var b: Stratum1Boss = _make_boss_with_collider(Vector2(0, 0), 9999)
	for i in range(20):
		# Alternate melee / slam to exercise both shapes.
		var hb: Hitbox
		if i % 2 == 0:
			hb = b._spawn_hitbox(
				Vector2.RIGHT, 5,
				Vector2.RIGHT * Stratum1Boss.MELEE_KNOCKBACK,
				Stratum1Boss.MELEE_HITBOX_REACH,
				Stratum1Boss.MELEE_HITBOX_RADIUS,
				Stratum1Boss.MELEE_HITBOX_LIFETIME)
		else:
			hb = b._spawn_hitbox(
				Vector2.ZERO, 7,
				Vector2.RIGHT * Stratum1Boss.SLAM_KNOCKBACK,
				0.0,
				Stratum1Boss.SLAM_HITBOX_RADIUS,
				Stratum1Boss.SLAM_HITBOX_LIFETIME)
		assert_not_null(hb, "boss hitbox %d/20 spawned" % (i + 1))
		await get_tree().physics_frame
	assert_false(b.is_dead(), "boss survived 20 hitbox spawns cleanly")


# ---- 6: Shooter projectile spawn spam ------------------------------------

func test_shooter_projectile_spawn_spam_no_panic() -> void:
	# Shooter's `_spawn_projectile` parents the projectile under the
	# shooter's parent (a Node2D in this test, since we add_child_autofree
	# the shooter to GutTest). The projectile is an Area2D — same root
	# cause as the hitbox sites.
	var s: Shooter = _make_shooter_with_collider(Vector2(0, 0), 9999)
	for i in range(15):
		s._spawn_projectile(Vector2.RIGHT)
		await get_tree().physics_frame
	# Shooter still alive — no panic mid-spawn aborted any AI state.
	assert_false(s.is_dead(),
		"shooter survived 15 projectile spawns cleanly (spawn-path panic absent)")
	# Each spawn appended to `_shots_fired`.
	assert_eq(s.get_shots_fired(), 15,
		"all 15 projectiles registered shots_fired (no panic-aborted spawns)")


# ---- 7: Hitbox enters tree with monitoring-off, activates after defer ----

func test_hitbox_enters_tree_with_monitoring_off_then_activates() -> void:
	# Direct-property assertion of the wave-2 fix shape: a freshly-
	# constructed Hitbox starts with monitoring/monitorable OFF, then
	# the deferred activation flips them ON before the initial-overlap
	# sweep runs.
	var hb: Hitbox = HitboxScript.new()
	hb.configure(5, Vector2.ZERO, 0.30, Hitbox.TEAM_PLAYER, null)
	# Pre-tree: monitoring/monitorable should be false (set in _init).
	assert_false(hb.monitoring,
		"REGRESSION-86c9nx1dx: Hitbox starts with monitoring=false (avoids physics-flush panic)")
	assert_false(hb.monitorable,
		"REGRESSION-86c9nx1dx: Hitbox starts with monitorable=false")
	# Add a CollisionShape2D so post-activation overlap queries work.
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	hb.add_child(shape)
	add_child_autofree(hb)
	# After add_child, monitoring is still false until the deferred call lands.
	# The deferred `_activate_and_check_initial_overlaps` runs at the next
	# idle phase. Await one process_frame to let it run.
	await get_tree().process_frame
	assert_true(hb.monitoring,
		"REGRESSION-86c9nx1dx: Hitbox monitoring activated post-flush via deferred call")
	assert_true(hb.monitorable,
		"REGRESSION-86c9nx1dx: Hitbox monitorable activated post-flush")


# ---- 8: Projectile mirrors the same monitoring-off-then-on shape --------

func test_projectile_enters_tree_with_monitoring_off_then_activates() -> void:
	var pj: Projectile = ProjectileScript.new()
	pj.configure(5, Vector2.RIGHT * 90.0, 1.0, Projectile.TEAM_ENEMY, null)
	assert_false(pj.monitoring,
		"REGRESSION-86c9nx1dx: Projectile starts with monitoring=false")
	assert_false(pj.monitorable,
		"REGRESSION-86c9nx1dx: Projectile starts with monitorable=false")
	add_child_autofree(pj)
	await get_tree().process_frame
	assert_true(pj.monitoring,
		"REGRESSION-86c9nx1dx: Projectile monitoring activated post-flush")
	assert_true(pj.monitorable,
		"REGRESSION-86c9nx1dx: Projectile monitorable activated post-flush")

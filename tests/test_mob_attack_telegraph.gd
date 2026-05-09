extends GutTest
## Attack-telegraph visual tests — M1 RC soak-attempt-4 fix (ticket 86c9q81br).
##
## Spec: every mob type plays a visible red-glow telegraph BEFORE its attack
## lands. Tests assert:
##   (a) Grunt light-attack: STATE_TELEGRAPHING_LIGHT fires + light_telegraph_started
##       emits BEFORE swing_spawned (hitbox spawn).
##   (b) Grunt attack-telegraph tween targets a non-white tint (visual delta from
##       rest, proving the visible-draw-node rule is honoured per Tier 1 bar).
##   (c) Charger: charge_telegraph_started fires before STATE_CHARGING (existing
##       contract; no new assertion) AND _attack_telegraph_tween is created in
##       STATE_TELEGRAPHING so the visual tween fires during the windup.
##   (d) Shooter: aim_started fires before STATE_POST_FIRE_RECOVERY (existing);
##       AND telegraph tween is created when entering STATE_AIMING.
##   (e) EDGE: Grunt telegraph is re-entry-idempotent — calling _begin_light_telegraph
##       twice in the same tick does not double-start.
##   (f) EDGE: Grunt dies mid-telegraph — no swing fires, tween is killed cleanly.
##   (g) EDGE: tint is HTML5-safe — all ATTACK_TELEGRAPH_TINT channels < 1.0
##       (avoids WebGL2/sRGB clamp trap from PR #115/#137 lessons).

const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")


# ---- Helpers ------------------------------------------------------------

class FakePlayer:
	extends Node2D
	# Dummy target. Mobs only read global_position.


func _make_grunt() -> Grunt:
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	return g


func _make_charger() -> Charger:
	var c: Charger = ChargerScript.new()
	add_child_autofree(c)
	c.set_physics_process(false)  # headless-determinism guard (see test_charger.gd)
	return c


func _make_shooter() -> Shooter:
	var s: Shooter = ShooterScript.new()
	add_child_autofree(s)
	return s


# ---- (a) Grunt: STATE_TELEGRAPHING_LIGHT fires before swing_spawned -----

func test_grunt_enters_telegraph_state_before_swing() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # within ATTACK_RANGE
	g.set_player(p)

	watch_signals(g)
	g._physics_process(0.016)
	# First physics tick while player is in range: should enter STATE_TELEGRAPHING_LIGHT
	# (NOT STATE_ATTACKING directly — the telegraph state is the NEW contract).
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT,
		"grunt enters TELEGRAPHING_LIGHT when player is in attack range (not immediate swing)")
	assert_signal_emitted(g, "light_telegraph_started",
		"light_telegraph_started fires when telegraph begins")
	assert_signal_not_emitted(g, "swing_spawned",
		"swing_spawned must NOT fire until telegraph window elapses")


func test_grunt_swing_fires_after_telegraph_window() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	g.set_player(p)

	# Enter telegraph.
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT)

	# Tick past the telegraph window.
	watch_signals(g)
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_signal_emitted(g, "swing_spawned",
		"swing_spawned fires after LIGHT_TELEGRAPH_DURATION elapses")
	var params: Array = get_signal_parameters(g, "swing_spawned", 0)
	assert_eq(params[0], Grunt.SWING_KIND_LIGHT,
		"swing kind is LIGHT after the light telegraph")


# ---- (b) Grunt: telegraph tint is non-white (visible-draw-node delta) --

func test_grunt_attack_telegraph_tint_is_not_white() -> void:
	# Assert the tint constant is meaningfully different from the rest color
	# (white = Color(1,1,1,1)). This is the Tier 1 bar assertion — prevents
	# the white-on-white cascade no-op that landed in PR #115.
	var tint: Color = Grunt.ATTACK_TELEGRAPH_TINT
	assert_ne(tint, Color(1.0, 1.0, 1.0, 1.0),
		"ATTACK_TELEGRAPH_TINT must differ from white rest-color (Tier 1 bar — visible delta)")


func test_grunt_telegraph_tween_created_on_enter() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	g.set_player(p)

	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT)
	# _attack_telegraph_tween is a Tween created in _play_attack_telegraph.
	# Verify it exists and is valid (not null, not stopped).
	var tween: Tween = g._attack_telegraph_tween
	assert_not_null(tween, "_attack_telegraph_tween must be non-null after telegraph start")
	if tween != null:
		assert_true(tween.is_valid(), "_attack_telegraph_tween must be running (is_valid)")


# ---- (c) Charger: telegraph fires visual tween during windup -----------

func test_charger_telegraph_tween_created_in_telegraphing_state() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	c.set_player(p)
	watch_signals(c)

	# Idle -> spotted.
	c._physics_process(0.016)
	# Spotted -> telegraphing.
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)
	assert_eq(c.get_state(), Charger.STATE_TELEGRAPHING,
		"charger entered TELEGRAPHING state")
	assert_signal_emitted(c, "charge_telegraph_started",
		"charge_telegraph_started fires on entering TELEGRAPHING")
	# The visual tween must be created at telegraph start (not at charge start).
	var tween: Tween = c._attack_telegraph_tween
	assert_not_null(tween, "_attack_telegraph_tween non-null in TELEGRAPHING")
	if tween != null:
		assert_true(tween.is_valid(), "_attack_telegraph_tween running in TELEGRAPHING")


func test_charger_attack_telegraph_tint_is_not_white() -> void:
	assert_ne(Charger.ATTACK_TELEGRAPH_TINT, Color(1.0, 1.0, 1.0, 1.0),
		"Charger ATTACK_TELEGRAPH_TINT must differ from white (Tier 1 bar)")


# ---- (d) Shooter: telegraph tween fires when entering STATE_AIMING -----

func test_shooter_telegraph_tween_created_on_aiming() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)  # sweet spot
	s.set_player(p)
	watch_signals(s)

	# Idle -> spotted -> aiming.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_AIMING,
		"shooter in STATE_AIMING after spotted hold")
	assert_signal_emitted(s, "aim_started",
		"aim_started fires on entering STATE_AIMING")
	var tween: Tween = s._attack_telegraph_tween
	assert_not_null(tween, "_attack_telegraph_tween non-null in STATE_AIMING")
	if tween != null:
		assert_true(tween.is_valid(), "_attack_telegraph_tween running in STATE_AIMING")


func test_shooter_attack_telegraph_tint_is_not_white() -> void:
	assert_ne(Shooter.ATTACK_TELEGRAPH_TINT, Color(1.0, 1.0, 1.0, 1.0),
		"Shooter ATTACK_TELEGRAPH_TINT must differ from white (Tier 1 bar)")


# ---- (e) EDGE: Grunt telegraph is re-entry-idempotent ------------------

func test_grunt_telegraph_no_double_start_on_reentry() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	g.set_player(p)

	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT)
	watch_signals(g)

	# Tick again — player still in range, still telegraphing. Must not
	# re-emit light_telegraph_started or restart the tween.
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT,
		"stays in TELEGRAPHING_LIGHT on second tick")
	assert_signal_not_emitted(g, "light_telegraph_started",
		"light_telegraph_started must not re-emit if already telegraphing (re-entry guard)")


# ---- (f) EDGE: Grunt dies mid-telegraph — no swing from corpse ---------

func test_grunt_dies_during_light_telegraph_no_swing() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 50})
	var g: Grunt = GruntScript.new()
	g.mob_def = def
	add_child_autofree(g)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	g.set_player(p)

	# Enter telegraph.
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT)

	# Kill mid-telegraph.
	watch_signals(g)
	g.take_damage(9999, Vector2.ZERO, null)
	assert_eq(g.get_state(), Grunt.STATE_DEAD, "grunt is dead")

	# Tick past where the telegraph would have fired the swing.
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.5)
	assert_signal_not_emitted(g, "swing_spawned",
		"no light swing fires from a dead grunt — telegraph is cancelled on death")
	assert_signal_emit_count(g, "mob_died", 1,
		"mob_died fired exactly once")


# ---- (g) EDGE: tint channels are HTML5-safe (all < 1.0 on R/G/B) ------

func test_grunt_telegraph_tint_channels_are_html5_safe() -> void:
	# WebGL2/sRGB clamps color to [0, 1]. A tint with any channel > 1.0 risks
	# being clamped into invisibility on a white-background sprite. R/G must be
	# < 1.0 (strict) so the visible delta from white survives the clamp; B/A
	# only need to be <= 1.0. (GUT lacks `assert_le`; using assert_true with an
	# explicit comparison.)
	var tint: Color = Grunt.ATTACK_TELEGRAPH_TINT
	assert_lt(tint.r, 1.0, "Grunt tint.r < 1.0 (HTML5 safe)")
	assert_lt(tint.g, 1.0, "Grunt tint.g < 1.0 (HTML5 safe)")
	assert_true(tint.b <= 1.0, "Grunt tint.b <= 1.0 (HTML5 safe)")
	assert_true(tint.a <= 1.0, "Grunt tint.a <= 1.0 (HTML5 safe)")


func test_charger_telegraph_tint_channels_are_html5_safe() -> void:
	var tint: Color = Charger.ATTACK_TELEGRAPH_TINT
	assert_lt(tint.r, 1.0, "Charger tint.r < 1.0")
	assert_lt(tint.g, 1.0, "Charger tint.g < 1.0")
	assert_true(tint.b <= 1.0, "Charger tint.b <= 1.0")
	assert_true(tint.a <= 1.0, "Charger tint.a <= 1.0")


func test_shooter_telegraph_tint_channels_are_html5_safe() -> void:
	var tint: Color = Shooter.ATTACK_TELEGRAPH_TINT
	assert_lt(tint.r, 1.0, "Shooter tint.r < 1.0")
	assert_lt(tint.g, 1.0, "Shooter tint.g < 1.0")
	assert_true(tint.b <= 1.0, "Shooter tint.b <= 1.0")
	assert_true(tint.a <= 1.0, "Shooter tint.a <= 1.0")


# ---- Stratum1Boss: telegraph fires on melee + slam wind-up paths --------

func test_stratum1_boss_attack_telegraph_tint_is_not_white() -> void:
	# Tier 1 visible-delta bar — boss tint differs from white rest color.
	assert_ne(Stratum1Boss.ATTACK_TELEGRAPH_TINT, Color(1.0, 1.0, 1.0, 1.0),
		"Boss ATTACK_TELEGRAPH_TINT must differ from white (Tier 1 bar)")


func test_stratum1_boss_telegraph_tint_channels_are_html5_safe() -> void:
	var tint: Color = Stratum1Boss.ATTACK_TELEGRAPH_TINT
	assert_lt(tint.r, 1.0, "Boss tint.r < 1.0")
	assert_lt(tint.g, 1.0, "Boss tint.g < 1.0")
	assert_true(tint.b <= 1.0, "Boss tint.b <= 1.0")
	assert_true(tint.a <= 1.0, "Boss tint.a <= 1.0")


func test_stratum1_boss_melee_telegraph_creates_tween() -> void:
	# Boss melee path: skip_intro_for_tests so we start in IDLE not DORMANT,
	# then put the player in MELEE_RANGE and tick — boss should enter
	# STATE_TELEGRAPHING_MELEE and create the visual telegraph tween.
	const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # within MELEE_RANGE
	b.set_player(p)

	b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"boss enters TELEGRAPHING_MELEE when player in melee range")
	var tween: Tween = b._attack_telegraph_tween
	assert_not_null(tween, "_attack_telegraph_tween non-null in TELEGRAPHING_MELEE")
	if tween != null:
		assert_true(tween.is_valid(), "_attack_telegraph_tween running in TELEGRAPHING_MELEE")


func test_stratum1_boss_slam_telegraph_creates_tween() -> void:
	# Boss slam path: requires phase 2 (slam unlocks at PHASE_2). Drive into
	# phase 2 by damaging boss past 66% threshold + tick past transition.
	const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
	const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	b.mob_def = def
	add_child_autofree(b)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)

	# Drop HP to phase-2 boundary (396) then advance past transition.
	b.take_damage(204, Vector2.ZERO, null)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2, "boss in phase 2")

	# Position player in slam radius (outside melee, inside slam).
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(50.0, 0.0)  # > MELEE_RANGE (36), < SLAM_RADIUS
	b._physics_process(0.016)
	# Boss should pick slam telegraph (phase 2 + slam range + cooldown clear).
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"boss enters TELEGRAPHING_SLAM in phase 2 at slam range")
	var tween: Tween = b._attack_telegraph_tween
	assert_not_null(tween, "_attack_telegraph_tween non-null in TELEGRAPHING_SLAM")
	if tween != null:
		assert_true(tween.is_valid(), "_attack_telegraph_tween running in TELEGRAPHING_SLAM")

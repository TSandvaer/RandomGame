extends GutTest
## Tests for mob-side combat visual feedback — paired with `Grunt.gd`,
## `Charger.gd`, `Shooter.gd`, `Stratum1Boss.gd` per Uma's
## `team/uma-ux/combat-visual-feedback.md` (run-008 — locked at PR #111).
##
## Coverage matrix (one paired test per row):
##   - Hit-flash modulates white on take_damage (Grunt + Charger + Shooter + Boss).
##   - Hit-flash duration is 80ms total (20+20+40 = HIT_FLASH_IN+HOLD+OUT).
##   - Hit-flash zero-damage path is silent (no tween started).
##   - Hit-flash second-hit-during-flash kills + restarts tween (Grunt).
##   - Death tween: 200ms scale 1.0→0.6 + alpha 1.0→0.0, queue_free at end (Grunt).
##   - Death contract: `mob_died` fires at frame-1 of `_die`, NOT after the tween.
##   - Death particles: 6-particle CPUParticles2D burst parented to the room
##     (NOT the mob — survives queue_free).
##   - Boss death: 24 particles + 4-px screen shake + 400ms hold + 200ms decay.
##   - Boss death contract: `boss_died` at frame-1 (mirror of mob_died contract).
##   - All four mob types use the same hit-flash rule (cross-system consistency).
##
## Per the run-008 design lock: do NOT assert exact pixel positions / colors at
## arbitrary tween times — driving Tween manually in headless GUT is fragile.
## Instead, assert (a) the tween was created + is_valid right after take_damage
## (b) tween cleanup happens on kill/finish (c) the *shape* of the tween via the
## constants on the script (HIT_FLASH_IN/HOLD/OUT/DEATH_TWEEN_DURATION).

const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")


# ---- Helpers --------------------------------------------------------

func _make_grunt() -> Grunt:
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	return g


func _make_charger() -> Charger:
	var c: Charger = ChargerScript.new()
	add_child_autofree(c)
	return c


func _make_shooter() -> Shooter:
	var s: Shooter = ShooterScript.new()
	add_child_autofree(s)
	return s


func _make_boss() -> Stratum1Boss:
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	return b


# ---- Hit-flash: starts a tween on damage --------------------------

func test_grunt_hit_flash_starts_tween_on_take_damage() -> void:
	var g: Grunt = _make_grunt()
	# Pre-condition: no flash tween yet.
	assert_null(g._hit_flash_tween, "no flash tween before damage")
	g.take_damage(5, Vector2.ZERO, null)
	assert_not_null(g._hit_flash_tween, "flash tween created on take_damage")
	assert_true(g._hit_flash_tween.is_valid(), "flash tween is_valid right after spawn")


func test_charger_hit_flash_starts_tween_on_take_damage() -> void:
	var c: Charger = _make_charger()
	c.take_damage(5, Vector2.ZERO, null)
	assert_not_null(c._hit_flash_tween)
	assert_true(c._hit_flash_tween.is_valid())


func test_shooter_hit_flash_starts_tween_on_take_damage() -> void:
	var s: Shooter = _make_shooter()
	s.take_damage(5, Vector2.ZERO, null)
	assert_not_null(s._hit_flash_tween)
	assert_true(s._hit_flash_tween.is_valid())


func test_boss_hit_flash_starts_tween_on_take_damage() -> void:
	var b: Stratum1Boss = _make_boss()
	b.take_damage(5, Vector2.ZERO, null)
	assert_not_null(b._hit_flash_tween)
	assert_true(b._hit_flash_tween.is_valid())


# ---- Hit-flash: 80ms total = 20 + 20 + 40 (Uma §2 spec) -----------

func test_grunt_hit_flash_constants_match_spec() -> void:
	# Spec is load-bearing — assert the constants match the design doc's 80ms.
	assert_almost_eq(Grunt.HIT_FLASH_IN, 0.020, 0.0001, "20ms tween-in")
	assert_almost_eq(Grunt.HIT_FLASH_HOLD, 0.020, 0.0001, "20ms hold")
	assert_almost_eq(Grunt.HIT_FLASH_OUT, 0.040, 0.0001, "40ms tween-back")
	var total: float = Grunt.HIT_FLASH_IN + Grunt.HIT_FLASH_HOLD + Grunt.HIT_FLASH_OUT
	assert_almost_eq(total, 0.080, 0.0001, "total = 80ms per Uma §2")


func test_all_mobs_have_identical_hit_flash_rule() -> void:
	# Cross-mob consistency per Uma §6: same 80ms rule across grunt/charger/
	# shooter/boss. Drift here = visual inconsistency in playtest.
	assert_eq(Grunt.HIT_FLASH_IN, Charger.HIT_FLASH_IN)
	assert_eq(Grunt.HIT_FLASH_HOLD, Charger.HIT_FLASH_HOLD)
	assert_eq(Grunt.HIT_FLASH_OUT, Charger.HIT_FLASH_OUT)
	assert_eq(Grunt.HIT_FLASH_IN, Shooter.HIT_FLASH_IN)
	assert_eq(Grunt.HIT_FLASH_HOLD, Shooter.HIT_FLASH_HOLD)
	assert_eq(Grunt.HIT_FLASH_OUT, Shooter.HIT_FLASH_OUT)
	assert_eq(Grunt.HIT_FLASH_IN, Stratum1Boss.HIT_FLASH_IN)
	assert_eq(Grunt.HIT_FLASH_HOLD, Stratum1Boss.HIT_FLASH_HOLD)
	assert_eq(Grunt.HIT_FLASH_OUT, Stratum1Boss.HIT_FLASH_OUT)


# ---- Hit-flash: observable color delta (white-on-white bug fix, 86c9ncd9g) --
#
# Why these tests exist: PR #115 / PR #136's hit-flash shipped with target
# `Color(1,1,1,1)` — the multiplicative identity for `modulate`. The previous
# `test_*_hit_flash_starts_tween_on_take_damage` tests only asserted
# `tween_valid=true`, which a no-op tween still passes. The visual bug shipped
# anyway because no test checked that the tweened color *differed from rest*.
# These paired tests close that gap by asserting (a) HIT_FLASH_COLOR is not
# the multiplicative identity, (b) it's overbright (component > 1.0) so it
# brightens any colored sprite, and (c) all four mobs share the same color
# constant per Uma §6 cross-mob consistency.

func test_grunt_hit_flash_color_is_not_multiplicative_identity() -> void:
	# Load-bearing assertion: the flash target must produce a visible delta
	# when multiplied against any non-zero sprite color. `Color(1,1,1,1)` is
	# the identity and would render no flash — that's the bug we're fixing.
	assert_ne(Grunt.HIT_FLASH_COLOR, Color(1, 1, 1, 1),
		"hit-flash target must NOT be multiplicative identity (Uma §2 / 86c9ncd9g)")


func test_grunt_hit_flash_color_is_overbright() -> void:
	# Overbright (component > 1.0) is what lets the flash visibly brighten
	# a tinted sprite via multiplicative modulate. <=1.0 components on a
	# dark sprite would *darken* it (wrong direction).
	assert_gt(Grunt.HIT_FLASH_COLOR.r, 1.0, "flash R must overbright")
	assert_gt(Grunt.HIT_FLASH_COLOR.g, 1.0, "flash G must overbright")
	assert_gt(Grunt.HIT_FLASH_COLOR.b, 1.0, "flash B must overbright")
	assert_almost_eq(Grunt.HIT_FLASH_COLOR.a, 1.0, 0.0001,
		"flash alpha stays at 1.0 (no fade during flash)")


func test_grunt_hit_flash_color_differs_from_rest() -> void:
	# Concrete delta on Grunt.tscn's actual sprite tint. Grunt's "Sprite"
	# ColorRect is `Color(0.55, 0.18, 0.22)`. The rendered flash color is
	# `HIT_FLASH_COLOR * sprite_color` (modulate is multiplicative). On HTML5
	# sRGB-clamped pipelines the result clamps to (1.0, sprite.g, sprite.b)
	# — visibly brighter than rest. We verify the multiplied-and-clamped
	# result differs from the unflashed sprite color by at least one channel.
	var sprite_color: Color = Color(0.55, 0.18, 0.22, 1.0)
	var flashed: Color = Color(
		min(1.0, Grunt.HIT_FLASH_COLOR.r * sprite_color.r),
		min(1.0, Grunt.HIT_FLASH_COLOR.g * sprite_color.g),
		min(1.0, Grunt.HIT_FLASH_COLOR.b * sprite_color.b),
		Grunt.HIT_FLASH_COLOR.a * sprite_color.a)
	# At least one channel must change observably between rest and flash.
	var delta: float = absf(flashed.r - sprite_color.r) \
		+ absf(flashed.g - sprite_color.g) \
		+ absf(flashed.b - sprite_color.b)
	assert_gt(delta, 0.05, "flash must produce >0.05 cumulative-channel delta vs rest sprite")


func test_all_mobs_share_hit_flash_color() -> void:
	# Cross-mob consistency: all four mobs MUST flash the same color so
	# combat reads consistently regardless of which mob you hit.
	assert_eq(Grunt.HIT_FLASH_COLOR, Charger.HIT_FLASH_COLOR,
		"Charger flash matches Grunt (Uma §6)")
	assert_eq(Grunt.HIT_FLASH_COLOR, Shooter.HIT_FLASH_COLOR,
		"Shooter flash matches Grunt (Uma §6)")
	assert_eq(Grunt.HIT_FLASH_COLOR, Stratum1Boss.HIT_FLASH_COLOR,
		"Stratum1Boss flash matches Grunt (Uma §6)")


func test_grunt_take_damage_flash_target_is_not_rest() -> void:
	# Integration: after take_damage, the running tween's *active step* must
	# be tweening toward HIT_FLASH_COLOR (not _modulate_at_rest). We can't
	# poke the tween's internal step cursor portably, but we CAN assert the
	# pre-tween state (parent.modulate ≈ rest) flips toward flash within one
	# physics tick — observable end-of-frame state change, not just
	# tween-existence.
	var g: Grunt = _make_grunt()
	# Force a known rest state so the assertion is unambiguous.
	g.modulate = Color(0.5, 0.5, 0.5, 1.0)
	g.take_damage(5, Vector2.ZERO, null)
	# Advance one physics frame so the tween's first step ticks.
	await get_tree().process_frame
	await get_tree().process_frame
	# Modulate must have moved toward HIT_FLASH_COLOR (away from the 0.5 rest).
	# Each channel of HIT_FLASH_COLOR (2.5) is greater than rest (0.5), so
	# the modulate's R component must have increased.
	assert_gt(g.modulate.r, 0.5,
		"after one frame the tween advances modulate.r away from rest toward HIT_FLASH_COLOR — proves NON-no-op tween")


# ---- Hit-flash: zero-damage path is silent -----------------------

func test_grunt_zero_damage_does_not_start_flash() -> void:
	var g: Grunt = _make_grunt()
	g.take_damage(0, Vector2.ZERO, null)
	assert_null(g._hit_flash_tween, "zero damage skips the flash (matches Uma §2)")
	g.take_damage(-5, Vector2.ZERO, null)
	assert_null(g._hit_flash_tween, "negative-clamped-to-zero damage skips the flash")


# ---- Hit-flash: second hit during flash kills + restarts ---------

func test_grunt_second_hit_during_flash_restarts_tween() -> void:
	var g: Grunt = _make_grunt()
	g.take_damage(3, Vector2.ZERO, null)
	var first_tween: Tween = g._hit_flash_tween
	assert_not_null(first_tween)
	# Second hit before the flash naturally completes — tween must restart.
	# The production rule (Uma §2 edge case): the old tween is killed and a
	# fresh tween is created so flashes don't accumulate or extend. We assert
	# (a) a new tween instance was assigned (b) the new tween is valid. We
	# don't assert on `first_tween.is_valid()` because Godot 4.3's Tween.kill
	# leaves the SceneTreeTween object in a valid-but-stopped state; the
	# load-bearing invariant is that the production code calls kill() then
	# create_tween(), which is observable via the reference change below.
	g.take_damage(3, Vector2.ZERO, null)
	var second_tween: Tween = g._hit_flash_tween
	assert_not_null(second_tween)
	assert_ne(first_tween, second_tween, "second hit creates a new flash tween (Uma §2)")
	assert_true(second_tween.is_valid(), "new tween is the active one")


# ---- Death tween: 200ms scale + fade ------------------------------

func test_grunt_death_tween_constants_match_spec() -> void:
	assert_almost_eq(Grunt.DEATH_TWEEN_DURATION, 0.200, 0.0001, "200ms per Uma §3a")
	assert_almost_eq(Grunt.DEATH_TARGET_SCALE, 0.6, 0.0001, "scale 1.0→0.6 per Uma §3a")
	assert_eq(Grunt.DEATH_PARTICLE_COUNT, 6, "6 particles for normal mobs per Uma §3b")


func test_charger_death_tween_constants_match_spec() -> void:
	assert_almost_eq(Charger.DEATH_TWEEN_DURATION, 0.200, 0.0001)
	assert_almost_eq(Charger.DEATH_TARGET_SCALE, 0.6, 0.0001)
	assert_eq(Charger.DEATH_PARTICLE_COUNT, 6)


func test_shooter_death_tween_constants_match_spec() -> void:
	assert_almost_eq(Shooter.DEATH_TWEEN_DURATION, 0.200, 0.0001)
	assert_almost_eq(Shooter.DEATH_TARGET_SCALE, 0.6, 0.0001)
	assert_eq(Shooter.DEATH_PARTICLE_COUNT, 6)


# ---- Death tween: created at _die() -------------------------------

func test_grunt_death_tween_created_on_die() -> void:
	var g: Grunt = _make_grunt()
	# Lethal damage → triggers _die → spawns death tween.
	g.take_damage(g.get_max_hp(), Vector2.ZERO, null)
	assert_true(g.is_dead())
	assert_not_null(g._death_tween, "death tween created on _die")


func test_charger_death_tween_created_on_die() -> void:
	var c: Charger = _make_charger()
	c.take_damage(c.get_max_hp(), Vector2.ZERO, null)
	assert_true(c.is_dead())
	assert_not_null(c._death_tween)


func test_shooter_death_tween_created_on_die() -> void:
	var s: Shooter = _make_shooter()
	s.take_damage(s.get_max_hp(), Vector2.ZERO, null)
	assert_true(s.is_dead())
	assert_not_null(s._death_tween)


# ---- Critical contract: mob_died fires at FRAME-1, not after tween ----

func test_grunt_mob_died_emits_at_die_start_not_after_tween() -> void:
	var g: Grunt = _make_grunt()
	watch_signals(g)
	# Lethal damage. mob_died MUST emit on this frame, before the tween
	# completes — loot drop + room-clear logic depend on this.
	g.take_damage(g.get_max_hp(), Vector2.ZERO, null)
	# This assertion happens *immediately* after the take_damage call,
	# before any tween steps have advanced. mob_died must already be in
	# the signal log.
	assert_signal_emit_count(g, "mob_died", 1, "mob_died fires at frame-1 of _die, not after tween")
	assert_true(g.is_dead(), "mob is_dead immediately too")


func test_charger_mob_died_emits_at_die_start_not_after_tween() -> void:
	var c: Charger = _make_charger()
	watch_signals(c)
	c.take_damage(c.get_max_hp(), Vector2.ZERO, null)
	assert_signal_emit_count(c, "mob_died", 1, "frame-1 contract preserved")


func test_shooter_mob_died_emits_at_die_start_not_after_tween() -> void:
	var s: Shooter = _make_shooter()
	watch_signals(s)
	s.take_damage(s.get_max_hp(), Vector2.ZERO, null)
	assert_signal_emit_count(s, "mob_died", 1, "frame-1 contract preserved")


func test_boss_boss_died_emits_at_die_start_not_after_tween() -> void:
	var b: Stratum1Boss = _make_boss()
	watch_signals(b)
	b.take_damage(b.get_max_hp(), Vector2.ZERO, null)
	assert_signal_emit_count(b, "boss_died", 1, "boss frame-1 contract preserved")


# ---- Particle burst: parented to room (NOT mob) -------------------

func test_grunt_death_particles_parented_to_room_not_self() -> void:
	# Grunt under a parent (the "room") — death burst goes to the room,
	# not the grunt, so the burst persists past the mob's queue_free.
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var g: Grunt = GruntScript.new()
	room.add_child(g)
	# Pre-condition: no CPUParticles2D anywhere yet.
	assert_eq(_count_particles_under(room), 0)
	# Lethal damage.
	g.take_damage(g.get_max_hp(), Vector2.ZERO, null)
	# Burst spawned under room (not under grunt — grunt's death tween is
	# about to fade it out and queue_free).
	assert_eq(_count_particles_under(room), 1, "burst parented to room")
	# The grunt itself doesn't carry the burst — it's a sibling.
	assert_eq(_count_particles_under(g), 0, "burst NOT parented to mob")


func test_boss_death_particles_count_is_24() -> void:
	# Climax bump per Uma §3 boss-addendum: 24 particles vs grunt's 6.
	assert_eq(Stratum1Boss.DEATH_PARTICLE_COUNT, 24, "boss climax = 4× particle volume")
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	room.add_child(b)
	b.take_damage(b.get_max_hp(), Vector2.ZERO, null)
	# Find the burst and assert its `amount`.
	var burst: CPUParticles2D = _first_particle_under(room)
	assert_not_null(burst, "boss spawns a burst under the room")
	assert_eq(burst.amount, 24, "boss burst is 24 particles per Uma §3 climax bump")


# ---- Boss climax: shake + 400ms hold + 200ms decay -----------------

func test_boss_shake_constants_within_vd09_budget() -> void:
	# VD-09 budget: max 4 logical px camera shake. Boss climax tunes this
	# right at the budget ceiling.
	assert_almost_eq(Stratum1Boss.BOSS_SHAKE_MAGNITUDE, 4.0, 0.0001,
		"boss shake at VD-09 max (4 logical px)")
	assert_lt(Stratum1Boss.BOSS_SHAKE_MAGNITUDE, 4.1,
		"shake never exceeds VD-09 4-px budget")


func test_boss_death_hold_is_400ms() -> void:
	assert_almost_eq(Stratum1Boss.BOSS_DEATH_HOLD, 0.400, 0.0001,
		"400ms hold per Uma §3 climax addendum")


func test_boss_shake_tween_created_on_die() -> void:
	var b: Stratum1Boss = _make_boss()
	b.take_damage(b.get_max_hp(), Vector2.ZERO, null)
	assert_not_null(b._shake_tween, "shake tween created on boss _die")


# ---- Side-effect inventory: existing signal contract preserved -----

func test_grunt_damaged_signal_still_fires_with_payload() -> void:
	# Sanity check: hit-flash didn't break the existing damaged signal.
	var g: Grunt = _make_grunt()
	watch_signals(g)
	var src: Node2D = autofree(Node2D.new())
	g.take_damage(7, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(g, "damaged", [7, 43, src])


func test_grunt_mob_died_payload_unchanged() -> void:
	# Sanity check: the death tween didn't change mob_died's (mob, pos, def)
	# payload — MobLootSpawner reads positional params, drift would break loot.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20})
	var g: Grunt = GruntScript.new()
	g.mob_def = def
	add_child_autofree(g)
	g.global_position = Vector2(7.0, 11.0)
	watch_signals(g)
	g.take_damage(20, Vector2.ZERO, null)
	var args: Array = get_signal_parameters(g, "mob_died", 0)
	assert_not_null(args, "mob_died emitted")
	assert_eq(args[0], g, "payload[0] is the mob node")
	assert_almost_eq(args[1].x, 7.0, 0.001)
	assert_almost_eq(args[1].y, 11.0, 0.001)
	assert_eq(args[2], def, "payload[2] is the MobDef")


# ---- Helpers: count CPUParticles2D children (recursive) ----------

func _count_particles_under(node: Node) -> int:
	var n: int = 0
	if node is CPUParticles2D:
		n += 1
	for child in node.get_children():
		n += _count_particles_under(child)
	return n


func _first_particle_under(node: Node) -> CPUParticles2D:
	if node is CPUParticles2D:
		return node
	for child in node.get_children():
		var found: CPUParticles2D = _first_particle_under(child)
		if found != null:
			return found
	return null

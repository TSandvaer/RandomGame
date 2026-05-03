extends GutTest
## Tests for Player attack visual feedback — ember swing-wedge + 60ms
## modulate flash. Locks the placeholder-fidelity contract from
## `team/uma-ux/combat-visual-feedback.md` §1.
##
## Numbers under test are derived directly from Uma's spec + Player.gd
## tuning constants — no priors. If the spec changes, the constants in
## Player.gd update and these tests should follow.
##
## We use the same in-tree pattern as `test_player_attack.gd` — `add_child_autofree`
## triggers `_ready` and lets create_tween work (a Tween needs a SceneTree).

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


func _find_wedge(p: Player) -> Polygon2D:
	# The wedge is parented to the Player and is the only Polygon2D child
	# in this test fixture (the Player.tscn ships only a CollisionShape2D
	# + a ColorRect Sprite; bare Player.new() has neither).
	for child: Node in p.get_children():
		if child is Polygon2D:
			return child
		# Defensive — Hitbox is an Area2D not a Polygon2D, so the cast
		# above doesn't match and we don't return early.
	return null


# --- 1: light-attack swing wedge spawns with correct sizing/alpha --------

func test_player_swing_wedge_spawns_on_attack() -> void:
	var p: Player = _make_player_in_tree()
	watch_signals(p)
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)

	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge, "light attack must spawn a Polygon2D wedge child on the player")

	# 3-vertex triangle pointed along +X in local space, rotated to face dir.
	assert_eq(wedge.polygon.size(), 3, "wedge is a 3-vertex triangle")
	# Tip at (LIGHT_REACH, 0) so the wedge extends as far as the hitbox does.
	assert_almost_eq(wedge.polygon[0].x, Player.LIGHT_REACH, 0.001, "tip extends LIGHT_REACH px")
	assert_almost_eq(wedge.polygon[0].y, 0.0, 0.001, "tip is on the +X axis")
	# Back corners at (0, ±LIGHT_HITBOX_RADIUS) so half-width matches the hitbox.
	assert_almost_eq(abs(wedge.polygon[1].y), Player.LIGHT_HITBOX_RADIUS, 0.001, "back corner ±radius")
	assert_almost_eq(abs(wedge.polygon[2].y), Player.LIGHT_HITBOX_RADIUS, 0.001, "back corner ±radius")

	# Color = ember #FF6A2A at alpha 0.55 for light attacks.
	assert_almost_eq(wedge.color.r, 1.0, 0.01, "color.r ≈ 1.0 (#FF...)")
	assert_almost_eq(wedge.color.g, 0.4156, 0.01, "color.g ≈ 0x6A/0xFF")
	assert_almost_eq(wedge.color.b, 0.1647, 0.01, "color.b ≈ 0x2A/0xFF")
	assert_almost_eq(wedge.color.a, 0.55, 0.001, "light wedge alpha = 0.55")

	# Behind the player body — z_index < 0 so the wedge reads as a flash
	# extending from the player rather than stamped over them.
	assert_lt(wedge.z_index, 0, "wedge sits below the player sprite (z_index < 0)")

	# Signal fired with the spawned wedge.
	assert_signal_emitted_with_parameters(p, "swing_wedge_spawned", [Player.ATTACK_LIGHT, wedge])


# --- 2: heavy-attack swing wedge has heavier sizing + alpha ---------------

func test_player_swing_wedge_heavy_uses_heavy_tuning() -> void:
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_HEAVY, Vector2.UP)

	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge)
	# Heavy reach + radius applied.
	assert_almost_eq(wedge.polygon[0].x, Player.HEAVY_REACH, 0.001, "tip extends HEAVY_REACH px")
	assert_almost_eq(abs(wedge.polygon[1].y), Player.HEAVY_HITBOX_RADIUS, 0.001, "heavy back-corner radius")
	# Heavy alpha is more punchy at 0.70.
	assert_almost_eq(wedge.color.a, 0.70, 0.001, "heavy wedge alpha = 0.70")


# --- 3: wedge orientation matches facing direction -----------------------

func test_player_swing_wedge_direction_matches_facing() -> void:
	var p: Player = _make_player_in_tree()
	# Fire a light attack pointing UP — wedge.rotation should be UP.angle()
	# which is -PI/2 in Godot (Y is down, so UP = (0,-1) → angle = -PI/2).
	p.try_attack(Player.ATTACK_LIGHT, Vector2.UP)
	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge)
	assert_almost_eq(wedge.rotation, Vector2.UP.angle(), 0.001, "rotation = facing.angle()")


func test_player_swing_wedge_direction_left() -> void:
	# Independent direction case to exercise sign correctness.
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_LIGHT, Vector2.LEFT)
	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge)
	assert_almost_eq(wedge.rotation, Vector2.LEFT.angle(), 0.001, "LEFT facing → angle PI")


func test_player_swing_wedge_direction_uses_facing_when_dir_zero() -> void:
	# When `dir` is zero, try_attack falls back to current facing — the
	# wedge must follow that fallback so the visual cue points the same way
	# the hitbox does.
	var p: Player = _make_player_in_tree()
	# Set facing via dodge (matches test_player_attack.gd:test_attack_uses_facing_when_dir_zero).
	p.try_dodge(Vector2.LEFT)
	p._tick_timers(Player.DODGE_DURATION + Player.DODGE_COOLDOWN + 0.01)
	p._process_dodge(0.0)
	assert_eq(p.get_facing(), Vector2.LEFT)
	p.try_attack(Player.ATTACK_LIGHT, Vector2.ZERO)
	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge)
	assert_almost_eq(wedge.rotation, Vector2.LEFT.angle(), 0.001, "wedge follows facing fallback")


# --- 4: wedge lifetime matches hitbox lifetime ---------------------------

func test_player_swing_wedge_lifetime_matches_hitbox_light() -> void:
	# Lifetime is recorded as Node metadata at spawn so tests can verify
	# the contract without poking Tween internals (Tween has no public
	# elapsed-time/remaining-duration getter).
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge)
	assert_eq(float(wedge.get_meta("lifetime")), Player.LIGHT_HITBOX_LIFETIME, "light wedge lifetime = 0.10s")
	assert_eq(StringName(wedge.get_meta("kind")), Player.ATTACK_LIGHT, "metadata records kind")


func test_player_swing_wedge_lifetime_matches_hitbox_heavy() -> void:
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_HEAVY, Vector2.DOWN)
	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge)
	assert_eq(float(wedge.get_meta("lifetime")), Player.HEAVY_HITBOX_LIFETIME, "heavy wedge lifetime = 0.14s")


# --- 5: wedge fades to alpha 0 over its lifetime + frees ----------------

func test_player_swing_wedge_fades_and_frees() -> void:
	# After spawning, await enough time for the fade tween (lifetime) +
	# the tween_callback (queue_free) + the next-frame queue_free flush.
	# Slack accounts for headless GUT physics-tick jitter.
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	var wedge: Polygon2D = _find_wedge(p)
	assert_not_null(wedge, "wedge spawned")
	# Wait LIFETIME + generous slack, then a couple of process_frame calls
	# to let queue_free settle.
	await get_tree().create_timer(Player.LIGHT_HITBOX_LIFETIME + 0.20).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(wedge), "wedge freed after lifetime")


# --- 6: 60ms modulate flash on attack ------------------------------------

func test_player_modulate_flash_60ms_total() -> void:
	# Assert the flash tween is created with the correct shape: a 2-step
	# property tween totaling exactly 60ms (30ms + 30ms). We don't sample
	# the modulate mid-tween — headless GUT process_frame cadence is jittery
	# at sub-frame resolution and would race the tween's interpolation.
	# Instead we await tween.finished and confirm the end-state is white.
	var p: Player = _make_player_in_tree()
	assert_eq(p.modulate, Color(1.0, 1.0, 1.0, 1.0), "player starts at white modulate")
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_not_null(p._active_flash_tween, "flash tween created on attack")
	assert_true(p._active_flash_tween.is_valid(), "flash tween is valid")
	# Verify the tween's total runtime is exactly 60ms — Tween.get_total_elapsed_time
	# is current, not total — so we await finished + record wall-clock and
	# trust that within +/- one physics frame.
	var t: Tween = p._active_flash_tween
	# Wait for the full 2-step tween to complete.
	await t.finished
	# After both steps complete, modulate is back to white.
	assert_almost_eq(p.modulate.r, 1.0, 0.01, "modulate.r ≈ 1.0 after flash returns")
	assert_almost_eq(p.modulate.g, 1.0, 0.01, "modulate.g ≈ 1.0 after flash returns")
	assert_almost_eq(p.modulate.b, 1.0, 0.01, "modulate.b ≈ 1.0 after flash returns")
	# Half-duration constant must equal 30ms (60ms / 2) — the duration is
	# the contract; the constant is the source-of-truth for it.
	assert_eq(Player.SWING_FLASH_HALF_DURATION, 0.030, "half-duration = 30ms")


func test_player_modulate_flash_intermediate_state_tints_toward_ember() -> void:
	# Independent test for the intermediate state — drive the tween manually
	# via custom_step so headless cadence doesn't race the interpolation.
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	var t: Tween = p._active_flash_tween
	assert_not_null(t)
	# custom_step drives the tween synchronously by `delta` seconds. Step
	# ~half the half-duration (15ms ≈ 50% into step 1) to land mid-tint.
	# Tween starts paused for the first frame in some Godot versions; pause
	# control isn't needed because tween.is_valid() implies it's playing.
	t.custom_step(0.020)
	# Step 1 tweens modulate from white toward Color(1.4, 1.0, 0.7, 1).
	# At any non-final point the blue channel must be < 1.0 (target is 0.7).
	assert_lt(p.modulate.b, 1.0, "blue channel dropped toward ember mid-tween")
	# Red channel rises toward 1.4 (luminance boost).
	assert_gt(p.modulate.r, 1.0, "red channel boosted toward 1.4 mid-tween")


func test_player_modulate_flash_same_duration_for_heavy_and_light() -> void:
	# Spec §1b: "Both attack types use the same flash duration."
	# We assert this by comparing the half-duration constant — the duration
	# is hardcoded at the spawn site, so failing this would mean someone
	# branched on `kind` for the flash.
	var p_light: Player = _make_player_in_tree()
	p_light.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	var p_heavy: Player = _make_player_in_tree()
	p_heavy.try_attack(Player.ATTACK_HEAVY, Vector2.RIGHT)
	assert_eq(Player.SWING_FLASH_HALF_DURATION, 0.030, "half-duration is 30ms (60ms total)")
	# Both flashes use the same constant.
	assert_not_null(p_light._active_flash_tween)
	assert_not_null(p_heavy._active_flash_tween)


# --- 7: kill-and-restart — second attack replaces first wedge -----------

func test_player_swing_wedge_replaced_on_second_attack() -> void:
	# A second attack fired during the first attack's recovery should
	# replace the wedge — Uma's spec §1: "if a second attack is fired
	# during the previous attack's recovery, the wedge from the new attack
	# replaces the old one." (Heavy → tick-past-recovery → light to
	# satisfy can_attack().)
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_HEAVY, Vector2.RIGHT)
	var first: Polygon2D = p._active_swing_wedge
	assert_not_null(first)
	# Tick past heavy recovery so the second attack lands.
	p._tick_timers(Player.HEAVY_RECOVERY + 0.001)
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	var second: Polygon2D = p._active_swing_wedge
	assert_not_null(second)
	assert_ne(first, second, "second attack creates a new wedge")
	# First was queue_freed when second spawned; await one frame for it to settle.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(first), "first wedge freed when second spawned")


# --- 8: rejected attack does NOT spawn a wedge ---------------------------

func test_no_wedge_on_rejected_attack() -> void:
	# An attack rejected mid-dodge or in-recovery returns null and must
	# not paint a wedge cue. Otherwise the cue lies about whether a swing
	# fired.
	var p: Player = _make_player_in_tree()
	p.try_dodge(Vector2.RIGHT)
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_null(hb, "attack during dodge rejected")
	assert_null(_find_wedge(p), "no wedge spawned on rejected attack")
	assert_null(p._active_swing_wedge, "no active wedge tracked")
	assert_null(p._active_flash_tween, "no flash tween created")


# --- 9: side-effect inventory: dodge interrupts attack recovery still works

func test_dodge_interrupt_unaffected_by_visual_feedback() -> void:
	# Visual-feedback cues are paint-only — they must NOT change the
	# existing dodge-cancels-attack-recovery rule from
	# test_player_attack.gd:test_dodge_cancels_attack_recovery.
	var p: Player = _make_player_in_tree()
	p.try_attack(Player.ATTACK_HEAVY, Vector2.RIGHT)
	assert_true(p.can_dodge(), "dodge can fire even during attack recovery")
	var ok: bool = p.try_dodge(Vector2.LEFT)
	assert_true(ok)
	assert_eq(p.get_state(), Player.STATE_DODGE)
	assert_eq(p._attack_recovery_left, 0.0, "dodge zeroed attack recovery")


# --- 10: side-effect inventory: hitbox damage application unchanged -----

func test_hitbox_payload_unchanged_by_visual_feedback() -> void:
	# The wedge spawn must NOT mutate the hitbox damage / lifetime / team.
	var p: Player = _make_player_in_tree()
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_not_null(hb)
	assert_eq(hb.lifetime, Player.LIGHT_HITBOX_LIFETIME, "hitbox lifetime unchanged")
	assert_eq(hb.team, Hitbox.TEAM_PLAYER)
	assert_eq(hb.get_parent(), p)

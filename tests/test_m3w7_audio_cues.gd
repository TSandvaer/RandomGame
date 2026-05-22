extends GutTest
## M3W-7 paired tests — animation-beat audio-cue wiring.
##
## ClickUp `86c9va3d0`. Covers the load-bearing surfaces of the audio-cue
## wiring shipped on Player + S1 mob roster + Boss:
##
##   1. AudioDirector exposes a public `play_sfx(cue_id)` API.
##   2. The SFX cue_id → resource path map (`SFX_PATHS`) covers every cue
##      the wiring sites reference (zero unknown-cue typos).
##   3. Every shipped SFX asset loads as an AudioStream (the file exists in
##      `audio/sfx/*` and is OGG-Vorbis decodable).
##   4. `play_sfx` advances the round-robin pool index AND records the cue
##      via `get_last_sfx_id`.
##   5. Per-character signal handlers route the right cue:
##        Player.attack_spawned(light)   → SFX_PLAYER_ATTACK_LIGHT
##        Player.attack_spawned(heavy)   → SFX_PLAYER_ATTACK_HEAVY
##        Player.damaged(>0)             → SFX_PLAYER_HIT
##        Player.damaged(0)              → NO SFX (i-frame absorb path)
##        Player.dodge_started           → SFX_PLAYER_DODGE
##        Player.iframes_started         → NO SFX (post-hit grant path —
##                                         AD-05 dodge-whoosh is intentional-
##                                         dodge ONLY, ticket 86c9vbhf1)
##        Grunt.damaged(>0)              → SFX_MOB_HIT
##        Grunt.mob_died                 → SFX_MOB_DIE
##        Grunt.light_telegraph_started  → SFX_ATTACK_TELEGRAPH
##        Grunt.swing_spawned            → SFX_ATTACK_IMPACT
##        Charger.damaged(>0)            → SFX_MOB_HIT
##        Charger.charge_telegraph_started → SFX_ATTACK_TELEGRAPH
##        Shooter.aim_started            → SFX_ATTACK_TELEGRAPH
##        Shooter.projectile_fired       → SFX_ATTACK_IMPACT
##        Stratum1Boss.boss_died         → SFX_BOSS_DIE
##        Stratum1Boss.swing_spawned(melee)         → SFX_ATTACK_IMPACT
##        Stratum1Boss.swing_spawned(slam_telegraph) → SFX_ATTACK_TELEGRAPH
##        Stratum1Boss.swing_spawned(slam_hit)       → SFX_ATTACK_IMPACT
##   6. Boot-time wiring does NOT push_warning (universal warning gate).
##
## **Regression guard contract** (per PR #216 / Priya): if a future PR drops
## a SFX asset, renames a cue, or breaks a signal handler, this file catches
## the regression at CI time before Tess re-soaks. The bug class is "silent
## audio dropout" — failing tests cost a CI run; failing soak costs hours.
##
## Companion to `tests/test_audio_bus_layout.gd` — that file pins the bus
## structure (SFX bus must exist at -6 dB); this file pins the per-cue
## wiring on top of it.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const AudioDirectorScript: Script = preload("res://scripts/audio/AudioDirector.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	# Reset the AudioDirector's round-robin index + last-cue-id so tests get a
	# known starting position. This is the test-only hook documented on the
	# AudioDirector — production code never calls it.
	var ad: Node = _get_audio_director()
	if ad != null and ad.has_method("reset_sfx_pool_index_for_test"):
		ad.reset_sfx_pool_index_for_test()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------

func _get_audio_director() -> Node:
	return get_tree().root.get_node_or_null("AudioDirector")


# ---- Section 1: AudioDirector public API exists -----------------------

func test_audio_director_autoload_registered() -> void:
	var ad: Node = _get_audio_director()
	assert_not_null(ad, "AudioDirector autoload is registered at /root/AudioDirector")


func test_play_sfx_method_exists() -> void:
	var ad: Node = _get_audio_director()
	assert_true(ad.has_method("play_sfx"),
		"AudioDirector exposes `play_sfx(cue_id)` for M3W-7 signal handlers")


func test_get_last_sfx_id_method_exists() -> void:
	var ad: Node = _get_audio_director()
	assert_true(ad.has_method("get_last_sfx_id"),
		"AudioDirector exposes `get_last_sfx_id()` as paired-test surface")


# ---- Section 2: SFX_PATHS covers every required cue --------------------

func test_sfx_paths_covers_every_required_cue() -> void:
	# Every cue id the wiring sites use must be present in SFX_PATHS. If a
	# future PR adds a cue id without updating the map, this catches it.
	var required: Array[StringName] = [
		&"sfx-player-attack-light",
		&"sfx-player-attack-heavy",
		&"sfx-player-hit",
		&"sfx-player-dodge",
		&"sfx-mob-hit",
		&"sfx-mob-die",
		&"sfx-boss-die",
		&"sfx-attack-telegraph",
		&"sfx-attack-impact",
	]
	for cue_id in required:
		assert_true(AudioDirectorScript.SFX_PATHS.has(cue_id),
			"SFX_PATHS missing cue_id '%s' — wiring sites will hit UNKNOWN trace" % cue_id)


# ---- Section 3: Every shipped SFX asset loads --------------------------

func test_every_sfx_asset_loads_as_audio_stream() -> void:
	# Direct ResourceLoader.load() of each path must succeed. This is the
	# HTML5-safety analog of the STARTER_ITEM_PATHS rule (per
	# `.claude/docs/html5-export.md`) — the resource cache always resolves
	# `load()` of a known res:// path, even when DirAccess recursion is
	# broken on packed pcks.
	for cue_id in AudioDirectorScript.SFX_PATHS:
		var path: String = AudioDirectorScript.SFX_PATHS[cue_id]
		var stream: Resource = load(path)
		assert_not_null(stream,
			"%s loads as a Resource at %s" % [cue_id, path])
		assert_true(stream is AudioStream,
			"%s is an AudioStream subclass (got %s)" % [cue_id, stream.get_class()])


# ---- Section 4: play_sfx advances pool index + records last id --------

func test_play_sfx_known_id_records_last_sfx_id() -> void:
	var ad: Node = _get_audio_director()
	# Pre-condition — fresh reset.
	assert_eq(ad.get_last_sfx_id(), StringName(""),
		"reset_sfx_pool_index_for_test clears last_sfx_id")
	ad.play_sfx(&"sfx-mob-hit")
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-mob-hit"),
		"play_sfx records last_sfx_id")


func test_play_sfx_unknown_id_is_safe_noop() -> void:
	# Unknown cue id must NOT crash + must NOT push_warning (warning would
	# fail the NoWarningGuard). Cue-not-found is a soft-fail combat-trace.
	var ad: Node = _get_audio_director()
	ad.play_sfx(&"this-cue-does-not-exist")
	# last_sfx_id stays the empty-string sentinel since no cue was played.
	assert_eq(ad.get_last_sfx_id(), StringName(""),
		"play_sfx(unknown) does not record a cue id")


func test_play_sfx_pool_size_is_positive() -> void:
	var ad: Node = _get_audio_director()
	var pool_size: int = ad.get_sfx_pool_size()
	assert_gt(pool_size, 0, "AudioDirector built a non-empty SFX pool")
	assert_eq(pool_size, AudioDirectorScript.SFX_POOL_SIZE,
		"pool size equals SFX_POOL_SIZE const")


# ---- Section 5: Per-character signal handler routing ------------------
# These tests don't need a full Player/mob — they emit the signal directly
# and assert the AudioDirector saw the right cue id. The wiring is just
# Signal.connect + a tiny handler, so this is a unit test of the contract,
# not an integration test.

func test_player_attack_spawned_light_plays_attack_light_cue() -> void:
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	# Ready ran — signal is connected.
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.attack_spawned.emit(Player.ATTACK_LIGHT, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-player-attack-light"),
		"Player.attack_spawned(light) routes to sfx-player-attack-light")


func test_player_attack_spawned_heavy_plays_attack_heavy_cue() -> void:
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.attack_spawned.emit(Player.ATTACK_HEAVY, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-player-attack-heavy"),
		"Player.attack_spawned(heavy) routes to sfx-player-attack-heavy")


func test_player_damaged_positive_plays_player_hit_cue() -> void:
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.damaged.emit(3, 47, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-player-hit"),
		"Player.damaged(>0) routes to sfx-player-hit")


func test_player_damaged_zero_is_silent() -> void:
	# Damaged(0) fires from the i-frame / post-hit-iframes blocked path —
	# audio MUST NOT play (no hit landed). Pin the contract so a future
	# refactor that removes the `amount <= 0` guard regresses here.
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.damaged.emit(0, 50, null)
	assert_eq(ad.get_last_sfx_id(), StringName(""),
		"Player.damaged(0) is silent (no cue played)")


func test_player_dodge_started_plays_dodge_cue() -> void:
	# Ticket 86c9vbhf1 — dodge-whoosh routes off `dodge_started`, NOT
	# `iframes_started`. Post-fix contract: only an intentional `try_dodge`
	# fires the cue. See `test_player_iframes_started_alone_is_silent` below
	# for the negative-control covering the take_damage post-hit-iframe path.
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.dodge_started.emit()
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-player-dodge"),
		"Player.dodge_started routes to sfx-player-dodge (per AD-05)")


func test_player_iframes_started_alone_is_silent() -> void:
	# REGRESSION GUARD — ticket 86c9vbhf1 / PR #278 review.
	# `iframes_started` ALSO fires from `take_damage` (post-hit invuln grant,
	# Uma's AC4 Room 05 balance pin §3.B). If a future refactor re-binds the
	# audio handler back to `iframes_started`, every damage taken produces a
	# dodge-whoosh — the bug PR #278 shipped. AD-05 is "intentional dodge
	# ONLY"; bare `iframes_started.emit()` (without the paired `dodge_started`
	# emit that `try_dodge` performs) must NOT play `sfx-player-dodge`.
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.iframes_started.emit()
	assert_eq(ad.get_last_sfx_id(), StringName(""),
		"Player.iframes_started alone (post-hit-iframe-grant path) is silent — " +
		"REGRESSION GUARD: dodge-whoosh fires ONLY from dodge_started per " +
		"audio-direction.md §AD-05 and ticket 86c9vbhf1")


func test_grunt_damaged_plays_mob_hit() -> void:
	var g: Grunt = preload("res://scripts/mobs/Grunt.gd").new()
	add_child_autofree(g)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	g.damaged.emit(3, 47, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-mob-hit"),
		"Grunt.damaged(>0) routes to sfx-mob-hit")


func test_grunt_mob_died_plays_mob_die() -> void:
	var g: Grunt = preload("res://scripts/mobs/Grunt.gd").new()
	add_child_autofree(g)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	g.mob_died.emit(g, Vector2.ZERO, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-mob-die"),
		"Grunt.mob_died routes to sfx-mob-die")


func test_grunt_light_telegraph_plays_telegraph_cue() -> void:
	var g: Grunt = preload("res://scripts/mobs/Grunt.gd").new()
	add_child_autofree(g)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	g.light_telegraph_started.emit()
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-telegraph"),
		"Grunt.light_telegraph_started routes to sfx-attack-telegraph")


func test_grunt_swing_spawned_plays_impact_cue() -> void:
	var g: Grunt = preload("res://scripts/mobs/Grunt.gd").new()
	add_child_autofree(g)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	g.swing_spawned.emit(Grunt.SWING_KIND_LIGHT, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-impact"),
		"Grunt.swing_spawned routes to sfx-attack-impact")


func test_charger_damaged_plays_mob_hit() -> void:
	var c: Charger = preload("res://scripts/mobs/Charger.gd").new()
	add_child_autofree(c)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	c.damaged.emit(3, 27, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-mob-hit"),
		"Charger.damaged(>0) routes to sfx-mob-hit")


func test_charger_charge_telegraph_plays_telegraph_cue() -> void:
	var c: Charger = preload("res://scripts/mobs/Charger.gd").new()
	add_child_autofree(c)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	c.charge_telegraph_started.emit(Vector2.RIGHT)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-telegraph"),
		"Charger.charge_telegraph_started routes to sfx-attack-telegraph")


func test_charger_charge_hit_spawned_plays_impact_cue() -> void:
	var c: Charger = preload("res://scripts/mobs/Charger.gd").new()
	add_child_autofree(c)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	c.charge_hit_spawned.emit(null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-impact"),
		"Charger.charge_hit_spawned routes to sfx-attack-impact")


func test_shooter_aim_started_plays_telegraph_cue() -> void:
	var s: Shooter = preload("res://scripts/mobs/Shooter.gd").new()
	add_child_autofree(s)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	s.aim_started.emit(Vector2.RIGHT)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-telegraph"),
		"Shooter.aim_started routes to sfx-attack-telegraph")


func test_shooter_projectile_fired_plays_impact_cue() -> void:
	var s: Shooter = preload("res://scripts/mobs/Shooter.gd").new()
	add_child_autofree(s)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	s.projectile_fired.emit(null, Vector2.RIGHT)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-impact"),
		"Shooter.projectile_fired routes to sfx-attack-impact")


func test_boss_damaged_plays_mob_hit() -> void:
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	b.damaged.emit(6, 594, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-mob-hit"),
		"Stratum1Boss.damaged(>0) routes to sfx-mob-hit")


func test_boss_died_plays_boss_die_not_mob_die() -> void:
	# Boss gets its own cue — heavier, longer than mob-die. Pin so a future
	# refactor doesn't accidentally collapse to sfx-mob-die.
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	b.boss_died.emit(b, Vector2.ZERO, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-boss-die"),
		"Stratum1Boss.boss_died routes to sfx-boss-die (heavier than mob-die)")


func test_boss_swing_spawned_melee_plays_impact() -> void:
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	b.swing_spawned.emit(Stratum1Boss.SWING_KIND_MELEE, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-impact"),
		"Boss melee swing routes to sfx-attack-impact")


func test_boss_swing_spawned_slam_telegraph_plays_telegraph() -> void:
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	b.swing_spawned.emit(Stratum1Boss.SWING_KIND_SLAM_TELEGRAPH, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-telegraph"),
		"Boss slam_telegraph routes to sfx-attack-telegraph (windup, not impact)")


func test_boss_swing_spawned_slam_hit_plays_impact() -> void:
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	b.swing_spawned.emit(Stratum1Boss.SWING_KIND_SLAM_HIT, null)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-attack-impact"),
		"Boss slam_hit routes to sfx-attack-impact (contact, not telegraph)")


# ---- Section 5b: M3-T2-W1-T7 phase-break + boss-wake stings ----------
# Maps to Uma `boss-intro.md` BI-06 (boss-wake stinger) + BI-18 (phase-break
# tritone sting). Wired in `Stratum1Boss._wire_audio_cues`.

func test_boss_woke_plays_boss_wake_stinger() -> void:
	# Uma BI-06: low brass + impact stinger fires once on boss wake
	# (STATE_DORMANT → STATE_IDLE). Cue is `sfx-boss-wake`.
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	b.boss_woke.emit()
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-boss-wake"),
		"Stratum1Boss.boss_woke routes to sfx-boss-wake (Uma BI-06)")


func test_phase_changed_plays_phase_break_sting() -> void:
	# Uma BI-18: tritone tension chord fires once per phase boundary
	# (66% → P2, 33% → P3). Cue is `sfx-phase-break`.
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	var ad: Node = _get_audio_director()
	# Test P2 boundary.
	ad.reset_sfx_pool_index_for_test()
	b.phase_changed.emit(Stratum1Boss.PHASE_2)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-phase-break"),
		"Stratum1Boss.phase_changed(P2) routes to sfx-phase-break (Uma BI-18)")
	# Test P3 boundary as well — handler is phase-agnostic.
	ad.reset_sfx_pool_index_for_test()
	b.phase_changed.emit(Stratum1Boss.PHASE_3)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-phase-break"),
		"Stratum1Boss.phase_changed(P3) routes to sfx-phase-break (Uma BI-18)")


func test_boss_wake_and_phase_break_cues_exist_in_sfx_paths() -> void:
	# Regression guard against the cue-id ↔ SFX_PATHS map drift class. If a
	# future PR renames the cue id without updating the map, this test
	# fails before the silent-trace shows up in soak.
	assert_true(AudioDirectorScript.SFX_PATHS.has(&"sfx-phase-break"),
		"SFX_PATHS contains sfx-phase-break (M3-T2-W1-T7)")
	assert_true(AudioDirectorScript.SFX_PATHS.has(&"sfx-boss-wake"),
		"SFX_PATHS contains sfx-boss-wake (M3-T2-W1-T7)")


# ---- Section 5c: M3-T2-W3-T16b boss-kill horn (Beat F2 cinematic) -----
# Maps to Uma `boss-intro.md` Beat F2 + `audio-direction.md` row
# sfx-boss-kill-horn (AD-23 tester check). Fires from
# `Stratum1BossRoom._play_t16_cinematic_climax(death_position)` (Drew's
# T16a wiring); paired-test surface here pins:
#   1. Cue id matches the constant Drew's wiring references (producer ↔
#      consumer string contract — same shape as the team-constants drift
#      pin in `.claude/docs/test-conventions.md`).
#   2. SFX_PATHS has the cue → resource map entry.
#   3. The shipped OGG loads as an AudioStream (asset exists + decodes).
#   4. Cue duration matches the 0.9 s Uma F2 spec (loose tolerance for
#      OGG encoder padding — asserts within 0.85 .. 0.95 s window).
#   5. `play_sfx(SFX_BOSS_KILL_HORN)` records `last_sfx_id` correctly
#      (i.e. the cue is dispatched, not silently hit the UNKNOWN no-op).
#
# **Regression guard contract:** if a future PR drops the OGG asset, renames
# the cue id, breaks the SFX_PATHS entry, or alters the composer-emitted
# duration outside the F2 window, this file catches the regression at CI
# time. The bug class is "boss-kill horn no longer fires / wrong cue / wrong
# duration" — invisible to existing tests (which were authored before this
# cue existed) and otherwise only catchable by Sponsor's interactive soak.

func test_sfx_boss_kill_horn_cue_id_constant_matches_wiring_string() -> void:
	# Drew's `Stratum1BossRoom.gd::T16_HORN_SFX_CUE_ID` is the consumer-side
	# StringName. The constant value MUST equal the producer-side
	# `AudioDirector.SFX_BOSS_KILL_HORN` StringName, or play_sfx hits the
	# UNKNOWN safe-no-op branch and the horn is silent. Pin both sides.
	assert_eq(String(AudioDirectorScript.SFX_BOSS_KILL_HORN),
		"sfx-boss-kill-horn",
		"AudioDirector.SFX_BOSS_KILL_HORN string == 'sfx-boss-kill-horn'")
	# Cross-check Drew's consumer-side string. Stratum1BossRoom defines
	# `T16_HORN_SFX_CUE_ID` (StringName); they must agree.
	var BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")
	assert_eq(String(BossRoomScript.T16_HORN_SFX_CUE_ID),
		"sfx-boss-kill-horn",
		"Stratum1BossRoom.T16_HORN_SFX_CUE_ID matches the producer-side cue id")


func test_sfx_boss_kill_horn_in_sfx_paths() -> void:
	# Regression guard against the cue-id ↔ SFX_PATHS map drift class.
	assert_true(AudioDirectorScript.SFX_PATHS.has(&"sfx-boss-kill-horn"),
		"SFX_PATHS contains sfx-boss-kill-horn (M3-T2-W3-T16b)")
	var path: String = AudioDirectorScript.SFX_PATHS[&"sfx-boss-kill-horn"]
	assert_eq(path, "res://audio/sfx/mobs/sfx-boss-kill-horn.ogg",
		"SFX_PATHS entry points to audio/sfx/mobs/ (audio-direction.md §4 folder rule)")


func test_sfx_boss_kill_horn_asset_loads_and_duration_matches_spec() -> void:
	# Asset exists, decodes as AudioStream, AND duration is within the
	# Uma F2 window (0.9 s ± 50 ms tolerance for OGG encoder framing).
	# A future re-encode that drifts the duration outside the window
	# would silently shift the cinematic timing — the horn-tail-into-
	# silence-at-T+1.2s contract depends on the 0.9 s duration landing.
	var path: String = AudioDirectorScript.SFX_PATHS[&"sfx-boss-kill-horn"]
	var stream: Resource = load(path)
	assert_not_null(stream,
		"sfx-boss-kill-horn loads at %s" % path)
	assert_true(stream is AudioStream,
		"sfx-boss-kill-horn is an AudioStream subclass (got %s)" % stream.get_class())
	var length_s: float = (stream as AudioStream).get_length()
	assert_between(length_s, 0.85, 0.95,
		"sfx-boss-kill-horn duration %.3f s within F2 spec window (0.85..0.95)" % length_s)


func test_play_sfx_boss_kill_horn_records_last_sfx_id() -> void:
	# Pin the producer-side dispatch — play_sfx(SFX_BOSS_KILL_HORN) is the
	# only thing Drew's `_play_t16_cinematic_climax` does for audio; assert
	# the cue is recognized, not silently dispatched into the UNKNOWN branch.
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	ad.play_sfx(AudioDirectorScript.SFX_BOSS_KILL_HORN)
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-boss-kill-horn"),
		"play_sfx(SFX_BOSS_KILL_HORN) records last_sfx_id (Beat F2 cinematic horn)")


# ---- Section 6: Wiring is idempotent (re-`_ready` doesn't double-connect)

func test_grunt_re_ready_does_not_double_connect() -> void:
	# `_ready` runs once per add_to_tree, but tests that re-_ready a mob (or
	# manually call `_wire_audio_cues` twice) shouldn't double-fire the cue.
	# We assert the connection count stays at 1 across re-wires.
	var g: Grunt = preload("res://scripts/mobs/Grunt.gd").new()
	add_child_autofree(g)
	# Initial _ready connected the cues (count = 1). Calling _wire_audio_cues
	# again is the test seam — idempotent guard.
	g._wire_audio_cues()
	g._wire_audio_cues()
	assert_eq(g.damaged.get_connections().size(), 1,
		"damaged signal has exactly 1 audio handler after triple-wire")
	assert_eq(g.mob_died.get_connections().size(), 1,
		"mob_died signal has exactly 1 audio handler after triple-wire")


func test_boss_wake_and_phase_break_wiring_idempotent_on_triple_wire() -> void:
	# Triple-wire guard for the M3-T2-W1-T7 additions. If `_wire_audio_cues`
	# is not idempotent on `phase_changed` / `boss_woke`, every re-wire stacks
	# a handler and a single phase boundary plays the cue N times. The
	# `is_connected` guards inside `_wire_audio_cues` are the structural
	# fix; this test pins them.
	var b: Stratum1Boss = preload("res://scripts/mobs/Stratum1Boss.gd").new()
	add_child_autofree(b)
	b._wire_audio_cues()
	b._wire_audio_cues()
	assert_eq(b.phase_changed.get_connections().size(), 1,
		"phase_changed has exactly 1 audio handler after triple-wire")
	assert_eq(b.boss_woke.get_connections().size(), 1,
		"boss_woke has exactly 1 audio handler after triple-wire")

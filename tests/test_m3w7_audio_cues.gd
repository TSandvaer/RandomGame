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
##        Player.iframes_started         → SFX_PLAYER_DODGE
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


func test_player_iframes_started_plays_dodge_cue() -> void:
	var player: Player = preload("res://scripts/player/Player.gd").new()
	add_child_autofree(player)
	var ad: Node = _get_audio_director()
	ad.reset_sfx_pool_index_for_test()
	player.iframes_started.emit()
	assert_eq(ad.get_last_sfx_id(), StringName("sfx-player-dodge"),
		"Player.iframes_started routes to sfx-player-dodge")


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

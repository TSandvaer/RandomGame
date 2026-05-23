extends GutTest
## S1 boss-room audio entry-trigger integration — M3-T2-W1-T1 (`86c9wjxzh`).
##
## Asserts that:
##   1. `AudioDirector.crossfade_to_boss_stratum1(fade_ms)` exists with S2-mirror
##      semantics + idempotence + role-swap on finalize.
##   2. `mus-boss-stratum1.ogg` exists at `res://audio/music/stratum1/` and
##      loads as an `AudioStream`.
##   3. `Stratum1BossRoom.entry_sequence_completed` is wired to fire the
##      crossfade (idempotent on triple-wire).
##   4. Calling the crossfade lands `STREAM_PATH_S1_BOSS` on
##      `_last_bgm_path` and the active BGM player owns the new stream
##      after the role-swap completes.
##   5. The crossfade honors Uma's UNIQUE per-stratum boss-music decision —
##      S1 ≠ S2 (DECISIONS.md 2026-05-15).
##
## **Headless caveat:** same as `test_s2_audio_triggers.gd` — AudioServer is
## initialized but no audible playback occurs. The audible verification is
## in the HTML5 release-build Self-Test Report on the PR.
##
## **Regression guard contract** (per PR #216 / Priya): if a future PR drops
## the wiring from `Stratum1BossRoom._ready`, deletes the crossfade method,
## or removes the OGG asset, this file catches the regression at CI before
## Sponsor soaks. The bug class is "boss-room enters silent" — caught by
## stream-identity assertions and the wiring connection-count assertion.
##
## Companion to `tests/integration/test_s2_audio_triggers.gd` — that file
## pins the S2 transition cues; this file pins the S1 boss-room crossfade.

const STREAM_PATH_S1_BOSS: String = "res://audio/music/stratum1/mus-boss-stratum1.ogg"
const STREAM_PATH_S2_BOSS: String = "res://audio/music/stratum2/mus-boss-stratum2.ogg"

# ---- Helpers ----------------------------------------------------------


func _audio_director() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AudioDirector")


func _reset_audio_director() -> void:
	var ad: Node = _audio_director()
	if ad == null:
		return
	if ad.has_method("stop_all_music"):
		ad.stop_all_music(1)
	if ad.has_method("complete_pending_fades_for_test"):
		ad.complete_pending_fades_for_test()


func before_each() -> void:
	_reset_audio_director()


# ---- AudioDirector S1 boss API contract -------------------------------


func test_audio_director_exposes_crossfade_to_boss_stratum1() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad, "AudioDirector autoload must be registered")
	assert_true(
		ad.has_method("crossfade_to_boss_stratum1"),
		(
			"AudioDirector must expose crossfade_to_boss_stratum1() — "
			+ "the M3-T2-W1-T1 wiring contract. Without this method the "
			+ "Stratum1BossRoom._on_entry_sequence_completed_audio handler "
			+ "silently no-ops and the boss room enters silent."
		)
	)


func test_mus_boss_stratum1_asset_loads() -> void:
	# Direct ResourceLoader.load() of the OGG must succeed. This is the
	# HTML5-safety analog of the STARTER_ITEM_PATHS rule (per
	# `.claude/docs/html5-export.md`) — the resource cache always resolves
	# `load()` of a known res:// path even when DirAccess recursion is
	# broken on packed pcks. If the composer ships a missing/corrupt asset
	# this test fails immediately at CI time, BEFORE Sponsor's HTML5 soak.
	var stream: Resource = load(STREAM_PATH_S1_BOSS)
	assert_not_null(stream, "mus-boss-stratum1.ogg must load at %s" % STREAM_PATH_S1_BOSS)
	assert_true(
		stream is AudioStream,
		"mus-boss-stratum1.ogg must be an AudioStream subclass (got %s)" % stream.get_class()
	)


func test_crossfade_to_boss_stratum1_loads_correct_stream() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad)
	# Pre-fight there's no S1 BGM playing — start from a clean stop.
	ad.stop_all_music(1)
	ad.complete_pending_fades_for_test()
	ad.crossfade_to_boss_stratum1(50)
	ad.complete_pending_fades_for_test()
	assert_eq(
		ad.get_last_bgm_path(),
		STREAM_PATH_S1_BOSS,
		"crossfade_to_boss_stratum1 must target mus-boss-stratum1.ogg"
	)


func test_crossfade_to_boss_stratum1_is_unique_not_s2_reuse() -> void:
	# Honors Uma's DECISIONS.md 2026-05-15 entry — S1 boss room plays a
	# DIFFERENT cue than S2 boss room. Belt-and-suspenders against a
	# future regression that points the constant at the S2 asset.
	var ad: Node = _audio_director()
	ad.crossfade_to_boss_stratum1(1)
	ad.complete_pending_fades_for_test()
	assert_ne(
		ad.get_last_bgm_path(),
		STREAM_PATH_S2_BOSS,
		"S1 boss room MUST play unique S1 music (DECISIONS.md 2026-05-15)"
	)
	assert_eq(
		ad.get_last_bgm_path(),
		STREAM_PATH_S1_BOSS,
		"S1 boss room plays mus-boss-stratum1, not mus-boss-stratum2"
	)


func test_crossfade_to_boss_stratum1_leaves_bgm_player_owning_new_stream() -> void:
	# After the role-swap the active BGM player should own the boss stream.
	# Same shape as the S2 test for parity.
	var ad: Node = _audio_director()
	ad.crossfade_to_boss_stratum1(1)
	ad.complete_pending_fades_for_test()
	var active_player: AudioStreamPlayer = ad.get_bgm_player()
	assert_not_null(active_player)
	assert_not_null(active_player.stream)
	assert_eq(
		active_player.stream.resource_path,
		STREAM_PATH_S1_BOSS,
		"After crossfade, the active BGM player owns the S1 boss stream"
	)
	assert_eq(active_player.bus, "BGM", "S1 boss music routes to the BGM bus")


func test_crossfade_to_boss_stratum1_is_idempotent() -> void:
	# A second call while the same stream is already playing must NOT
	# swap the stream. Same shape as `test_play_stratum2_bgm_is_idempotent`.
	var ad: Node = _audio_director()
	ad.crossfade_to_boss_stratum1(1)
	ad.complete_pending_fades_for_test()
	var stream_before: AudioStream = ad.get_bgm_player().stream
	ad.crossfade_to_boss_stratum1(1)
	var stream_after: AudioStream = ad.get_bgm_player().stream
	assert_eq(
		stream_before, stream_after, "Repeated crossfade_to_boss_stratum1 calls must not re-swap"
	)


# ---- Stratum1BossRoom wiring ------------------------------------------


func _make_boss_room() -> Stratum1BossRoom:
	# Constructs a boss room scene without the real boss instance, so the
	# entry-sequence trigger is the focused surface. The deferred
	# `_assemble_room_fixtures` will skip auto-fire (gated on _boss != null).
	var room: Stratum1BossRoom = Stratum1BossRoom.new()
	# Disable the boss-spawn path to keep this test focused on the signal
	# wiring — empty boss_scene_path makes `_spawn_boss` fail loudly which
	# we don't want; we just override the boss right after _ready so it's
	# present but inert.
	room.boss_scene_path = "res://scenes/mobs/Stratum1Boss.tscn"
	room.boss_mob_def_path = ""
	return room


func test_stratum1_boss_room_wires_entry_sequence_completed_to_audio() -> void:
	# The room's _ready must subscribe a handler to entry_sequence_completed
	# that drives the BGM crossfade. We assert the connection count, not
	# the method identity — the connection IS the contract.
	var room: Stratum1BossRoom = _make_boss_room()
	add_child_autofree(room)
	# Connection count must be ≥ 1 (the audio handler). The internal
	# `_complete_entry_sequence` connects the SceneTreeTimer's timeout
	# but NOT the room's own signal; the only subscriber of
	# `entry_sequence_completed` after _ready is the audio handler.
	# (Tests may add their own subscribers; we assert ≥ 1.)
	var connections: Array = room.entry_sequence_completed.get_connections()
	assert_gte(
		connections.size(),
		1,
		(
			"Stratum1BossRoom._ready must wire entry_sequence_completed to "
			+ "the audio handler. Found %d connections." % connections.size()
		)
	)


func test_stratum1_boss_room_audio_wiring_is_idempotent() -> void:
	# Triple-wire guard. The room's _wire_audio_cues should be safe to
	# call repeatedly (e.g. from tests that re-wire after _ready) without
	# stacking handlers — otherwise the crossfade fires N times per
	# entry-sequence-completed emission.
	var room: Stratum1BossRoom = _make_boss_room()
	add_child_autofree(room)
	# _ready already called _wire_audio_cues. Call it twice more — the
	# is_connected guard inside should prevent duplicate connections.
	room._wire_audio_cues()
	room._wire_audio_cues()
	var connections: Array = room.entry_sequence_completed.get_connections()
	# Find audio-handler connections specifically (matches our method name).
	var audio_handler_count: int = 0
	for c in connections:
		if c.has("callable") and c["callable"].get_method() == "_on_entry_sequence_completed_audio":
			audio_handler_count += 1
	assert_eq(
		audio_handler_count,
		1,
		(
			"_on_entry_sequence_completed_audio is connected exactly once "
			+ "after triple-wire (got %d connections)" % audio_handler_count
		)
	)


func test_entry_sequence_completed_fires_crossfade() -> void:
	# The integration end-to-end: emitting entry_sequence_completed on a
	# boss room must result in `crossfade_to_boss_stratum1` having been
	# called against AudioDirector. We assert the side-effect: _last_bgm_path
	# transitions to STREAM_PATH_S1_BOSS.
	var ad: Node = _audio_director()
	assert_not_null(ad)
	# Clean state — make sure no prior test left the boss stream on
	# _last_bgm_path (otherwise the assertion is vacuously satisfied).
	ad.stop_all_music(1)
	ad.complete_pending_fades_for_test()
	assert_ne(
		ad.get_last_bgm_path(), STREAM_PATH_S1_BOSS, "sanity: pre-condition cleared S1 boss path"
	)
	# Spin up a room and fire the signal directly (not via the timer —
	# tests don't simulate wall-clock waits for the 1.8 s entry sequence).
	var room: Stratum1BossRoom = _make_boss_room()
	add_child_autofree(room)
	# Drive completion through the test-only hook — same path that the
	# 1.8 s timer would take in production. This emits the signal which
	# fires the audio handler.
	room.complete_entry_sequence_for_test()
	# Drain the fade tween so _last_bgm_path is observable as the final
	# state, not mid-transition.
	ad.complete_pending_fades_for_test()
	assert_eq(
		ad.get_last_bgm_path(),
		STREAM_PATH_S1_BOSS,
		(
			"entry_sequence_completed must result in S1 boss BGM crossfade "
			+ "(got _last_bgm_path=%s)" % ad.get_last_bgm_path()
		)
	)

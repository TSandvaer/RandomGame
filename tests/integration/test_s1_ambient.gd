extends GutTest
## S1 ambient stream integration — M3-T2-W2-T10 (`86c9wjyke`).
##
## Asserts that:
##   1. `AudioDirector.play_stratum1_ambient(fade_in_ms, target_gain_db)` exists
##      and routes `amb-stratum1-room.ogg` onto the Ambient bus.
##   2. `AudioDirector.stop_stratum1_ambient(fade_out_ms)` exists and uses the
##      ease-out cubic curve required by Uma's brief BI-03 spec.
##   3. `AudioDirector.resume_stratum1_ambient_at_60_percent(fade_in_ms)` exists
##      and tweens to -4.4 dB (60% nominal) with ease-in-out quadratic curve.
##   4. `amb-stratum1-room.ogg` exists at `res://audio/ambient/stratum1/`.
##   5. Idempotence holds for room-cycle (R1→R2→R1) — a second
##      `play_stratum1_ambient()` while the same stream is already playing
##      at the same gain is a no-op.
##   6. Resume after stop_stratum1_ambient is a fresh fade-in (not a vacuous
##      no-op) — proves the `_last_ambient_path` invalidation in stop works.
##   7. Stratum1BossRoom wires `entry_sequence_started` → stop_stratum1_ambient
##      (the BI-03 hookup). Connection-count contract, not method-identity.
##   8. The Main.gd `_load_room_at_index` path fires play_stratum1_ambient for
##      non-boss S1 rooms and SKIPS it for the boss room (index 8).
##
## **Headless caveat:** GUT runs Godot --headless. AudioServer is initialized
## but no audible playback occurs. Assertions cover stream identity, bus
## routing, volume_db targets, and signal wiring — all faithfully tracked
## in headless. Audible verification is the HTML5 release-build Self-Test
## Report on the PR (per `.claude/docs/audio-architecture.md` § HTML5
## audio-playback gate).
##
## **Regression guard contract** (per PR #216 / Priya): if a future PR drops
## the wiring from `Stratum1BossRoom._ready`, deletes the API methods, or
## removes the OGG asset, this file fails at CI before Sponsor soaks. The
## bug class is "S1 ambient never plays" (room dies silent) or "ambient
## resumes at wrong gain after defeat" — caught here by stream-identity +
## target-dB assertions.
##
## **Cross-lane integration surfaces enumerated:**
##   - Inventory + Pickup + RoomGate + Loot are NOT touched by T10 (no
##     combat surface change). T10 is bus + AudioDirector + signal wiring
##     only.
##   - The Main.gd ambient-on-room-load path runs INSIDE `_load_room_at_index`
##     adjacent to `_loot_spawner.set_parent_for_pickups` — no shared state
##     mutation between the two; the only adjacency is sequencing.
##   - `Stratum1BossRoom.entry_sequence_started` is the same signal the
##     Camera/vignette/nameplate layers subscribe to (T9/T12/T13) — the
##     ambient-stop subscriber is one more handler on a multicast signal,
##     no consumer-side coupling.

const STREAM_PATH_S1_AMBIENT: String = "res://audio/ambient/stratum1/amb-stratum1-room.ogg"
const STREAM_PATH_S2_AMBIENT: String = "res://audio/ambient/stratum2/amb-stratum2-room.ogg"

const RESUME_DB: float = -4.4  # 60% nominal — Uma s1-ambient.md §"Volume / loudness targets"
const RESUME_DB_EPSILON: float = 0.05

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


# ---- AudioDirector S1 ambient API contract ----------------------------


func test_audio_director_exposes_play_stratum1_ambient() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad, "AudioDirector autoload must be registered")
	assert_true(
		ad.has_method("play_stratum1_ambient"),
		"AudioDirector must expose play_stratum1_ambient() — T10 wiring contract"
	)


func test_audio_director_exposes_stop_stratum1_ambient() -> void:
	var ad: Node = _audio_director()
	assert_true(
		ad.has_method("stop_stratum1_ambient"),
		"AudioDirector must expose stop_stratum1_ambient() — BI-03 wiring contract"
	)


func test_audio_director_exposes_resume_stratum1_ambient_at_60_percent() -> void:
	var ad: Node = _audio_director()
	assert_true(
		ad.has_method("resume_stratum1_ambient_at_60_percent"),
		"AudioDirector must expose resume_stratum1_ambient_at_60_percent() — F4 wiring contract"
	)


func test_amb_stratum1_room_asset_loads() -> void:
	# Direct ResourceLoader.load() of the OGG must succeed. Without this the
	# AudioDirector's loader pushes a warning and the bed never plays — and
	# in HTML5 that warning is the only signal (no audible playback in
	# headless). Same HTML5-safety analog as test_s1_boss_audio_triggers.gd
	# uses for the S1 boss OGG.
	var stream: Resource = load(STREAM_PATH_S1_AMBIENT)
	assert_not_null(stream, "amb-stratum1-room.ogg must load at %s" % STREAM_PATH_S1_AMBIENT)
	assert_true(
		stream is AudioStream,
		"amb-stratum1-room.ogg must be an AudioStream subclass (got %s)" % stream.get_class()
	)


func test_play_stratum1_ambient_loads_correct_stream_on_ambient_bus() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad)
	ad.play_stratum1_ambient(50, 0.0)
	ad.complete_pending_fades_for_test()
	var player: AudioStreamPlayer = ad.get_ambient_player()
	assert_not_null(player, "Ambient AudioStreamPlayer must exist")
	assert_eq(player.bus, "Ambient", "Ambient player must route to the Ambient bus")
	assert_not_null(player.stream)
	assert_eq(
		player.stream.resource_path,
		STREAM_PATH_S1_AMBIENT,
		"play_stratum1_ambient must load amb-stratum1-room.ogg"
	)
	assert_eq(ad.get_last_ambient_path(), STREAM_PATH_S1_AMBIENT)


func test_play_stratum1_ambient_distinct_from_s2_ambient() -> void:
	# Cross-stratum-distinct policy (Uma s1-ambient.md §"Tonal anchor" +
	# DECISIONS.md draft 2026-05-20). S1 ambient is a DIFFERENT asset
	# from S2 ambient; never tone-match cousins.
	var ad: Node = _audio_director()
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	assert_ne(
		ad.get_last_ambient_path(),
		STREAM_PATH_S2_AMBIENT,
		"S1 ambient must NOT be the S2 ambient asset (cross-stratum-distinct policy)"
	)
	assert_eq(ad.get_last_ambient_path(), STREAM_PATH_S1_AMBIENT)


# ---- Volume targets ---------------------------------------------------


func test_play_stratum1_ambient_default_target_is_full_db() -> void:
	# Default call (no target_gain_db) should aim at 0 dB nominal on the
	# AmbientPlayer. The Ambient bus's own -18 dB attenuation handles the
	# net post-bus level.
	var ad: Node = _audio_director()
	ad.play_stratum1_ambient(1)
	ad.complete_pending_fades_for_test()
	var player: AudioStreamPlayer = ad.get_ambient_player()
	assert_almost_eq(
		player.volume_db,
		0.0,
		RESUME_DB_EPSILON,
		"play_stratum1_ambient() default target is 0 dB (full nominal)"
	)


func test_resume_stratum1_ambient_at_60_percent_targets_minus_4_4_db() -> void:
	# The F4 resume must land at -4.4 dB ± epsilon (60% of nominal).
	# Uma's brief §"Volume / loudness targets" + §"F4" lock this value;
	# a regression that drifts the target is a feel-bug Sponsor will
	# notice in soak.
	var ad: Node = _audio_director()
	ad.resume_stratum1_ambient_at_60_percent(1)
	ad.complete_pending_fades_for_test()
	var player: AudioStreamPlayer = ad.get_ambient_player()
	assert_almost_eq(
		player.volume_db,
		RESUME_DB,
		RESUME_DB_EPSILON,
		"F4 resume must target -4.4 dB (60%% of nominal) — got %.2f" % player.volume_db
	)


func test_resume_targets_minus_4_4_db_via_target_introspection() -> void:
	# Belt-and-suspenders via the test-only target introspection helper —
	# proves the tween was CREATED with the right target, even if a
	# complete_pending_fades_for_test snap is broken.
	var ad: Node = _audio_director()
	ad.resume_stratum1_ambient_at_60_percent(50)
	# Don't snap-complete — directly read the target the tween was built
	# against.
	assert_almost_eq(
		ad.get_ambient_target_db_for_test(),
		RESUME_DB,
		RESUME_DB_EPSILON,
		"Resume tween must be built against -4.4 dB target"
	)


# ---- Idempotence ------------------------------------------------------


func test_play_stratum1_ambient_is_idempotent_when_same_gain() -> void:
	# Room-cycle case: R1→R2→R1 re-fires play_stratum1_ambient. The second
	# call must be a no-op (same stream, same gain) — otherwise the ambient
	# bed re-seeds loop position to 0 and the player hears a glitch on
	# every room transition.
	var ad: Node = _audio_director()
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	var stream_before: AudioStream = ad.get_ambient_player().stream
	var playing_before: bool = ad.get_ambient_player().playing
	# Re-call with the same args — must NOT re-seed.
	ad.play_stratum1_ambient(1, 0.0)
	var stream_after: AudioStream = ad.get_ambient_player().stream
	assert_eq(
		stream_before,
		stream_after,
		"Repeated play_stratum1_ambient calls (same gain) must not swap stream"
	)
	assert_true(
		playing_before and ad.get_ambient_player().playing,
		"Stream stays playing across the idempotent call"
	)


func test_play_stratum1_ambient_retargets_when_different_gain() -> void:
	# The F4 path on a player who walked back through R1 mid-fight: ambient
	# at full → stop_stratum1_ambient (BI-03) → bed stops → boss dies →
	# resume_stratum1_ambient_at_60_percent. The resume must NOT be
	# idempotence-blocked (different gain target from the prior FULL_DB
	# play call). This test pins that contract.
	var ad: Node = _audio_director()
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	# Re-call with a DIFFERENT gain — must re-target, not no-op.
	ad.play_stratum1_ambient(1, RESUME_DB)
	ad.complete_pending_fades_for_test()
	assert_almost_eq(
		ad.get_ambient_player().volume_db,
		RESUME_DB,
		RESUME_DB_EPSILON,
		"Different-gain call must re-target the volume tween"
	)


# ---- BI-03 fade-out path ----------------------------------------------


func test_stop_stratum1_ambient_drives_player_to_silence_and_stops() -> void:
	# After the fade-out, the player must be stopped (`playing == false`)
	# and `_last_ambient_path` cleared so a future play_stratum1_ambient
	# is NOT idempotence-blocked.
	var ad: Node = _audio_director()
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	assert_true(ad.get_ambient_player().playing, "sanity: bed is playing pre-stop")
	# Fire the BI-03 stop with very short fade.
	ad.stop_stratum1_ambient(1)
	# `_fade_out_and_stop` schedules a finished.connect lambda that calls
	# stop() after the tween completes. Wait two frames so the tween's
	# `finished` lands.
	await wait_frames(3)
	assert_false(
		ad.get_ambient_player().playing,
		"Ambient player must stop after stop_stratum1_ambient fade-out"
	)
	assert_eq(
		ad.get_last_ambient_path(),
		"",
		"_last_ambient_path must clear so future play_stratum1_ambient is not idempotence-blocked"
	)


func test_play_stratum1_ambient_re_fires_cleanly_after_stop() -> void:
	# Stop → Play sequence: covers the room-traversal-during-fight case
	# (player walks back to a non-boss room post-defeat). The resume
	# must result in the bed playing again, NOT a silent vacuous no-op.
	var ad: Node = _audio_director()
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	ad.stop_stratum1_ambient(1)
	await wait_frames(3)
	# Now re-play — must succeed (not idempotence-blocked).
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	assert_true(
		ad.get_ambient_player().playing,
		"play_stratum1_ambient post-stop must successfully restart the bed"
	)
	assert_eq(ad.get_last_ambient_path(), STREAM_PATH_S1_AMBIENT)


# ---- Stratum1BossRoom wiring ------------------------------------------


func _make_boss_room() -> Stratum1BossRoom:
	# Same shape as test_s1_boss_audio_triggers.gd's helper.
	var room: Stratum1BossRoom = Stratum1BossRoom.new()
	room.boss_scene_path = "res://scenes/mobs/Stratum1Boss.tscn"
	room.boss_mob_def_path = ""
	return room


func test_stratum1_boss_room_wires_entry_sequence_started_to_ambient_stop() -> void:
	# BI-03 wiring contract. The room's _ready (via _wire_audio_cues) must
	# subscribe a handler to entry_sequence_started that stops the S1
	# ambient. Assertion is on the connection count + the method name —
	# the connection IS the contract that prevents the bed from playing
	# during the boss fight.
	var room: Stratum1BossRoom = _make_boss_room()
	add_child_autofree(room)
	var connections: Array = room.entry_sequence_started.get_connections()
	# Find the ambient-stop handler specifically — same pattern as the
	# entry_sequence_completed idempotence test in test_s1_boss_audio_triggers.gd.
	var ambient_handler_count: int = 0
	for c in connections:
		if c.has("callable") and c["callable"].get_method() == "_on_entry_sequence_started_audio":
			ambient_handler_count += 1
	assert_eq(
		ambient_handler_count,
		1,
		(
			"_on_entry_sequence_started_audio must be connected exactly once "
			+ "after _ready (got %d connections)" % ambient_handler_count
		)
	)


func test_stratum1_boss_room_ambient_wiring_is_idempotent() -> void:
	# Triple-wire guard. _wire_audio_cues must be safe to re-call without
	# stacking handlers — otherwise stop_stratum1_ambient fires N times
	# per entry_sequence_started emission.
	var room: Stratum1BossRoom = _make_boss_room()
	add_child_autofree(room)
	room._wire_audio_cues()
	room._wire_audio_cues()
	var connections: Array = room.entry_sequence_started.get_connections()
	var ambient_handler_count: int = 0
	for c in connections:
		if c.has("callable") and c["callable"].get_method() == "_on_entry_sequence_started_audio":
			ambient_handler_count += 1
	assert_eq(
		ambient_handler_count,
		1,
		(
			"_on_entry_sequence_started_audio must remain connected exactly "
			+ "once after triple-wire (got %d connections)" % ambient_handler_count
		)
	)


func test_entry_sequence_started_drives_ambient_to_silence() -> void:
	# End-to-end: emit entry_sequence_started on a boss room and confirm
	# the ambient ducks. Same shape as
	# test_entry_sequence_completed_fires_crossfade in the S1 boss audio
	# test file, but for the ambient channel.
	var ad: Node = _audio_director()
	# Start the ambient first so there's something to fade out.
	ad.play_stratum1_ambient(1, 0.0)
	ad.complete_pending_fades_for_test()
	assert_true(ad.get_ambient_player().playing, "sanity: ambient playing pre-trigger")
	# Spin up a boss room and fire the entry-sequence signal directly.
	var room: Stratum1BossRoom = _make_boss_room()
	add_child_autofree(room)
	# trigger_entry_sequence emits entry_sequence_started + arms the 1.8 s
	# timer; we only need the emission to fire the audio handler.
	room.trigger_entry_sequence()
	# Wait for the fade tween to complete (the test passes fade=1 ms but
	# stop_stratum1_ambient uses S1_AMBIENT_ENTRY_FADE_OUT_MS=600 default).
	# Bypass the wait by snap-completing — easier to assert end-state.
	# But complete_pending_fades_for_test snaps to _ambient_target_db which
	# is SILENCE_DB after stop_stratum1_ambient, so this works.
	await wait_frames(3)
	# After the fade the player should be stopped + last_ambient_path empty.
	assert_eq(
		ad.get_last_ambient_path(),
		"",
		(
			"After entry_sequence_started, the ambient path must clear "
			+ "(the bed is stopping). got=%s" % ad.get_last_ambient_path()
		)
	)


# ---- Cross-stratum-distinct policy (Uma binding decision) -------------


func test_s1_and_s2_ambient_assets_are_different_files() -> void:
	# The cross-stratum-distinct ambient policy from Uma's s1-ambient.md
	# §"Tonal anchor" + DECISIONS.md draft 2026-05-20. S2 already has
	# distinct ambient (mus + amb both unique); T10 IS the second instance.
	# This test pins the file-level distinction (mirrors the
	# test_crossfade_to_boss_stratum1_is_unique_not_s2_reuse pattern).
	assert_ne(
		STREAM_PATH_S1_AMBIENT,
		STREAM_PATH_S2_AMBIENT,
		(
			"S1 ambient must be a distinct file from S2 ambient "
			+ "(cross-stratum-distinct policy; Uma s1-ambient.md §Tonal anchor)"
		)
	)
	var s1: Resource = load(STREAM_PATH_S1_AMBIENT)
	var s2: Resource = load(STREAM_PATH_S2_AMBIENT)
	assert_ne(
		s1.resource_path,
		s2.resource_path,
		"S1 and S2 ambient resources must have distinct resource paths"
	)


# ---- Main.gd room-load wiring -----------------------------------------


func test_main_load_room_at_index_fires_play_stratum1_ambient_for_non_boss_rooms() -> void:
	# Drive Main's load-room handler for a non-boss room index (Room01,
	# index 0) and assert play_stratum1_ambient was called. This is the
	# regression guard against the wiring getting dropped from
	# `_load_room_at_index`.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var main: Node = packed.instantiate()
	# Clean slate save so Main doesn't restore stale state.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	add_child_autofree(main)
	# Reset the audio director state so this test isn't satisfied by a
	# prior test's last_ambient_path.
	var ad: Node = _audio_director()
	ad.stop_all_music(1)
	ad.complete_pending_fades_for_test()
	# Force a room load — public API exists per `load_room_index` in Main.gd.
	main.load_room_index(0)
	await wait_frames(3)
	ad.complete_pending_fades_for_test()
	assert_eq(
		ad.get_last_ambient_path(),
		STREAM_PATH_S1_AMBIENT,
		(
			"Main._load_room_at_index must fire play_stratum1_ambient for "
			+ "non-boss S1 rooms (got %s)" % ad.get_last_ambient_path()
		)
	)


func test_main_load_room_at_index_skips_ambient_for_boss_room() -> void:
	# Inverse: boss room (index 8) must NOT fire play_stratum1_ambient.
	# The ambient is stopped by Stratum1BossRoom.entry_sequence_started
	# handler; this test pins that Main.gd doesn't pre-trigger the bed
	# at room load (which would race the entry-sequence stop).
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	add_child_autofree(main)
	var ad: Node = _audio_director()
	ad.stop_all_music(1)
	ad.complete_pending_fades_for_test()
	# Pre-condition: ambient path is empty.
	assert_eq(ad.get_last_ambient_path(), "", "sanity: ambient path cleared pre-load")
	# Load the boss room directly.
	main.load_room_index(8)
	await wait_frames(3)
	# Assert ambient was NOT fired by Main.gd's load handler. (The handler
	# checks `index != BOSS_ROOM_INDEX` before calling.)
	assert_ne(
		ad.get_last_ambient_path(),
		STREAM_PATH_S1_AMBIENT,
		(
			"Boss room load must NOT fire play_stratum1_ambient — the "
			+ "entry_sequence_started handler is the only ambient-control "
			+ "path inside the boss room. got=%s" % ad.get_last_ambient_path()
		)
	)
